#!/usr/bin/env bash

# Add this script to your wm startup file.

DIR="$HOME/.config/polybar/"

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

screens=$(xrandr --listactivemonitors | grep -v "Monitors" | cut -d" " -f6)

if [[ $(xrandr --listactivemonitors | grep -v "Monitors" | cut -d" " -f4 | cut -d"+" -f2- | uniq | wc -l) == 1 ]]; then
    MONITOR=$(polybar --list-monitors | cut -d":" -f1) TRAY=right polybar -q main -c "$DIR"/config.ini &
else
    primary=$(xrandr --query | grep primary | cut -d" " -f1)
    for m in $screens; do
        if [[ $primary == $m ]]; then
            MONITOR=$m TRAY=right polybar -q main -c "$DIR"/config.ini &
        else
            MONITOR=$m TRAY=none polybar -q secondary -c "$DIR"/config.ini &
        fi
    done
fi
