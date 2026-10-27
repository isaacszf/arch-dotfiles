#!/bin/bash
# Copy the niri and fuzzel configs from this repo into ~/.config.
# Anything already there is moved to ~/.config/dotfiles-niri-backup-<timestamp>/ first.
# Build and install the package (pkgbuild/pond-interface-local) before logging into niri.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$CONFIG/dotfiles-niri-backup-$(date +%Y%m%d-%H%M%S)"

for dir in niri fuzzel; do
    if [ -e "$CONFIG/$dir" ]; then
        mkdir -p "$BACKUP"
        mv "$CONFIG/$dir" "$BACKUP/$dir"
        echo "Backed up $CONFIG/$dir to $BACKUP/$dir"
    fi
    cp -r "$REPO/config/$dir" "$CONFIG/$dir"
done

# Pond's shell integration (keybinds, layer rules) follows the installed package.
ln -s /usr/share/pond-interface/config/niri/shell "$CONFIG/niri/shell"
chmod +x "$CONFIG/niri/scripts/"*.sh

echo "Installed. Check it with: niri validate"
