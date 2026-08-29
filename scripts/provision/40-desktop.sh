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

if ! command -v Hyprland >/dev/null 2>&1 && ! command -v hyprland >/dev/null 2>&1; then
  info "WARNING: Hyprland was not installed - only modes 1 and 2 will work."
fi

# seatd exists so wlroots can link against libseat. Under WSL there is no real
# seat to acquire, but having the service present avoids startup warnings.
info "Enabling seatd"
systemctl enable seatd.service >/dev/null 2>&1 || true

# A Hyprland config fragment that neutralises the bits which assume real
# hardware. Sourced from the user's hyprland.conf by 60-wsl.sh.
info "Writing the WSL Hyprland overrides"
install -d -m 0755 /etc/skel/.config/hypr/conf
cat >/etc/skel/.config/hypr/conf/wsl.conf <<'EOF'
# omarchy-wsl2 overrides
#
# WSL2 has no KMS-capable /dev/dri/cardN, so Hyprland runs either nested inside
# WSLg (Wayland backend) or headless behind wayvnc. These settings drop the
# bare-metal-only behaviour that would otherwise error out.

# A single virtual output; the nested window resizes with the host window.
monitor = , preferred, auto, 1

# No physical backlight, battery, lid switch or power button under WSL.
$omarchy_wsl = 1

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    # No vblank source on a virtual output - avoids a busy loop.
    vfr = true
    vrr = 0
}

# Direct scanout is meaningless without a real plane.
render {
    direct_scanout = false
}

# Hardware cursors need DRM planes; use a software cursor instead.
cursor {
    no_hardware_cursors = true
    allow_dumb_copy = true
}

# Keep these off: they drive real hardware that WSL does not expose.
# (hypridle/hyprlock/hyprsunset all assume a physical session)
EOF

info "Desktop tier installed"
