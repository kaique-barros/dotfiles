#!/bin/bash

STATE_FILE="$HOME/.cache/waybar-ip-state"

# Criar arquivo de estado se não existir
if [ ! -f "$STATE_FILE" ]; then
    echo "local" > "$STATE_FILE"
fi

STATE=$(cat "$STATE_FILE")

if [ "$STATE" = "public" ]; then
    # Mostrar IP público (preferir IPv4)
    PUBLIC_IP=$(timeout 3 curl -4 -s https://icanhazip.com 2>/dev/null || timeout 3 curl -4 -s https://checkip.amazonaws.com 2>/dev/null)
    PUBLIC_IP=$(echo "$PUBLIC_IP" | tr -d '\n' | xargs)
    
    # Se não conseguir IPv4, tentar IPv6
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP=$(timeout 3 curl -6 -s https://icanhazip.com 2>/dev/null)
        PUBLIC_IP=$(echo "$PUBLIC_IP" | tr -d '\n' | xargs)
    fi
    
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP="N/A"
    fi
    echo "󰩟 $PUBLIC_IP"
else
    # Mostrar IP local (preferir IPv4)
    LOCAL_IP=$(ip addr | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
    
    # Se não houver IPv4, tentar IPv6
    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP=$(ip addr | grep 'inet6 ' | grep -v '::1' | awk '{print $2}' | cut -d/ -f1 | head -1)
    fi
    
    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP="N/A"
    fi
    echo "󰒍 $LOCAL_IP"
fi
