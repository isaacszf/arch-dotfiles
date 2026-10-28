# dotfiles-niri

My desktops on plain Arch Linux: niri (the main one), sway, and the i3 setup both were ported from. The niri desktop uses the shell, lock screen and wallpaper from [Pond](https://github.com/bflycomputer/pond-interface), the desktop made by Butterfly. I build it locally from a pinned commit instead of installing the Pond distro, so there's no Butterfly pacman repo or signing key involved.

## What's here

```
pkgbuild/pond-interface-local/   PKGBUILD + patches for Pond's desktop layer
config/niri/                     niri config (personal settings in cfg/, helper scripts in scripts/)
config/fuzzel/                   fuzzel launcher theme, styled like Pond's sidebar cards
config/sway/                     sway config, a Wayland port of the i3 one (scripts in scripts/)
config/i3/                       i3 config, i3blocks bar, layout and helper scripts
install.sh                       copies the configs into ~/.config (backs up what's there)
```

### Patches on top of Pond

| Patch | What it does |
|---|---|
| `sync-theme-icons.patch` | Fixes a shell crash. Quickshell's `image://icon` provider ran `QIcon::pixmap()` on a background thread when an `Image` was asynchronous. That raced Qt's icon cache and aborted in `QPixmap::scaled` with a pure virtual call. The patch loads the four theme-icon images synchronously. |
| `sidebar-temperature.patch` | Adds a CPU and GPU temperature card under the clock. It reads `k10temp` Tctl and `amdgpu` edge from hwmon every 3 s, and turns yellow from 70° and red from 90°. |
| `fuzzel-launcher.patch` | The sidebar's "+" button opens fuzzel instead of Vicinae. |

### Keybinds worth knowing

| Key | Action |
|---|---|
| `Mod+D` | fuzzel launcher |
| `Mod+Return` | kitty |
| `Mod+E` | Thunar |
| `Mod+O` | Overview |
| `Mod+Shift+Esc` | Show all keybinds |
| `Mod+Alt+L` | Lock |
| `Mod+Shift+M` | Toggle auto-lock / monitor sleep (swayidle) |
| `Mod+Shift+B` | Toggle CPU boost |

## Install

`./install.sh` installs all three. Name the ones you want to install only those, e.g. `./install.sh sway i3`.

### niri

1. Build and install the package. It pulls niri, quickshell, fuzzel and the rest as dependencies.
   ```sh
   cd pkgbuild/pond-interface-local
   makepkg -si
   sudo pacman -S swayidle
   ```
2. Copy the configs:
   ```sh
   ./install.sh
   niri validate
   ```
3. Pick **niri** in your display manager, or run `niri-session` from a TTY.

### sway

```sh
sudo pacman -S --needed sway swaylock swayidle wmenu grim slurp xdg-desktop-portal-wlr i3blocks dunst network-manager-applet flameshot
./install.sh sway
sway -C
```

Same keys, colors and bar as the i3 config. What differs:

- Monitors are `output` lines instead of `monitors_setup.sh`. Wayland names differ from xrandr: `HDMI-A-0` is `HDMI-A-1`, and `DisplayPort-1` should be `DP-2`. Check with `swaymsg -t get_outputs`.
- Launcher is `wmenu-run` instead of `dmenu_run`.
- `scripts/idle.sh` replaces xss-lock and i3lock: swaylock and monitors off after 10 min, lock before suspend. `Mod+Shift+M` toggles it.
- `Mod+Shift+R` reloads, since sway has no in-place restart.
- `Shift+Print` takes a region screenshot to the clipboard with grim and slurp, in case flameshot misbehaves.
- The `ws1.json` layout isn't restored, since sway has no `append_layout`.
- The bar uses the i3blocks setup from `config/i3`, so install that too.

### i3

```sh
sudo pacman -S --needed i3-wm i3lock xss-lock i3blocks dmenu dunst network-manager-applet flameshot xorg-xrandr xorg-xset lm_sensors
./install.sh i3
i3 -C
```

The bar runs scripts from [i3blocks-contrib](https://github.com/vivien/i3blocks-contrib). The installer clones it at a pinned commit into `~/.config/i3/scripts`, applies `i3blocks-contrib-temperature.patch` (shows CPU and GPU temperature instead of one sensor), and adds my own scripts next to it. It also writes `~/.i3blocks.conf`.

### Things you'll probably want to change

- `config/niri/cfg/display.kdl`: my monitor is `HDMI-A-1` at 1920x1080@144. Run `niri msg outputs` for yours. The sway config and `config/i3/scripts/monitors_setup/monitors_setup.sh` hard-code the same monitors.
- `config/niri/cfg/input.kdl`: keyboard layout is `br` (`abnt2`).
- `config/niri/cfg/misc.kdl`: the cursor theme is `aero-mini`, which isn't packaged. Change it or remove that block to use Pond's `capitaine-cursors`.
- The temperature card assumes an AMD CPU (`k10temp`) and AMD GPU (`amdgpu`). Edit the hwmon names in `shell/temperature/Card.qml` (in the patch) for other hardware.

### CPU boost toggle

`toggle_cpu_boost.sh` (one copy per desktop) writes to sysfs through `sudo -n tee`, so it needs a sudoers rule. Add it with `sudo visudo -f /etc/sudoers.d/cpu-boost` and replace `youruser`:

```
youruser ALL=(root) NOPASSWD: /usr/bin/tee /sys/devices/system/cpu/cpufreq/boost, /usr/bin/tee /sys/devices/system/cpu/cpufreq/policy[0-9]*/boost
```

## Known gaps

- The updates badge doesn't work. It calls Pond's own `pm` tool.
- The Wi-Fi panel needs NetworkManager.
- "Pond Gramercy" is Butterfly's proprietary font and isn't included, so titles that use it fall back to another font.

## Updating Pond

Review upstream changes before bumping `_commit` in the PKGBUILD:

```sh
git -C <your clone of pond-interface> log <old-commit>..origin/main
```

Then rebuild. If a patch no longer applies, it needs refreshing against the new commit.

## Credits

Pond's shell, lock screen and niri config are © Butterfly Interaction Inc., under the BSD 3-Clause License. The patches here modify that code and are under the same license. The Onest font is downloaded from Google Fonts under the SIL Open Font License.
