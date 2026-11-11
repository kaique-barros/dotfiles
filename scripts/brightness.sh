#!/usr/bin/env bash

case "$1" in
    up)
        brightnessctl -e4 -n2 set 5%+ >/dev/null
        ;;
    down)
        brightnessctl -e4 -n2 set 5%- >/dev/null
        ;;
    *)
        exit 1
        ;;
esac

brightness=$(brightnessctl -m | awk -F, '{gsub(/%/, "", $5); print $5}')

qs ipc call rightControlsBar syncBrightness "$brightness"
