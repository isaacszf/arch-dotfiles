#!/bin/bash
# Toggle monitor sleep (DPMS + X screensaver blanking).
#
# Requires xorg-xset (already installed: xorg-xset 1.2.6-1).
#
# Turning DPMS off also stops the X screensaver timer, which is what xss-lock
# watches, so automatic locking is suspended too while sleep is disabled. The
# screensaver timeout is saved before it is cleared and restored on the way
# back, because "xset s on" would otherwise reset it to the server default.
set -uo pipefail

STATE="${XDG_CACHE_HOME:-$HOME/.cache}/i3-dpms-toggle.state"

notify() { notify-send -u "$1" -i "$2" "Monitor Sleep" "$3"; }

if ! command -v xset > /dev/null; then
    notify critical dialog-error "⚠️ xset not found — install xorg-xset."
    exit 1
fi

if ! q=$(xset q 2>&1); then
    notify critical dialog-error "⚠️ Cannot reach the X server: ${q}"
    exit 1
fi

read -r standby suspend off < <(awk '/Standby:/ {print $2, $4, $6}' <<< "$q")

if grep -q "DPMS is Enabled" <<< "$q"; then
    read -r timeout cycle < <(awk '/timeout:/ {print $2, $4}' <<< "$q")
    mkdir -p "$(dirname "$STATE")"
    printf '%s %s %s %s %s\n' "$timeout" "$cycle" "$standby" "$suspend" "$off" > "$STATE"

    if ! err=$(xset s off -dpms 2>&1); then
        notify critical dialog-error "⚠️ Failed to disable: ${err}"
        exit 1
    fi

    if xset q | grep -q "DPMS is Enabled"; then
        notify critical dialog-error "⚠️ X server ignored the change (DPMS still on)."
        exit 1
    fi

    notify normal dialog-information "🔴 DISABLED — screen stays on, auto-lock paused."
else
    timeout=600 cycle=600
    if [ -r "$STATE" ]; then
        read -r timeout cycle standby suspend off < "$STATE"
    fi

    if ! err=$(xset s "$timeout" "$cycle" +dpms dpms "$standby" "$suspend" "$off" 2>&1); then
        notify critical dialog-error "⚠️ Failed to enable: ${err}"
        exit 1
    fi

    if ! xset q | grep -q "DPMS is Enabled"; then
        notify critical dialog-error "⚠️ X server ignored the change (DPMS still off)."
        exit 1
    fi

    notify normal dialog-information "🟢 ENABLED — blanks after ${timeout}s, off after ${off}s."
fi
