#!/bin/bash
# Auto-lock and monitor sleep for niri, the Wayland counterpart of xss-lock + DPMS under i3.
#
#   idle.sh start   start swayidle (used by autostart.kdl)
#   idle.sh toggle  stop or start it (Mod+Shift+M)
#
# Locks with Pond's lock screen after 10 min, turns monitors off 1 min later,
# and locks before suspend. Requires swayidle.
set -uo pipefail

LOCK='/usr/bin/qs -p /usr/share/pond-interface/lockscreen ipc call lockscreen lock || /usr/bin/qs -d -p /usr/share/pond-interface/lockscreen'
LOCK_AFTER=600
OFF_AFTER=660

notify() { notify-send -u "$1" -i "$2" "Monitor Sleep" "$3"; }

start() {
    setsid -f swayidle -w \
        timeout "$LOCK_AFTER" "$LOCK" \
        timeout "$OFF_AFTER" 'niri msg action power-off-monitors' \
        before-sleep "$LOCK" > /dev/null 2>&1
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
