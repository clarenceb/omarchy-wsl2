#!/bin/bash
# 30-apps.sh - graphical applications launched individually through WSLg.
set -euo pipefail

if ! want_apps; then
  info "Profile '$PROFILE' - skipping the GUI apps tier"
  exit 0
fi

mapfile -t PKGS < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' \
  "$SRC_DIR/packages/apps.packages" | tr -d '\r')

info "Installing ${#PKGS[@]} GUI application packages"
for p in "${PKGS[@]}"; do
  pacman -S --noconfirm --needed "$p" >/dev/null 2>&1 \
    || { info "  unavailable on $TARGET_ARCH: $p"; echo "$p" >>/var/log/omarchy-wsl2-missing.log; }
done

# Mesa's d3d12 Gallium driver is what turns WSLg's /dev/dxg into working
# OpenGL. vulkan-dzn is the (experimental) Direct3D12 Vulkan layer.
info "Installing WSLg graphics drivers"
for p in mesa mesa-utils vulkan-icd-loader vulkan-dzn libva-utils; do
  pacman -S --noconfirm --needed "$p" >/dev/null 2>&1 || info "  unavailable: $p"
done

info "Setting up XDG user directories"
install -d -m 0755 /etc/skel/{Desktop,Documents,Downloads,Pictures,Videos,Music}

info "GUI apps tier installed"
