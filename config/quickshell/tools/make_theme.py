#!/usr/bin/env python3
"""Gera (ou atualiza) themes/<id>.json a partir das cores que o ColorQuantizer tirou do print.

Chamado pelo ThemeGen.qml, mas também funciona sozinho:
  make_theme.py --id 1845706469 --shot print.png --themes ./themes --colors "#aabbcc,#112233,..."

As cores do tema são só uma aproximação inicial: edite o json à vontade
(o gerador não sobrescreve um tema existente, a não ser com --force).
"""
import argparse
import colorsys
import json
import os
import re
import sys

HEX = re.compile(r"^#?([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$")


def parse_hex(s):
    m = HEX.match(s.strip())
    if not m:
        return None
    h = m.group(1)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def to_hex(rgb):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v))) for v in rgb)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def lum(rgb):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(v) for v in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def hsv(rgb):
    return colorsys.rgb_to_hsv(*(v / 255 for v in rgb))


def distinct(colors, min_dist=12):
    out = []
    for c in colors:
        if all(sum(abs(c[i] - o[i]) for i in range(3)) >= min_dist for o in out):
            out.append(c)
    return out


def derive(colors):
    """Escolhe cor1 (fundo), cor2 (pílulas), cor3 (texto) e accent. danger fica vazio (= padrão)."""
    colors = distinct(colors)
    if not colors:
        return {}

    by_lum = sorted(colors, key=lum)
    darkest, lightest = by_lum[0], by_lum[-1]
    white, black = (255, 255, 255), (0, 0, 0)

    if lum(lightest) >= 0.25:
        # tema claro: moldura clara, texto escuro (como o padrão)
        cor1 = mix(lightest, white, 0.30)
        cor3 = mix(darkest, black, 0.55)
        if contrast(cor1, cor3) < 7:
            cor3 = black
    else:
        # wallpaper escuro: moldura escura, texto claro
        cor1 = mix(darkest, black, 0.20)
        cor3 = mix(lightest, white, 0.60)
        if contrast(cor1, cor3) < 7:
            cor3 = white

    # pílulas/caixas: a cor mais saturada que não é igual à moldura nem ao texto
    pool = [c for c in colors if contrast(c, cor1) >= 1.4 and sum(abs(c[i] - cor3[i]) for i in range(3)) > 30]
    pool.sort(key=lambda c: hsv(c)[1] * (0.4 + hsv(c)[2]), reverse=True)
    if pool:
        cor2 = pool[0]
    else:
        cor2 = mix(cor1, cor3, 0.65)

    # accent: só se houver uma cor realmente viva; senão fica vazio e vale o padrão
    accent = ""
    vivid = [c for c in colors if hsv(c)[1] >= 0.45 and hsv(c)[2] >= 0.45 and c != cor2]
    vivid.sort(key=lambda c: hsv(c)[1] * hsv(c)[2], reverse=True)
    if vivid:
        accent = to_hex(vivid[0])

    return {"cor1": to_hex(cor1), "cor2": to_hex(cor2), "cor3": to_hex(cor3),
            "accent": accent, "danger": ""}


def read_title(workshop, tid):
    if not workshop:
        return ""
    try:
        with open(os.path.join(workshop, tid, "project.json"), encoding="utf-8") as f:
            return str(json.load(f).get("title", "")).strip()
    except (OSError, ValueError):
        return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True)
    ap.add_argument("--shot", default="")
    ap.add_argument("--themes", required=True)
    ap.add_argument("--workshop", default="")
    ap.add_argument("--colors", required=True, help="cores do quantizer separadas por vírgula")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()

    path = os.path.join(a.themes, a.id + ".json")
    existing = {}
    if os.path.exists(path):
        if not a.force:
            print("[theme] %s: já existe, mantido (use --force para refazer)" % a.id)
            return 0
        try:
            with open(path, encoding="utf-8") as f:
                existing = json.load(f)
        except (OSError, ValueError):
            existing = {}

    raw = [parse_hex(s) for s in a.colors.split(",") if s.strip()]
    raw = [c for c in raw if c]
    if not raw:
        print("[theme] %s: nenhuma cor válida" % a.id, file=sys.stderr)
        return 1

    niri = existing.get("niri", {})
    if not isinstance(niri, dict):
        niri = {}

    data = {
        "id": a.id,
        "name": existing.get("name") or read_title(a.workshop, a.id),
        "screenshot": a.shot,
        "assets": existing.get("assets", ""),
        "colors": derive(raw),
        "quantized": [to_hex(c) for c in raw],
        "niri": {
            "borderWidth": niri.get("borderWidth", 2),
            "cornerRadius": niri.get("cornerRadius", 7),
        },
    }
    # mantém qualquer outra chave que você tenha adicionado ao tema
    for k, v in existing.items():
        data.setdefault(k, v)

    os.makedirs(a.themes, exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, path)
    print("[theme] %s: %s" % (a.id, path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
