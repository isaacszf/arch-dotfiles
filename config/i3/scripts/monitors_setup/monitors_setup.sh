#!/bin/bash
# If DisplayPort-1 is connected, enable it; otherwise turn it off.
if xrandr | grep -q "^DisplayPort-1 connected"; then
xrandr \
    --output HDMI-A-0    --mode 1920x1080 --rate 144 --primary \
    --output DisplayPort-1 --mode 1920x1080 --rate 60
else
xrandr \
    --output HDMI-A-0    --mode 1920x1080 --rate 144 --primary \
    --output DisplayPort-1 --off
fi
