#!/bin/bash
# Importa (uma vez) o histórico do rofi (~/.cache/rofi3.druncache) para o do launcher do Quickshell.
# Formato dos dois: "contagem id" por linha. Soma contagens de ids repetidos. Pode rodar de novo sem duplicar
# (só soma se ainda não houver marca de importação).
set -eu
cache="${XDG_CACHE_HOME:-$HOME/.cache}"
src="$cache/rofi3.druncache"
dst="$cache/quickshell-launcher.usage"
mark="$cache/.rofi-usage-imported"
[ -f "$src" ] || { echo "sem $src — nada a importar"; exit 0; }
[ -f "$mark" ] && { echo "já importado (apague $mark para refazer)"; exit 0; }
touch "$dst"
cat "$src" "$dst" | awk '
  match($0,/^[ \t]*[0-9]+[ \t]+/) { n=$1; id=$0; sub(/^[ \t]*[0-9]+[ \t]+/,"",id); sub(/[ \t]+$/,"",id); c[id]+=n }
  END { for (i in c) print c[i], i }' | sort -rn > "$dst.tmp"
mv "$dst.tmp" "$dst"
touch "$mark"
echo "importado: $(wc -l < "$dst") apps em $dst"
