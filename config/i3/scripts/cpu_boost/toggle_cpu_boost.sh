#!/bin/bash
set -uo pipefail

GLOBAL="/sys/devices/system/cpu/cpufreq/boost"

notify() { notify-send -u "$1" -i "$2" "CPU Boost" "$3"; }

if [ -f "$GLOBAL" ]; then
    FILES=("$GLOBAL")
elif compgen -G "/sys/devices/system/cpu/cpufreq/policy*/boost" > /dev/null; then
    FILES=(/sys/devices/system/cpu/cpufreq/policy*/boost)
else
    notify critical dialog-error "⚠️ Boost control unavailable on this system."
    exit 1
fi

current=$(cat "${FILES[0]}")
target=$(( current == 1 ? 0 : 1 ))

for f in "${FILES[@]}"; do
    if ! err=$(echo "$target" | sudo -n /usr/bin/tee "$f" 2>&1 >/dev/null); then
        notify critical dialog-error "⚠️ Write failed: ${err:-sudo denied}"
        exit 1
    fi
done

new=$(cat "${FILES[0]}")
if [ "$new" != "$target" ]; then
    notify critical dialog-error "⚠️ Kernel ignored the change (boost still $new)."
    exit 1
fi

if [ "$new" = "1" ]; then
    notify normal dialog-information "🟢 ENABLED — cores can boost above base frequency."
else
    notify normal dialog-information "🔴 DISABLED — cores running at base frequency."
fi
