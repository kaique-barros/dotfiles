#!/bin/bash

# Obter o perfil atual
CURRENT=$(powerprofilesctl get)

# Alternar ciclicamente
case "$CURRENT" in
    "power-saver")
        powerprofilesctl set balanced
        ;;
    "balanced")
        powerprofilesctl set performance
        ;;
    "performance")
        powerprofilesctl set power-saver
        ;;
    *)
        powerprofilesctl set balanced
        ;;
esac

# Recarregar waybar
pkill -SIGRTMIN+1 waybar
