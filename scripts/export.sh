#!/bin/bash
# scripts/export.sh - export the provisioned build distro as a .wsl file.
#
# A .wsl file is just a gzip-compressed tar of the root filesystem, per
# https://learn.microsoft.com/windows/wsl/build-custom-distro
#
# Usage: scripts/export.sh <build-distro-name> <dist-dir> <output-name>

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BUILD_DISTRO="${1:?usage: export.sh <distro> <dist-dir> <name>}"
DIST_DIR="${2:?}"
OUT_NAME="${3:?}"

require_wsl_host
distro_exists "$BUILD_DISTRO" || die "Build distro '$BUILD_DISTRO' not found"

ensure_dir "$DIST_DIR"
TAR_PATH="$DIST_DIR/${OUT_NAME}.tar"
WSL_PATH="$DIST_DIR/${OUT_NAME}.wsl"
rm -f "$TAR_PATH" "$WSL_PATH"

step "Shutting the build distro down cleanly"
wsl.exe --terminate "$BUILD_DISTRO" >/dev/null 2>&1 || true

log "Exporting '$BUILD_DISTRO'"
# WSL writes an uncompressed tar; we gzip it ourselves so the compression
# format matches Microsoft's recommendation (gzip = widest compatibility).
wsl.exe --export "$BUILD_DISTRO" "$(winpath "$TAR_PATH")" \
  || die "wsl --export failed"

step "Compressing to $(basename "$WSL_PATH")"
gzip -9 -c "$TAR_PATH" > "$WSL_PATH"
rm -f "$TAR_PATH"

SHA=$(sha256sum "$WSL_PATH" | cut -d' ' -f1)
printf '%s  %s\n' "$SHA" "$(basename "$WSL_PATH")" > "$WSL_PATH.sha256"

log "Built $WSL_PATH ($(human_size "$(stat -c%s "$WSL_PATH")"))"
step "sha256: $SHA"
echo
echo "Install it with:"
echo "  wsl --install --from-file $(winpath "$WSL_PATH")"
echo "or just double-click the .wsl file in Explorer."
