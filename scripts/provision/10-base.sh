#!/bin/bash
# 10-base.sh - install the headless CLI/TUI tier.
set -euo pipefail

read_packages() {
  # Strip comments and blank lines from a .packages file.
  sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1" | tr -d '\r'
}

mapfile -t PKGS < <(read_packages "$SRC_DIR/packages/base.packages")
info "Installing ${#PKGS[@]} base packages"

# Install as one transaction so pacman can resolve conflicts sensibly, but fall
# back to one-by-one so a single unavailable package (common on aarch64) does
# not abort the whole build.
if ! pacman -S --noconfirm --needed "${PKGS[@]}" >/dev/null 2>&1; then
  info "Bulk install failed; retrying individually"
  MISSING=()
  for p in "${PKGS[@]}"; do
    pacman -S --noconfirm --needed "$p" >/dev/null 2>&1 || MISSING+=("$p")
  done
  if (( ${#MISSING[@]} )); then
    info "Unavailable on $TARGET_ARCH: ${MISSING[*]}"
    printf '%s\n' "${MISSING[@]}" >>/var/log/omarchy-wsl2-missing.log
  fi
fi

info "Enabling useful system services"
systemctl enable systemd-timesyncd.service >/dev/null 2>&1 || true

# WSL manages networking itself, and these units fight it.
#
# NOTE: Microsoft's custom-distro guidance also lists tmp.mount and the
# systemd-tmpfiles-* units, but masking those breaks the per-user systemd
# session on modern systemd:
#   user@1000.service: Failed to spawn executor: Device or resource busy
# systemd's executor needs a working /tmp, and /run/user/<uid> has to be set
# up, so we deliberately leave them enabled.
info "Masking systemd units that conflict with WSL networking"
for unit in \
  systemd-resolved.service \
  systemd-networkd.service \
  NetworkManager.service
do
  systemctl mask "$unit" >/dev/null 2>&1 || true
done

info "Base tier installed"
