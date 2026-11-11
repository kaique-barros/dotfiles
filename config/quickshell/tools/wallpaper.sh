#!/usr/bin/env bash
# Inicia o linux-wallpaperengine com o tema salvo e troca de wallpaper/tema.
#
#   wallpaper.sh start        inicia com o tema salvo (use no spawn-at-startup do config.kdl)
#   wallpaper.sh set <id>     salva <id> como tema atual e troca o wallpaper
#   wallpaper.sh get          mostra o id salvo
#
# O id fica em ${XDG_STATE_HOME:-~/.local/state}/quickshell/theme (o shell lê o mesmo arquivo).
# Monitores e opções do engine ficam em themes/engine.conf.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
CONF="$ROOT/themes/engine.conf"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
STATE_FILE="$STATE_DIR/theme"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/quickshell-wallpaper.lock"

LWE="linux-wallpaperengine"
MONITORS=""        # vazio = todos os monitores do niri
GLOBAL_ARGS=""     # opções do engine antes dos wallpapers (ex.: --silent --fps 30)
BG_ARGS=""         # opções de cada wallpaper (ex.: --scaling fill --clamp border)
DEFAULT_ID=""      # usado enquanto não existir tema salvo
SWITCH_OVERLAP=1   # segundos com o engine novo e o antigo juntos (evita piscar a tela)
# shellcheck disable=SC1090
[ -f "$CONF" ] && . "$CONF"

current_id() {
  local id=""
  [ -s "$STATE_FILE" ] && id="$(tr -d '[:space:]' < "$STATE_FILE")"
  echo "${id:-$DEFAULT_ID}"
}

monitors() {
  if [ -n "$MONITORS" ]; then echo $MONITORS; else niri msg --json outputs 2>/dev/null | jq -r 'keys[]'; fi
}

engine_pids() { pgrep -f '(^|/)linux-wallpaperengine( |$)' || true; }

launch() {
  local id="$1" m
  local -a args
  # shellcheck disable=SC2206
  args=($GLOBAL_ARGS)
  for m in $(monitors); do
    # shellcheck disable=SC2206
    args+=(--screen-root "$m" --bg "$id" $BG_ARGS)
  done
  # 9>&-: o engine NÃO pode herdar o fd do lock, senão ele segura o lock enquanto estiver vivo
  setsid -f "$LWE" "${args[@]}" >/dev/null 2>&1 9>&-
}

switch_to() {
  local id="$1" old
  old="$(engine_pids)"
  launch "$id"
  if [ -n "$old" ]; then
    sleep "$SWITCH_OVERLAP"
    # shellcheck disable=SC2086
    kill $old 2>/dev/null
  fi
}

cmd="${1:-}"
case "$cmd" in
  get)
    current_id
    ;;
  start)
    id="$(current_id)"
    [ -n "$id" ] || { echo "sem tema salvo e sem DEFAULT_ID em $CONF" >&2; exit 1; }
    command -v "$LWE" >/dev/null || { echo "não achei o $LWE no PATH" >&2; exit 1; }
    exec 9>"$LOCK"; flock -w 10 9 || echo "lock ocupado, seguindo sem ele" >&2
    switch_to "$id"
    ;;
  set)
    id="${2:-}"
    [[ "$id" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "uso: $0 set <id>" >&2; exit 2; }
    mkdir -p "$STATE_DIR"
    printf '%s\n' "$id" > "$STATE_FILE"
    command -v "$LWE" >/dev/null || { echo "não achei o $LWE no PATH" >&2; exit 1; }
    exec 9>"$LOCK"; flock -w 10 9 || echo "lock ocupado, seguindo sem ele" >&2
    # se chegou uma troca mais nova enquanto esperava o lock, ela cuida do resto
    [ "$(current_id)" = "$id" ] || exit 0
    switch_to "$id"
    ;;
  *)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
