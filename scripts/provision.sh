#!/bin/bash
# scripts/provision.sh - copy this repo into the build distro and run the
# in-guest provisioning chain.
#
# Usage: scripts/provision.sh <build-distro-name> <profile>

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BUILD_DISTRO="${1:?usage: provision.sh <distro> <profile>}"
PROFILE="${2:-desktop}"

require_wsl_host
distro_exists "$BUILD_DISTRO" || die "Build distro '$BUILD_DISTRO' not found (run: make seed)"

case "$PROFILE" in
  headless|apps|desktop) ;;
  *) die "PROFILE must be one of: headless, apps, desktop (got '$PROFILE')" ;;
esac

log "Provisioning '$BUILD_DISTRO' with profile '$PROFILE'"

STAGE=/tmp/omarchy-wsl2-src
step "Copying build tree into the guest"
# --cd / keeps wsl.exe from trying to translate the Linux cwd to a Windows path.
wsl.exe -d "$BUILD_DISTRO" -u root --cd / -- rm -rf "$STAGE"
wsl.exe -d "$BUILD_DISTRO" -u root --cd / -- mkdir -p "$STAGE"

# tar over stdin avoids any dependency on /mnt paths inside the guest.
tar -C "$REPO_ROOT" -cf - \
      --exclude='./.git' --exclude='./build' --exclude='./dist' --exclude='./cache' \
      . \
  | wsl.exe -d "$BUILD_DISTRO" -u root --cd / -- tar -C "$STAGE" -xf - \
  || die "Failed to stage sources into the guest"

step "Running in-guest provisioning (this takes a while)"
# A clean PATH is essential. WSL's interop appends the entire Windows PATH, so
# without this, Omarchy scripts that call `code`, `python` or `node` would
# invoke the *Windows* binaries over /mnt/c and hang the build.
# </dev/null likewise stops any stray prompt blocking forever.
wsl.exe -d "$BUILD_DISTRO" -u root --cd / -- \
  env -i \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      HOME=/root TERM="${TERM:-xterm-256color}" \
      OMARCHY_WSL_PROFILE="$PROFILE" \
      OMARCHY_REF="${OMARCHY_REF:-master}" \
      OMARCHY_REPO="${OMARCHY_REPO:-basecamp/omarchy}" \
      OMARCHY_THEME="${OMARCHY_THEME:-Tokyo Night}" \
      OMARCHY_LAYOUT="${OMARCHY_LAYOUT:-tiling}" \
      OMARCHY_USER="${OMARCHY_USER:-omarchy}" \
      OMARCHY_UID="${OMARCHY_UID:-1001}" \
      /bin/bash "$STAGE/scripts/provision/main.sh" </dev/null \
  || die "Provisioning failed. Inspect with: wsl -d $BUILD_DISTRO -u root"

# Remove the staged sources now that nothing is executing from them.
step "Removing staged sources from the guest"
wsl.exe -d "$BUILD_DISTRO" -u root --cd / -- rm -rf "$STAGE" || true

log "Provisioning complete"
