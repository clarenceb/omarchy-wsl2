#!/bin/bash
# 40-desktop.sh - the nested/VNC Hyprland session tier.
set -euo pipefail

if ! want_desktop; then
  info "Profile '$PROFILE' - skipping the Hyprland desktop tier"
  exit 0
fi

mapfile -t PKGS < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' \
  "$SRC_DIR/packages/desktop.packages" | tr -d '\r')

info "Installing ${#PKGS[@]} desktop packages"
for p in "${PKGS[@]}"; do
  pacman -S --noconfirm --needed "$p" >/dev/null 2>&1 \
    || { info "  unavailable on $TARGET_ARCH: $p"; echo "$p" >>/var/log/omarchy-wsl2-missing.log; }
done

if ! command -v sway >/dev/null 2>&1; then
  info "WARNING: sway was not installed - only modes 1 and 2 will work."
fi

# seatd is only needed by wlroots' DRM/libinput backends. Our session uses the
# headless and Wayland backends, which need no seat at all - but the service is
# harmless and makes `sway` usable if a future WSL kernel ever exposes DRM.
info "Enabling seatd"
systemctl enable seatd.service >/dev/null 2>&1 || true

# ---------------------------------------------------------------- sway ---
# The session that actually works under WSL2. wlroots falls back to a shm
# allocator when neither backend nor renderer needs DMABUF, so pixman +
# headless/wayland runs with no DRM device at all.
info "Writing the sway session config"
install -d -m 0755 /etc/skel/.config/sway

# Prefer Omarchy's terminal, fall back to whatever is present.
if command -v alacritty >/dev/null 2>&1; then TERMINAL=alacritty
elif command -v foot >/dev/null 2>&1;      then TERMINAL=foot
else                                            TERMINAL=xterm
fi

cat >/etc/skel/.config/sway/config <<EOF
# omarchy-wsl2 sway session
#
# Omarchy is a Hyprland distribution, but Hyprland cannot start under WSL2:
# its backend (Aquamarine) requires a GBM allocator built from a DRM node,
# and WSL2 exposes no DRM device. sway/wlroots can fall back to shm buffers,
# so this config reproduces Omarchy's keybindings and look on wlroots.
#
# See /usr/share/omarchy-wsl2/docs/12-wayland-on-wsl2.md

set \$mod Mod4
set \$term $TERMINAL
set \$menu wofi --show drun

# --- Omarchy-style keybindings -------------------------------------------
bindsym \$mod+Return exec \$term
bindsym \$mod+w kill
bindsym \$mod+space exec \$menu
bindsym \$mod+b exec chromium
bindsym \$mod+e exec nautilus
bindsym \$mod+Shift+e exit
bindsym \$mod+Shift+r reload

# focus / move, vim keys and arrows
bindsym \$mod+h focus left
bindsym \$mod+j focus down
bindsym \$mod+k focus up
bindsym \$mod+l focus right
bindsym \$mod+Left focus left
bindsym \$mod+Down focus down
bindsym \$mod+Up focus up
bindsym \$mod+Right focus right
bindsym \$mod+Shift+h move left
bindsym \$mod+Shift+j move down
bindsym \$mod+Shift+k move up
bindsym \$mod+Shift+l move right

bindsym \$mod+f fullscreen
bindsym \$mod+v splitv
bindsym \$mod+g splith
bindsym \$mod+t layout tabbed
bindsym \$mod+Shift+space floating toggle

# workspaces
EOF

for i in 1 2 3 4 5 6 7 8 9; do
  printf 'bindsym $mod+%s workspace number %s\n' "$i" "$i" \
    >>/etc/skel/.config/sway/config
  printf 'bindsym $mod+Shift+%s move container to workspace number %s\n' "$i" "$i" \
    >>/etc/skel/.config/sway/config
done

cat >>/etc/skel/.config/sway/config <<'EOF'

# --- screenshots ----------------------------------------------------------
# Written here rather than above so the shell substitution reaches sway
# verbatim and is evaluated at keypress time.
bindsym Print exec grim -g "$(slurp)" - | satty -f -
bindsym Shift+Print exec grim - | wl-copy

# --- appearance -----------------------------------------------------------
# Omarchy's gaps-and-rounded-corners feel. Colours are overwritten by
# omarchy-theme-set via ~/.config/sway/theme.conf (sourced below).
default_border pixel 2
gaps inner 8
gaps outer 4
font pango:JetBrainsMono Nerd Font 10

# --- WSL2 specifics -------------------------------------------------------
# No physical inputs: everything arrives from WSLg or wayvnc's virtual
# devices, so do not fail when libinput finds nothing.
input * {
    xkb_layout us
}

# Software cursors only - there are no DRM planes to put a hardware one on.
seat * hide_cursor when-typing enable

# WSLg already owns /tmp/.X11-unix and every display slot in it, so sway's
# own Xwayland cannot claim one:
#     xwayland/sockets.c: No display available in the first 33
#     sway/server.c: Failed to start Xwayland
# X11 apps should be run through WSLg instead (omarchy-wsl-app). Disabling
# this removes a wall of startup errors and speeds up launch.
xwayland disable

# --- autostart ------------------------------------------------------------
# -c/-s point waybar at the sway-native config; Omarchy's own config.jsonc is
# left in place but is Hyprland-specific.
exec_always --no-startup-id waybar -c ~/.config/waybar-sway/config.jsonc -s ~/.config/waybar-sway/style.css
exec --no-startup-id mako
# Omarchy keeps the active wallpaper at ~/.config/omarchy/current/background,
# which is a symlink that only exists once a theme has been applied. swaybg
# does NOT exit non-zero on a missing image - it just logs "Could not find
# config for output" and draws nothing - so test for the file first rather
# than relying on shell ||.
exec --no-startup-id sh -c 'bg="$HOME/.config/omarchy/current/background"; \
  if [ -r "$bg" ]; then exec swaybg -m fill -i "$bg"; else exec swaybg -c "#13233A"; fi'

# Per-user theme overrides, written by the Omarchy theme bridge.
include ~/.config/sway/theme.conf
include ~/.config/sway/local.conf
EOF

chmod 0644 /etc/skel/.config/sway/config

# `include` on a missing file is a hard error in sway, so ship empty stubs.
: >/etc/skel/.config/sway/theme.conf
: >/etc/skel/.config/sway/local.conf
chmod 0644 /etc/skel/.config/sway/theme.conf /etc/skel/.config/sway/local.conf

# ---------------------------------------------------------------- waybar ---
# Omarchy's own waybar config uses hyprland/workspaces and hyprland/window,
# which need HYPRLAND_INSTANCE_SIGNATURE and simply switch themselves off
# under sway:
#     module hyprland/workspaces: Disabling module ... (Is Hyprland running?)
# Ship a sway-native config in a separate directory and point waybar at it
# from the session, leaving Omarchy's file untouched for reference.
info "Writing the sway waybar config"
install -d -m 0755 /etc/skel/.config/waybar-sway
cat >/etc/skel/.config/waybar-sway/config.jsonc <<'EOF'
{
  "layer": "top",
  "position": "top",
  "height": 26,
  "spacing": 8,
  "modules-left": ["sway/workspaces", "sway/mode"],
  "modules-center": ["sway/window"],
  "modules-right": ["pulseaudio", "cpu", "memory", "clock", "tray"],

  "sway/workspaces": {
    "disable-scroll": true,
    "all-outputs": true,
    "format": "{name}"
  },
  "sway/window": {
    "max-length": 60,
    "tooltip": false
  },
  "cpu":    { "format": "  {usage}%", "interval": 5 },
  "memory": { "format": "  {}%",     "interval": 5 },
  "clock":  {
    "format": "  {:%a %d %b  %H:%M}",
    "tooltip-format": "<tt>{calendar}</tt>"
  },
  "pulseaudio": {
    "format": "{icon}  {volume}%",
    "format-muted": "  muted",
    "format-icons": { "default": ["", "", ""] },
    "on-click": "pamixer -t"
  },
  "tray": { "spacing": 8 }
}
EOF

# A self-contained stylesheet. Omarchy's own style.css targets its
# Hyprland-specific module IDs, and @import-ing a file that may not exist
# leaves waybar unstyled, so keep this standalone.
cat >/etc/skel/.config/waybar-sway/style.css <<'EOF'
* {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 12px;
  border: none;
  border-radius: 0;
  min-height: 0;
}

window#waybar {
  background: rgba(19, 35, 58, 0.92);
  color: #e6edf3;
}

#workspaces button {
  padding: 0 8px;
  color: #8b98a5;
  background: transparent;
}

#workspaces button.focused,
#workspaces button.visible {
  color: #e6edf3;
  box-shadow: inset 0 -2px #2aa6c4;
}

#workspaces button.urgent {
  color: #c0392b;
}

#mode {
  padding: 0 8px;
  color: #ffd479;
}

#window {
  color: #b6c2cf;
}

#cpu, #memory, #clock, #pulseaudio, #tray {
  padding: 0 8px;
}

#clock {
  color: #e6edf3;
  font-weight: bold;
}

#pulseaudio.muted {
  color: #8b98a5;
}
EOF

chmod 0644 /etc/skel/.config/waybar-sway/config.jsonc \
           /etc/skel/.config/waybar-sway/style.css

# ------------------------------------------------------------- hyprland ---
# Kept so Omarchy's own hypr* configs stay readable and diffable, and so the
# session starts working the day Aquamarine grows an shm path. It cannot run
# today - see the doc referenced above.
info "Writing the WSL Hyprland overrides (reference only)"
install -d -m 0755 /etc/skel/.config/hypr/conf
cat >/etc/skel/.config/hypr/conf/wsl.conf <<'EOF'
# omarchy-wsl2 overrides
#
# NOTE: Hyprland does not start under WSL2 at all. Aquamarine requires a GBM
# allocator built from a DRM node; WSL2 exposes only /dev/dxg, and WSLg does
# not advertise zwp_linux_dmabuf_v1. This file is retained for reference and
# for the day that changes. Use sway - see omarchy-wsl-desktop.

# A single virtual output.
monitor = , preferred, auto, 1

$omarchy_wsl = 1

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    vfr = true
    vrr = 0
}

render {
    direct_scanout = false
}

cursor {
    no_hardware_cursors = true
    allow_dumb_copy = true
}
EOF

info "Desktop tier installed"
