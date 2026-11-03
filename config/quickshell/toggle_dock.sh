#!/bin/bash
STATE_FILE="/tmp/quickshell_dock_active"

if [ -f "$STATE_FILE" ]; then
    CURRENT=$(cat "$STATE_FILE")
    if [ "$CURRENT" = "1" ]; then
        echo "0" > "$STATE_FILE"
    else
        echo "1" > "$STATE_FILE"
    fi
else
    echo "1" > "$STATE_FILE"
fi
