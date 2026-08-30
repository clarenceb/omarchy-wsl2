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
bindsym \$mod+Shift+w exec omarchy-wsl-bg next

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

# Mouse handling. Tiled windows have no titlebar to grab - that is the point
# of a tiling WM - so dragging is done with the modifier held:
#   SUPER + left-drag   move a floating window
#   SUPER + right-drag  resize any window
floating_modifier \$mod normal

# Keyboard resizing for tiled windows.
bindsym \$mod+r mode "resize"

# Floating windows get a real titlebar, so dialogs stay draggable by mouse.
for_window [floating] border normal 2

# Omarchy's TUI launchers pass --app-id=TUI.float / TUI.tile through
# xdg-terminal-exec; honour those hints.
for_window [app_id="TUI.float"] floating enable, resize set 1100 700
for_window [app_id="TUI.tile"] floating disable

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

# --- resize mode ----------------------------------------------------------
# SUPER+R enters it; arrows or hjkl resize; Escape/Enter leaves.
mode "resize" {
    bindsym h resize shrink width 40px
    bindsym j resize grow height 40px
    bindsym k resize shrink height 40px
    bindsym l resize grow width 40px
    bindsym Left  resize shrink width 40px
    bindsym Down  resize grow height 40px
    bindsym Up    resize shrink height 40px
    bindsym Right resize grow width 40px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}

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
# Secret Service provider, so Copilot CLI / gh / VS Code can store tokens
# instead of falling back to plaintext. See omarchy-wsl-keyring.
exec --no-startup-id sh -c 'command -v gnome-keyring-daemon >/dev/null 2>&1 && printf "\n" | gnome-keyring-daemon --start --components=secrets,ssh >/dev/null 2>&1 || true'
# Omarchy keeps the active wallpaper at ~/.config/omarchy/current/background,
# which is a symlink that only exists once a theme has been applied. swaybg
# does NOT exit non-zero on a missing image - it just logs "Could not find
# config for output" and draws nothing - so test for the file first rather
# than relying on shell ||. Fall back to our own generated wallpaper.
exec --no-startup-id sh -c 'bg="$HOME/.config/omarchy/current/background"; \
  [ -r "$bg" ] || bg=/usr/share/omarchy-wsl2/wallpapers/omarchy-wsl2.png; \
  if [ -r "$bg" ]; then exec swaybg -m fill -i "$bg"; else exec swaybg -c "#0d1120"; fi'

# A tiling desktop with nothing running is just a wallpaper, and SUPER is
# often swallowed by Windows in nested mode - so open a terminal on first
# start. Users who dislike it can drop a `# no-welcome` marker in local.conf.
EOF

# Appended outside the quoted heredoc so $TERMINAL expands to the terminal we
# actually found at build time.
cat >>/etc/skel/.config/sway/config <<EOF
exec --no-startup-id sh -c 'grep -qs no-welcome "\$HOME/.config/sway/local.conf" || exec $TERMINAL -e bash -lic "omarchy-wsl-help; exec bash -i"'
EOF

cat >>/etc/skel/.config/sway/config <<'EOF'

# Per-user theme overrides, written by the Omarchy theme bridge.
include ~/.config/sway/theme.conf
include ~/.config/sway/local.conf
EOF

chmod 0644 /etc/skel/.config/sway/config

# `include` on a missing file is a hard error in sway, so ship empty stubs.
: >/etc/skel/.config/sway/theme.conf
: >/etc/skel/.config/sway/local.conf

# Tiling is Omarchy's model, but it is a big adjustment coming from Windows
# or GNOME. OMARCHY_LAYOUT=floating bakes the familiar behaviour in instead;
# either way `omarchy-wsl-desktop --floating/--tiling` flips it at runtime.
if [[ ${OMARCHY_LAYOUT:-tiling} == floating ]]; then
  info "  default window layout: floating"
  cat >/etc/skel/.config/sway/local.conf <<'EOF'
# >>> omarchy-wsl2 layout >>>
# Windows float with titlebars, like Windows or GNOME.
# Switch back with: omarchy-wsl-desktop --tiling
for_window [app_id=".*"] floating enable
for_window [class=".*"] floating enable
default_border normal 2
# <<< omarchy-wsl2 layout <<<
EOF
else
  info "  default window layout: tiling"
fi

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
  "height": 34,
  "spacing": 4,
  "margin-top": 6,
  "margin-left": 10,
  "margin-right": 10,
  "modules-left": ["sway/workspaces", "sway/mode"],
  "modules-center": ["clock"],
  "modules-right": ["cpu", "memory", "pulseaudio", "tray", "custom/distro"],

  "sway/workspaces": {
    "disable-scroll": true,
    "all-outputs": true,
    "format": "{name}"
  },
  "sway/mode": { "format": "  {}" },
  "cpu":    { "format": "  {usage}%", "interval": 5 },
  "memory": { "format": "  {}%",     "interval": 5 },
  "clock":  {
    "format": "{:%a %d %b   %H:%M}",
    "tooltip-format": "<tt>{calendar}</tt>"
  },
  "pulseaudio": {
    "format": "{icon}  {volume}%",
    "format-muted": "  muted",
    "format-icons": { "default": ["", "", ""] },
    "on-click": "pamixer -t"
  },
  "tray": { "spacing": 8 },
  "custom/distro": {
    "format": "  omarchy",
    "tooltip-format": "omarchy-wsl2 - sway session\nSUPER+Return terminal, SUPER+Space launcher"
  }
}
EOF

# A self-contained stylesheet: a floating, translucent pill bar. sway has no
# blur or rounded window corners, so the bar and the wallpaper carry the look.
cat >/etc/skel/.config/waybar-sway/style.css <<'EOF'
* {
  font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font", monospace;
  font-size: 13px;
  border: none;
  border-radius: 0;
  min-height: 0;
}

window#waybar {
  background: transparent;
}

/* Each module group is its own floating pill. */
#workspaces,
#mode,
#clock,
#cpu,
#memory,
#pulseaudio,
#tray,
#custom-distro {
  background: rgba(13, 17, 32, 0.82);
  color: #cdd6f4;
  padding: 2px 14px;
  margin: 0 3px;
  border-radius: 14px;
}

#workspaces {
  padding: 2px 6px;
}

#workspaces button {
  padding: 0 9px;
  margin: 2px 1px;
  color: #6c7394;
  background: transparent;
  border-radius: 10px;
  transition: all 0.15s ease;
}

#workspaces button:hover {
  background: rgba(91, 75, 214, 0.25);
  color: #cdd6f4;
}

#workspaces button.focused,
#workspaces button.visible {
  background: linear-gradient(135deg, #5b4bd6, #2aa6c4);
  color: #ffffff;
  font-weight: bold;
}

#workspaces button.urgent {
  background: #d83b01;
  color: #ffffff;
}

#clock {
  color: #ffffff;
  font-weight: bold;
  padding: 2px 18px;
}

#cpu    { color: #3ddcc8; }
#memory { color: #7c6cf5; }

#pulseaudio.muted {
  color: #6c7394;
}

#custom-distro {
  background: linear-gradient(135deg, #5b4bd6, #2aa6c4);
  color: #ffffff;
  font-weight: bold;
}

#mode {
  background: #e8842b;
  color: #13233a;
  font-weight: bold;
}

tooltip {
  background: rgba(13, 17, 32, 0.96);
  border: 1px solid rgba(91, 75, 214, 0.6);
  border-radius: 10px;
}

tooltip label {
  color: #cdd6f4;
}
EOF

chmod 0644 /etc/skel/.config/waybar-sway/config.jsonc \
           /etc/skel/.config/waybar-sway/style.css

# ------------------------------------------------------- wofi + mako ---
info "Writing the launcher and notification styling"
install -d -m 0755 /etc/skel/.config/wofi /etc/skel/.config/mako

cat >/etc/skel/.config/wofi/config <<EOF
# term= is what makes Terminal=true .desktop entries launch at all; without
# it wofi silently does nothing for TUI apps like btop.
term=$TERMINAL
show=drun
width=520
height=380
prompt=Run
insensitive=true
allow_images=true
image_size=24
no_actions=true
gtk_dark=true
EOF

cat >/etc/skel/.config/wofi/style.css <<'EOF'
window {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 13px;
  background: rgba(13, 17, 32, 0.94);
  border: 1px solid rgba(91, 75, 214, 0.7);
  border-radius: 16px;
  color: #cdd6f4;
}

#input {
  margin: 12px;
  padding: 10px 14px;
  border: none;
  border-radius: 12px;
  background: rgba(27, 35, 64, 0.9);
  color: #ffffff;
}

#input:focus {
  border: 1px solid #2aa6c4;
}

#inner-box { margin: 6px 12px 12px 12px; }
#scroll    { margin: 0; }

#entry {
  padding: 9px 12px;
  border-radius: 10px;
}

#entry:selected {
  background: linear-gradient(135deg, #5b4bd6, #2aa6c4);
  color: #ffffff;
}

#text:selected { color: #ffffff; }
EOF

cat >/etc/skel/.config/mako/config <<'EOF'
font=JetBrainsMono Nerd Font 11
background-color=#0d1120ee
text-color=#cdd6f4
border-color=#5b4bd6
border-size=1
border-radius=12
padding=12
margin=8
default-timeout=6000
anchor=top-right
max-visible=4

[urgency=critical]
border-color=#d83b01
default-timeout=0
EOF

chmod 0644 /etc/skel/.config/wofi/config /etc/skel/.config/wofi/style.css \
           /etc/skel/.config/mako/config

# ----------------------------------------------------------- wallpapers ---
# Shipped as the fallback for before any Omarchy theme has been applied.
# Once omarchy-theme-set runs, ~/.config/omarchy/current/background wins.
if [[ -d $SRC_DIR/assets/wallpapers ]]; then
  info "Installing fallback wallpapers"
  install -d -m 0755 /usr/share/omarchy-wsl2/wallpapers
  install -m 0644 "$SRC_DIR/assets/wallpapers/"*.png \
    /usr/share/omarchy-wsl2/wallpapers/ 2>/dev/null || true
fi

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

# -------------------------------------------------------- desktop entries ---
# Omarchy ships two sets of .desktop files that we were not installing:
#
#   applications/*.desktop         its own launchers (Docker, Disk Usage, the
#                                  web apps) - these call xdg-terminal-exec,
#                                  for which we ship a shim
#   applications/hidden/*.desktop  21 `Hidden=true` stubs that suppress junk
#                                  pulled in as dependencies - avahi-discover,
#                                  qv4l2, cmake-gui, the fcitx5 family, ...
#
# Without the second set the launcher lists tools that cannot work here and
# fail with things like "No module named 'dbus'".
info "Installing Omarchy's desktop entries"
APPS_DIR=/etc/skel/.local/share/applications
install -d -m 0755 "$APPS_DIR"

if [[ -d $OMARCHY_SHARE/applications ]]; then
  find "$OMARCHY_SHARE/applications" -maxdepth 1 -name '*.desktop' \
    -exec install -m 0644 {} "$APPS_DIR/" \; 2>/dev/null || true
  find "$OMARCHY_SHARE/applications/hidden" -maxdepth 1 -name '*.desktop' \
    -exec install -m 0644 {} "$APPS_DIR/" \; 2>/dev/null || true
  if [[ -d $OMARCHY_SHARE/applications/icons ]]; then
    install -d -m 0755 /etc/skel/.local/share/icons
    find "$OMARCHY_SHARE/applications/icons" -maxdepth 1 -type f \
      -exec install -m 0644 {} /etc/skel/.local/share/icons/ \; 2>/dev/null || true
  fi
  info "  installed $(find "$APPS_DIR" -name '*.desktop' | wc -l) entries"
else
  info "  no applications/ in the Omarchy checkout - skipping"
fi

# Entries that are meaningless under WSL2 specifically, on top of Omarchy's
# own list. A Hidden=true stub in ~/.local/share/applications masks the
# system copy without touching pacman-owned files.
info "Hiding desktop entries that cannot work under WSL2"
for junk in \
  avahi-discover bssh bvnc \
  org.freedesktop.MalcontentControl \
  qv4l2 qvidcap \
  xgps xgpsspeed \
  cups cmake-gui \
  nm-connection-editor \
  lstopo \
  electron34 electron35 electron36 \
  uuctl \
  hyprland
do
  printf '[Desktop Entry]\nHidden=true\n' >"$APPS_DIR/${junk}.desktop"
  chmod 0644 "$APPS_DIR/${junk}.desktop"
done

info "Desktop tier installed"
