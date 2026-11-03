#!/bin/bash

# Obter o perfil atual de energia
PROFILE=$(powerprofilesctl get)

case "$PROFILE" in
    "power-saver")
        echo "󱈘 Saver"
        ;;
    "balanced")
        echo "󰓅 Balanced"
        ;;
    "performance")
        echo "󰓅 Perf"
        ;;
    *)
        echo "󰓅 $PROFILE"
        ;;
esac
