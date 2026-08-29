#!/bin/bash
# scripts/seed.sh - import the base Arch rootfs as a throwaway build distro.
#
# Usage: scripts/seed.sh <cache-dir> <build-dir> <build-distro-name>

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CACHE_DIR="${1:?usage: seed.sh <cache-dir> <build-dir> <distro>}"
BUILD_DIR="${2:?}"
BUILD_DISTRO="${3:?}"
ARCH_TARGET="$(target_arch)"
ROOTFS="$CACHE_DIR/base-${ARCH_TARGET}.tar.gz"

require_wsl_host
check_wsl_version

[[ -s $ROOTFS ]] || die "Base rootfs missing: $ROOTFS  (run: make fetch)"

unregister_distro "$BUILD_DISTRO"

# Any OTHER distro still registered against this directory also holds a lock on
# it, and --import then fails with ERROR_FILE_EXISTS. This happens when you
# build under a second NAME: 'omarchy-build' still owns BUILD_DIR while we are
# trying to import 'omarchy-desktop-build'.
for other in $(wslx --list --quiet | sed 's/\r//' | grep -- '-build$' || true); do
  [[ $other == "$BUILD_DISTRO" ]] && continue
  if [[ -f "$BUILD_DIR/ext4.vhdx" ]]; then
    warn "Distro '$other' still occupies $BUILD_DIR"
    step "Unregistering stale build distro '$other'"
    unregister_distro "$other"
  fi
done

ensure_dir "$BUILD_DIR"
# A stale install dir makes --import fail with ERROR_FILE_EXISTS.
rm -rf "${BUILD_DIR:?}/"* 2>/dev/null || true

if [[ -e "$BUILD_DIR/ext4.vhdx" ]]; then
  die "$BUILD_DIR still contains ext4.vhdx and could not be cleared.
    A distro is probably still registered against it. Check 'wsl -l -v',
    then run:  wsl --unregister <name>"
fi

log "Importing $(basename "$ROOTFS") as build distro '$BUILD_DISTRO'"
wsl.exe --import "$BUILD_DISTRO" "$(winpath "$BUILD_DIR")" "$(winpath "$ROOTFS")" --version 2 \
  2>&1 | tr -d '\0' | sed 's/^/    /' \
  || die "wsl --import failed"

# Arch Linux ARM tarballs are rooted at '/', the official Arch WSL image too,
# so no path fixups are needed. Verify we can actually get a shell.
step "Verifying the build distro boots"
wslx -d "$BUILD_DISTRO" -u root -- /bin/sh -c 'echo ok' | grep -q ok \
  || die "Build distro did not start"

log "Build distro '$BUILD_DISTRO' ready at $BUILD_DIR"
