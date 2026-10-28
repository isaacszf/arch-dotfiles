#!/bin/bash
# Auto-lock and monitor sleep for sway, the Wayland counterpart of xss-lock + DPMS under i3.
#
#   idle.sh start   start swayidle (used by the sway config's autostart)
#   idle.sh toggle  stop or start it (Mod+Shift+M)
#
# Locks with swaylock after 10 min, turns monitors off at the same time
# (matching the X defaults xss-lock followed), and locks before suspend.
set -uo pipefail

LOCK='swaylock -f'
LOCK_AFTER=600
OFF_AFTER=600

notify() { notify-send -u "$1" -i "$2" "Monitor Sleep" "$3"; }

start() {
    setsid -f swayidle -w \
        timeout "$LOCK_AFTER" "$LOCK" \
        timeout "$OFF_AFTER" 'swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
        before-sleep "$LOCK" \
        lock "$LOCK" > /dev/null 2>&1
}

if ! command -v swayidle > /dev/null; then
    notify critical dialog-error "⚠️ swayidle not found — install swayidle."
    exit 1
fi

case "${1:-toggle}" in
    start)
        pgrep -u "$USER" -x swayidle > /dev/null || start
        ;;
    toggle)
        if pgrep -u "$USER" -x swayidle > /dev/null; then
            pkill -u "$USER" -x swayidle
            notify normal dialog-information "🔴 DISABLED — screen stays on, auto-lock paused."
        else
            start
            notify normal dialog-information "🟢 ENABLED — locks after ${LOCK_AFTER}s, off after ${OFF_AFTER}s."
        fi
        ;;
    *)
        echo "usage: $0 [start|toggle]" >&2
        exit 2
        ;;
esac
