#!/usr/bin/env bash
# Gera um tema (themes/<id>.json) para cada wallpaper do Wallpaper Engine.
#
#   1) tira um print de cada wallpaper com o linux-wallpaperengine  -> themes/screenshots/<id>.png
#   2) roda o ColorQuantizer do Quickshell (tools/ThemeGen.qml) nos prints
#      e escreve as cores iniciais em themes/<id>.json
#
# Uso:
#   tools/gen-themes.sh                 todos os wallpapers que ainda não têm print/tema
#   tools/gen-themes.sh 1845706469 ...  só esses ids
#   tools/gen-themes.sh --force         refaz prints e cores (mantém "assets" e "name" do json)
#   tools/gen-themes.sh --shots-only    só os prints
#   tools/gen-themes.sh --themes-only   só os temas, a partir dos prints que já existem
#
# Variáveis (opcionais):
#   WORKSHOP_DIR   padrão ~/.local/share/Steam/steamapps/workshop/content/431960
#   SHOT_SIZE      tamanho da janela do print, padrão 1920x1080
#   SHOT_DELAY     frames de espera antes do print (só se o seu linux-wallpaperengine tiver --screenshot-delay), padrão 30
#   SHOT_TIMEOUT   segundos por wallpaper antes de desistir, padrão 60
#   QUANT_DEPTH    2^n cores por tema, padrão 3 (8 cores)
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
THEMES_DIR="$ROOT/themes"
SHOTS_DIR="$THEMES_DIR/screenshots"
WORKSHOP_DIR="${WORKSHOP_DIR:-$HOME/.local/share/Steam/steamapps/workshop/content/431960}"
SHOT_SIZE="${SHOT_SIZE:-1920x1080}"
SHOT_DELAY="${SHOT_DELAY:-30}"
SHOT_TIMEOUT="${SHOT_TIMEOUT:-60}"
LWE="${LWE:-linux-wallpaperengine}"

FORCE=0; DO_SHOTS=1; DO_THEMES=1; FALLBACK=1; IDS=()
for arg in "$@"; do
  case "$arg" in
    -f|--force)     FORCE=1 ;;
    --shots-only)   DO_THEMES=0 ;;
    --themes-only)  DO_SHOTS=0 ;;
    --no-fallback)  FALLBACK=0 ;;
    -h|--help)      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)             echo "opção desconhecida: $arg" >&2; exit 2 ;;
    *)              IDS+=("$arg") ;;
  esac
done

mkdir -p "$SHOTS_DIR"
python3 "$HERE/add-niri-settings.py" --themes "$THEMES_DIR" || exit 1

list_ids() {
  if [ ${#IDS[@]} -gt 0 ]; then printf '%s\n' "${IDS[@]}"; return; fi
  [ -d "$WORKSHOP_DIR" ] || { echo "pasta do workshop não existe: $WORKSHOP_DIR" >&2; return 1; }
  find "$WORKSHOP_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

existing_shot() {   # imprime o print existente do id (qualquer extensão), se houver
  local f
  for f in "$SHOTS_DIR/$1".{png,jpg,jpeg,gif,webp,bmp}; do
    [ -s "$f" ] && { echo "$f"; return 0; }
  done
  return 1
}

take_shot() {
  local id="$1" dir="$WORKSHOP_DIR/$1" out="$SHOTS_DIR/$1.png"
  local args=(--screenshot "$out")

  # --screenshot-delay existe em versões mais novas; só passa se o seu binário conhecer
  if "$LWE" --help 2>&1 | grep -q -- '--screenshot-delay'; then
    args+=(--screenshot-delay "$SHOT_DELAY")
  fi
  args+=(--window "0x0x${SHOT_SIZE}" --silent)

  rm -f "$out"
  timeout -k 5 "$SHOT_TIMEOUT" "$LWE" "${args[@]}" "$dir" >/dev/null 2>&1
  [ -s "$out" ] && return 0

  rm -f "$out"
  if [ "$FALLBACK" = 1 ]; then      # o engine não conseguiu: usa a imagem de preview do próprio wallpaper
    local p ext
    for p in "$dir"/preview.{png,jpg,jpeg,gif,webp}; do
      [ -s "$p" ] || continue
      ext="${p##*.}"
      cp "$p" "$SHOTS_DIR/$id.$ext" && { echo "  (print falhou; usei o preview.$ext)"; return 0; }
    done
  fi
  return 1
}

if [ "$DO_SHOTS" = 1 ]; then
  command -v "$LWE" >/dev/null || { echo "não achei o '$LWE' no PATH" >&2; exit 1; }
  ok=0; skip=0; bad=0
  while read -r id; do
    [ -n "$id" ] || continue
    if [ "$FORCE" = 0 ] && existing_shot "$id" >/dev/null; then skip=$((skip+1)); continue; fi
    if [ ! -d "$WORKSHOP_DIR/$id" ]; then echo "$id: não está no workshop"; bad=$((bad+1)); continue; fi
    printf '%s: print... ' "$id"
    if take_shot "$id"; then echo ok; ok=$((ok+1)); else echo FALHOU; bad=$((bad+1)); fi
  done < <(list_ids)
  echo "prints: $ok novos, $skip já existiam, $bad com falha  ->  $SHOTS_DIR"
fi

if [ "$DO_THEMES" = 1 ]; then
  QS="$(command -v qs || command -v quickshell)" || { echo "não achei o quickshell (qs)" >&2; exit 1; }
  # ids que serão processados: têm print e (sem --force) ainda não têm tema
  todo="$(list_ids | while read -r id; do
    [ -n "$id" ] || continue
    shot="$(existing_shot "$id")" || continue
    [ "$FORCE" = 0 ] && [ -e "$THEMES_DIR/$id.json" ] && continue
    printf '%s\t%s\n' "$id" "$shot"
  done)"
  if [ -z "$todo" ]; then echo "temas: nada a fazer"; exit 0; fi

  THEMES_DIR="$THEMES_DIR" SHOTS_DIR="$SHOTS_DIR" WORKSHOP_DIR="$WORKSHOP_DIR" \
  MAKE_THEME="$HERE/make_theme.py" FORCE="$FORCE" QUANT_DEPTH="${QUANT_DEPTH:-3}" \
  TODO="$todo" "$QS" -p "$HERE/ThemeGen.qml" 2>&1 | grep --line-buffered '\[theme\]'
fi
