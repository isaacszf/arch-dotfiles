#!/bin/bash
# Copy the configs from this repo into ~/.config.
#
#   ./install.sh                 install everything (niri, i3)
#   ./install.sh i3              install only the ones named
#
# Anything already there is moved to ~/.config/dotfiles-backup-<timestamp>/ first.
# For niri, build and install the package (pkgbuild/pond-interface-local) before logging in.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$CONFIG/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# i3blocks-contrib commit the i3 bar scripts were taken from
CONTRIB_URL="https://github.com/vivien/i3blocks-contrib"
CONTRIB_COMMIT="9d66d81da8d521941a349da26457f4965fd6fcbd"

backup() {
    local src="$1" name="$2"
    if [ -e "$src" ] || [ -L "$src" ]; then
        mkdir -p "$BACKUP"
        mv "$src" "$BACKUP/$name"
        echo "Backed up $src to $BACKUP/$name"
    fi
}

install_niri() {
    for dir in niri fuzzel; do
        backup "$CONFIG/$dir" "$dir"
        cp -r "$REPO/config/$dir" "$CONFIG/$dir"
    done

    # Pond's shell integration (keybinds, layer rules) follows the installed package.
    ln -s /usr/share/pond-interface/config/niri/shell "$CONFIG/niri/shell"
    chmod +x "$CONFIG/niri/scripts/"*.sh
    echo "niri installed. Check it with: niri validate"
}

install_i3() {
    backup "$CONFIG/i3" i3
    backup "$HOME/.i3blocks.conf" i3blocks.conf

    mkdir -p "$CONFIG/i3"
    cp "$REPO/config/i3/config" "$CONFIG/i3/config"
    cp -r "$REPO/config/i3/layouts" "$CONFIG/i3/layouts"

    # The bar runs scripts from i3blocks-contrib, with a patched temperature
    # block (CPU + GPU). My own scripts live in the same folder.
    git clone --quiet "$CONTRIB_URL" "$CONFIG/i3/scripts"
    git -C "$CONFIG/i3/scripts" checkout --quiet "$CONTRIB_COMMIT"
    git -C "$CONFIG/i3/scripts" apply "$REPO/config/i3/i3blocks-contrib-temperature.patch"
    cp -r "$REPO/config/i3/scripts/." "$CONFIG/i3/scripts/"

    sed "s|^SCRIPT_DIR=.*|SCRIPT_DIR=$CONFIG/i3/scripts|" \
        "$REPO/config/i3/i3blocks.conf" > "$HOME/.i3blocks.conf"
    echo "i3 installed. Check it with: i3 -C"
}

targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=(niri i3)

for t in "${targets[@]}"; do
    case "$t" in
        niri|i3) "install_$t" ;;
        *) echo "usage: $0 [niri] [i3]" >&2; exit 2 ;;
    esac
done
