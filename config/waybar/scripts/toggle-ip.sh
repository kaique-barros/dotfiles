#!/bin/bash

STATE_FILE="$HOME/.cache/waybar-ip-state"

# Criar arquivo de estado se não existir
if [ ! -f "$STATE_FILE" ]; then
    echo "local" > "$STATE_FILE"
fi

STATE=$(cat "$STATE_FILE")

# Alternar estado
if [ "$STATE" = "local" ]; then
    echo "public" > "$STATE_FILE"
else
    echo "local" > "$STATE_FILE"
fi

# Recarregar waybar
pkill -SIGRTMIN+1 waybar
