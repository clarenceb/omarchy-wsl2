#!/bin/bash
# scripts/fetch-rootfs.sh - download the Arch base root filesystem.
#
#   x86_64   official Arch Linux WSL image  (archlinux-wsl, built monthly)
#   aarch64  Arch Linux ARM generic rootfs  (Arch proper has no ARM port)
#
# Usage: scripts/fetch-rootfs.sh <cache-dir>

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CACHE_DIR="${1:?usage: fetch-rootfs.sh <cache-dir>}"
ARCH_TARGET="$(target_arch)"
ensure_dir "$CACHE_DIR"

ARCH_WSL_MIRROR="${ARCH_WSL_MIRROR:-https://geo.mirror.pkgbuild.com/wsl/latest}"
ALARM_URL="${ALARM_URL:-http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz}"

fetch() {
  local url="$1" out="$2"
  if [[ -s $out ]]; then
    step "Using cached $(basename "$out") ($(human_size "$(stat -c%s "$out")"))"
    return 0
  fi
  step "Downloading $url"
  curl -fL --progress-bar --retry 3 --retry-delay 2 -o "$out.part" "$url" \
    || die "Download failed: $url"
  mv "$out.part" "$out"
  step "Saved $(basename "$out") ($(human_size "$(stat -c%s "$out")"))"
}

case "$ARCH_TARGET" in
  x86_64)
    log "Fetching official Arch Linux WSL image (x86_64)"
    # The directory listing names the current build, e.g. archlinux-2026.08.01.174141.wsl
    image_name=$(curl -fsSL "$ARCH_WSL_MIRROR/" \
      | grep -oE 'archlinux-[0-9.]+\.wsl' | sort -u | tail -1) \
      || die "Could not list $ARCH_WSL_MIRROR"
    [[ -z $image_name ]] && die "No archlinux-*.wsl found at $ARCH_WSL_MIRROR"
    fetch "$ARCH_WSL_MIRROR/$image_name" "$CACHE_DIR/base-x86_64.tar.gz"
    ;;

  aarch64)
    log "Fetching Arch Linux ARM generic rootfs (aarch64)"
    warn "Arch Linux ARM is a separate project from Arch Linux."
    warn "Omarchy's own pacman repo has no aarch64 packages - see docs/08-arm64.md."
    fetch "$ALARM_URL" "$CACHE_DIR/base-aarch64.tar.gz"
    ;;
esac

log "Base rootfs ready in $CACHE_DIR"
