#!/bin/bash
# scripts/provision/main.sh - in-guest provisioning entrypoint.
#
# Runs as root INSIDE the throwaway Arch build distro. Each stage is a separate
# script so you can re-run one in isolation while iterating.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_ARCH="$(uname -m)"
export SRC_DIR TARGET_ARCH

# Defensive: never let WSL interop's Windows PATH entries leak into the build.
# Omarchy scripts call `code`, `node`, `python` - all of which exist as Windows
# executables under /mnt/c and would hang or misbehave here.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

export PROFILE="${OMARCHY_WSL_PROFILE:-desktop}"
export OMARCHY_USER="${OMARCHY_USER:-omarchy}"
# WSL2 runs every distro in ONE VM sharing a single cgroup namespace, so the
# per-user systemd manager lives at the same path in all of them:
#   /sys/fs/cgroup/user.slice/user-<uid>.slice/user@<uid>.service
# If another running distro (e.g. Ubuntu) already has user@1000.service, this
# distro's attempt fails with:
#   user@1000.service: Failed to spawn executor: Device or resource busy
# Defaulting to 1001 keeps us clear of the near-universal 1000.
export OMARCHY_UID="${OMARCHY_UID:-1001}"
export OMARCHY_REF="${OMARCHY_REF:-master}"
export OMARCHY_REPO="${OMARCHY_REPO:-basecamp/omarchy}"
export OMARCHY_THEME="${OMARCHY_THEME:-Tokyo Night}"
export OMARCHY_LAYOUT="${OMARCHY_LAYOUT:-tiling}"
export OMARCHY_SHARE=/usr/share/omarchy

g() { printf '\n\033[1;35m### %s\033[0m\n' "$*"; }
info() { printf '\033[36m  -> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m  xx %s\033[0m\n' "$*" >&2; exit 1; }
export -f info die

# Should this profile include a given tier?
want_apps()    { [[ $PROFILE == apps || $PROFILE == desktop ]]; }
want_desktop() { [[ $PROFILE == desktop ]]; }
export -f want_apps want_desktop

STAGES=(
  00-pacman.sh
  10-base.sh
  20-omarchy.sh
  30-apps.sh
  40-desktop.sh
  50-user.sh
  60-wsl.sh
  70-theme.sh
  90-cleanup.sh
)

printf '\033[1;36m'
cat <<'EOF'
   ┌──────────┬────────┐
   │  >_      │        │   omarchy-wsl2 image build
   │          ├────────┤
   └──────────┴────────┘
EOF
printf '\033[0m'
echo "  profile: $PROFILE"
echo "  arch:    $TARGET_ARCH"
echo "  omarchy: $OMARCHY_REPO@$OMARCHY_REF"
echo "  user:    $OMARCHY_USER (uid $OMARCHY_UID)"

for stage in "${STAGES[@]}"; do
  g "$stage"
  bash "$SRC_DIR/scripts/provision/$stage" || die "stage $stage failed"
done

g "Done"
echo "Image provisioned. Export it with: make export"
