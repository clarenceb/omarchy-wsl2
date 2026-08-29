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

# WSL manages networking itself - these units fight it and are known to break
# WSL distros (per Microsoft's custom-distro guidance).
info "Masking systemd units that misbehave under WSL"
for unit in \
  systemd-resolved.service \
  systemd-networkd.service \
  NetworkManager.service \
  systemd-tmpfiles-setup.service \
  systemd-tmpfiles-clean.service \
  systemd-tmpfiles-clean.timer \
  systemd-tmpfiles-setup-dev-early.service \
  systemd-tmpfiles-setup-dev.service \
  tmp.mount
do
  systemctl mask "$unit" >/dev/null 2>&1 || true
done

info "Base tier installed"
