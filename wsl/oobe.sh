#!/bin/bash
# /etc/oobe.sh - omarchy-wsl2 first-run experience.
#
# Contract (see https://learn.microsoft.com/windows/wsl/build-custom-distro):
#   * runs once, on the first interactive shell
#   * a NON-ZERO exit means WSL refuses to open a shell -> always exit 0
#   * must line up with `[oobe] defaultUid = 1000` in wsl-distribution.conf
#
# NOTE: this is Arch. `adduser` does not exist here - we use useradd/usermod.

set -u

DEFAULT_UID=1000
DEFAULT_GROUPS='wheel'
STATE_DIR=/var/lib/omarchy-wsl2

cyan() { printf '\033[36m%s\033[0m\n' "$1"; }
warn() { printf '\033[33m%s\033[0m\n' "$1"; }

banner() {
  cyan '
   ┌──────────┬────────┐
   │  >_      │        │      omarchy-wsl2
   │          ├────────┤      Omarchy, running on WSL2
   └──────────┴────────┘
'
}

create_user() {
  local username
  echo 'Create your Omarchy user account.'
  echo 'This is separate from your Windows username.'
  echo

  while true; do
    read -r -p 'Enter new UNIX username: ' username || return 1
    [[ -z $username ]] && continue

    if useradd --uid "$DEFAULT_UID" --create-home --shell /bin/bash \
               --user-group "$username" 2>/dev/null; then
      usermod -aG "$DEFAULT_GROUPS" "$username" || { userdel -r "$username"; continue; }

      echo
      echo "Set a password for '$username' (used for sudo)."
      if passwd "$username"; then
        printf '[user]\ndefault=%s\n' "$username" >/tmp/.omarchy-user
        return 0
      fi
      userdel -r "$username" 2>/dev/null
    else
      warn "Could not create '$username' - try another name."
    fi
  done
}

sync_default_user() {
  # Keep /etc/wsl.conf's default user in step with whatever was created.
  local name
  name=$(getent passwd "$DEFAULT_UID" | cut -d: -f1) || return 0
  [[ -z $name ]] && return 0
  if [[ -f /etc/wsl.conf ]] && ! grep -qE "^default=${name}$" /etc/wsl.conf; then
    sed -i -E "s/^default=.*/default=${name}/" /etc/wsl.conf
  fi
}

main() {
  banner

  if getent passwd "$DEFAULT_UID" >/dev/null; then
    # The image already bakes in an 'omarchy' user at uid 1000.
    local name
    name=$(getent passwd "$DEFAULT_UID" | cut -d: -f1)
    echo "Using the preconfigured account '${name}'."
    echo
    if passwd -S "$name" 2>/dev/null | awk '{print $2}' | grep -qx 'NP'; then
      echo "Set a password for '${name}' (leave it unset to keep sudo passwordless):"
      passwd "$name" || true
    fi
  else
    create_user || warn 'User setup was interrupted; falling back to root.'
  fi

  sync_default_user
  mkdir -p "$STATE_DIR" && date -Is >"$STATE_DIR/oobe-completed"

  echo
  cyan 'Omarchy is ready.'
  echo
  echo '  omarchy-wsl-doctor     check WSLg / GPU / desktop readiness'
  echo '  omarchy-wsl-desktop    launch the nested Hyprland session'
  echo '  omarchy-theme-set      change the theme'
  echo '  omarchy-wsl-help       what to do next'
  echo

  # NEVER fail: a non-zero exit locks the user out of the distro.
  exit 0
}

main "$@"
