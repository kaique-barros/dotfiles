#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
THEMES_DIR="$ROOT/themes"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
STATE_FILE="$STATE_DIR/theme"
OUTPUT="$STATE_DIR/niri-theme.kdl"

# O ID é passado pelo Theme.qml. Se não vier, usa o tema salvo.
THEME_ID="${1:-}"
if [[ -z "$THEME_ID" && -f "$STATE_FILE" ]]; then
    THEME_ID="$(<"$STATE_FILE")"
fi

THEME_FILE="$THEMES_DIR/$THEME_ID.json"

# Valores de fallback para quando não houver tema válido.
COR1="#fefefe"
COR2="#2a211c"
BORDER_WIDTH=2
CORNER_RADIUS=7

if [[ -n "$THEME_ID" && -f "$THEME_FILE" ]]; then
    jq -e . "$THEME_FILE" >/dev/null

    read -r COR1 COR2 BORDER_WIDTH CORNER_RADIUS < <(
        jq -r '[
            .colors.cor1 // "#fefefe",
            .colors.cor2 // "#2a211c",
            .niri.borderWidth // 2,
            .niri.cornerRadius // 7
        ] | @tsv' "$THEME_FILE"
    )
fi

# Validação para evitar gerar KDL inválido.
[[ "$COR1" =~ ^#[[:xdigit:]]{6}([[:xdigit:]]{2})?$ ]] || COR1="#fefefe"
[[ "$COR2" =~ ^#[[:xdigit:]]{6}([[:xdigit:]]{2})?$ ]] || COR2="#2a211c"

[[ "$BORDER_WIDTH" =~ ^[0-9]+([.][0-9]+)?$ ]] || BORDER_WIDTH=2
[[ "$CORNER_RADIUS" =~ ^[0-9]+([.][0-9]+)?$ ]] || CORNER_RADIUS=7

mkdir -p "$STATE_DIR"

TMP="$(mktemp "$STATE_DIR/niri-theme.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<EOF
// Gerado automaticamente por theme-sync-niri.sh.
// Não edite manualmente.

layout {
    border {
        width $BORDER_WIDTH
        active-gradient from="$COR2" to="$COR1" angle=45
        inactive-color "$COR2"
    }
}

window-rule {
    geometry-corner-radius $CORNER_RADIUS
    clip-to-geometry true
}
EOF

mv "$TMP" "$OUTPUT"
