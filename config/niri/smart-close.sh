#!/bin/bash
# Fecha a janela focada; Spotify vai para a workspace nomeada "spotify" em vez de fechar (equivale ao special workspace).
app=$(niri msg --json focused-window | jq -r '.app_id // ""')
if [[ "${app,,}" == "spotify" ]]; then
  niri msg action move-window-to-workspace spotify
else
  niri msg action close-window
fi
