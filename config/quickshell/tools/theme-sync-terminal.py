#!/usr/bin/env python3
"""Gera as cores do terminal (kitty) a partir do tema atual do Quickshell.

Lê themes/<id>.json (colors.cor1..cor3, accent, danger), monta uma paleta ANSI de 16 cores legível sobre o fundo
e grava ~/.local/state/quickshell/kitty-theme.conf. Se o conteúdo mudou, manda SIGUSR1 aos kitty abertos para
recarregarem a configuração (as cores do prompt do oh-my-zsh, como o agnoster, são índices da paleta e mudam na hora).

Uso: theme-sync-terminal.py [ID_DO_TEMA]      (sem ID, usa o tema salvo em ~/.local/state/quickshell/theme)
"""
import colorsys
import json
import os
import re
import signal
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
THEMES_DIR = Path(os.environ.get("QS_THEMES_DIR") or HERE.parent / "themes")
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state") / "quickshell"
OUTPUT = Path(os.environ.get("QS_KITTY_THEME_OUT") or STATE_DIR / "kitty-theme.conf")

# ================= CONFIGURAÇÕES =================
BG_LIGHTNESS_MAX = 0.14      # o fundo do terminal é sempre escuro; se a cor do tema for mais clara, escurece
BG_SATURATION_MAX = 0.40
FG_CONTRAST = 8.0            # texto normal sobre o fundo
COLOR_CONTRAST = 4.5         # cores ANSI sobre o fundo e como fundo de segmento (texto preto do agnoster)
TINT = 0.18                  # quanto o matiz das cores "normais" é puxado para o matiz do tema (0 a 1)
MIN_HUE_GAP = 40             # distância mínima entre matizes para o azul do tema não colidir com verde/vermelho/etc.
# matiz base (graus) de cada cor ANSI
BASE_HUES = {"red": 4, "green": 135, "yellow": 46, "blue": 215, "magenta": 292, "cyan": 183}
FALLBACK = {"cor1": "#fefefe", "cor2": "#2a211c", "cor3": "#8a8a8a"}
# =================================================


# ---------- cor ----------
def parse(h):
    h = h.strip().lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hexs(rgb):
    return "#" + "".join(f"{round(max(0, min(1, c)) * 255):02x}" for c in rgb)


def lum(rgb):
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4  # noqa: E731
    r, g, b = (f(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = lum(a), lum(b)
    if la < lb:
        la, lb = lb, la
    return (la + 0.05) / (lb + 0.05)


def to_hls(rgb):
    return colorsys.rgb_to_hls(*rgb)          # (h 0-1, l, s)


def from_hls(h, l, s):
    return colorsys.hls_to_rgb(h % 1.0, max(0, min(1, l)), max(0, min(1, s)))


def hue_deg(rgb):
    return to_hls(rgb)[0] * 360


def hue_dist(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


def toward(h, target, w):
    """Puxa o matiz h (graus) para o target pelo caminho mais curto."""
    d = ((target - h + 180) % 360) - 180
    return (h + d * w) % 360


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def lift(rgb, against, ratio, step=0.01):
    """Aumenta a luminosidade até haver contraste suficiente contra todas as cores de `against`."""
    h, l, s = to_hls(rgb)
    while l < 0.93 and any(contrast(from_hls(h, l, s), c) < ratio for c in against):
        l += step
    out = from_hls(h, l, s)
    if any(contrast(out, c) < ratio for c in against):      # no teto: tira saturação
        while s > 0.05 and any(contrast(out, c) < ratio for c in against):
            s -= 0.05
            out = from_hls(h, l, s)
    return out


def drop(rgb, against, ratio, step=0.01):
    """Reduz a luminosidade até haver contraste suficiente (para cores de fundo)."""
    h, l, s = to_hls(rgb)
    while l > 0.02 and any(contrast(from_hls(h, l, s), c) < ratio for c in against):
        l -= step
    return from_hls(h, l, s)


# ---------- paleta ----------
def build(colors):
    def get(k):
        v = colors.get(k)
        return parse(v) if isinstance(v, str) and re.fullmatch(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", v.strip()) else parse(FALLBACK.get(k, "#808080"))

    cands = [get("cor1"), get("cor2"), get("cor3")]

    # fundo: a mais escura das cores do tema, escurecida/dessaturada o bastante para um terminal confortável
    bg0 = min(cands, key=lum)
    h, l, s = to_hls(bg0)
    bg = from_hls(h, min(l, BG_LIGHTNESS_MAX), min(s, BG_SATURATION_MAX))
    if lum(bg) > 0.03:
        bg = from_hls(h, BG_LIGHTNESS_MAX * 0.7, min(s, BG_SATURATION_MAX))

    # destaque do tema: accent, ou a cor mais saturada do tema
    acc = colors.get("accent")
    accent = parse(acc) if isinstance(acc, str) and re.fullmatch(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", acc.strip()) else max(cands, key=lambda c: to_hls(c)[2] * (0.3 + abs(to_hls(c)[1] - 0.5)))
    ah, al, a_s = to_hls(accent)
    if a_s < 0.15:                                           # tema sem cor: usa um azul acinzentado neutro
        ah, a_s = BASE_HUES["blue"] / 360, 0.25
    accent_h = ah * 360

    # primeiro plano: a mais clara das cores do tema (pouco saturada), com contraste garantido
    fg0 = max(cands, key=lum)
    fh, fl, fs = to_hls(fg0)
    fg = lift(from_hls(fh, max(fl, 0.85), min(fs, 0.18)), [bg], FG_CONTRAST)

    # matizes: o azul é o do tema (o agnoster usa azul no diretório); as outras são puxadas de leve para ele
    hues = {k: toward(v, accent_h, TINT) for k, v in BASE_HUES.items()}
    hues["blue"] = accent_h
    dng = colors.get("danger")
    if isinstance(dng, str) and re.fullmatch(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", dng.strip()):
        hues["red"] = hue_deg(parse(dng))
    # evita colisão do azul do tema com as demais (ex.: accent verde viraria igual ao verde do git)
    for k in ("green", "cyan", "yellow", "red", "magenta"):
        if hue_dist(hues[k], hues["blue"]) < MIN_HUE_GAP:
            sign = 1 if ((hues[k] - hues["blue"] + 180) % 360 - 180) >= 0 else -1
            hues[k] = (hues["blue"] + sign * MIN_HUE_GAP) % 360

    sat = lambda k: (min(max(a_s, 0.45), 0.8) if k == "blue" else 0.6)  # noqa: E731

    # preto ANSI: um pouco mais claro que o fundo, para o segmento "contexto" do prompt aparecer
    bh, bl, bs = to_hls(bg)
    black = from_hls(bh, bl + 0.05, bs)

    normal = {}
    for k in ("red", "green", "yellow", "blue", "magenta", "cyan"):
        c = from_hls(hues[k] / 360, 0.52, sat(k))
        # legível sobre o fundo e com o texto preto por cima (segmentos do agnoster)
        normal[k] = lift(c, [bg, black], COLOR_CONTRAST)
    bright = {}
    for k, c in normal.items():
        h2, l2, s2 = to_hls(c)
        bright[k] = from_hls(h2, min(0.82, l2 + 0.10), min(1, s2 + 0.05))

    white = lift(from_hls(fh, 0.80, min(fs, 0.12)), [bg], COLOR_CONTRAST)
    bright_black = lift(mix(bg, fg, 0.38), [bg], 3.2)         # comentários, sugestões do zsh

    ansi = [black, normal["red"], normal["green"], normal["yellow"], normal["blue"], normal["magenta"], normal["cyan"], white,
            bright_black, bright["red"], bright["green"], bright["yellow"], bright["blue"], bright["magenta"], bright["cyan"], fg]
    return {"bg": bg, "fg": fg, "accent": normal["blue"], "ansi": ansi}


def render(p, theme_id):
    a = p["ansi"]
    names = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
    lines = [
        f"# Gerado por theme-sync-terminal.py (tema {theme_id or 'padrão'}). Não edite: é sobrescrito a cada troca de tema.",
        f"foreground            {hexs(p['fg'])}",
        f"background            {hexs(p['bg'])}",
        f"cursor                {hexs(p['accent'])}",
        f"cursor_text_color     {hexs(p['bg'])}",
        f"selection_foreground  {hexs(p['fg'])}",
        f"selection_background  {hexs(mix(p['bg'], p['accent'], 0.40))}",
        f"url_color             {hexs(a[14])}",
        f"active_border_color   {hexs(p['accent'])}",
        f"inactive_border_color {hexs(a[8])}",
        f"active_tab_foreground   {hexs(p['bg'])}",
        f"active_tab_background   {hexs(p['accent'])}",
        f"inactive_tab_foreground {hexs(p['fg'])}",
        f"inactive_tab_background {hexs(mix(p['bg'], p['fg'], 0.10))}",
        f"tab_bar_background      {hexs(p['bg'])}",
        "",
    ]
    for i in range(16):
        label = names[i] if i < 8 else "bright " + names[i - 8]
        lines.append(f"color{i:<2} {hexs(a[i])}   # {label}")
    return "\n".join(lines) + "\n"


def reload_kitty():
    try:
        subprocess.run(["pkill", "-USR1", "-x", "kitty"], check=False, timeout=3)
    except (OSError, subprocess.SubprocessError):
        pass


def main():
    theme_id = sys.argv[1] if len(sys.argv) > 1 else ""
    if not theme_id:
        try:
            theme_id = (STATE_DIR / "theme").read_text().strip()
        except OSError:
            theme_id = ""
    colors = {}
    if theme_id and re.fullmatch(r"[\w.-]+", theme_id):
        try:
            colors = json.loads((THEMES_DIR / f"{theme_id}.json").read_text()).get("colors", {}) or {}
        except (OSError, ValueError) as e:
            print(f"theme-sync-terminal: sem tema válido ({e}); usando o padrão", file=sys.stderr)

    text = render(build(colors), theme_id)
    try:
        if OUTPUT.read_text() == text:
            return
    except OSError:
        pass
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=OUTPUT.parent, prefix="kitty-theme.", suffix=".tmp")
    with os.fdopen(fd, "w") as f:
        f.write(text)
    os.replace(tmp, OUTPUT)
    reload_kitty()


if __name__ == "__main__":
    main()
