#!/bin/bash
# /etc/oobe.sh - omarchy-wsl2 first-run experience.
#
# Contract (see https://learn.microsoft.com/windows/wsl/build-custom-distro):
#   * runs once, on the first interactive shell
#   * a NON-ZERO exit means WSL refuses to open a shell -> always exit 0
#   * must line up with `[oobe] defaultUid` in wsl-distribution.conf
#
# NOTE: this is Arch. `adduser` does not exist here - we use useradd/usermod.

set -u

# Read the uid the image was actually built with rather than assuming 1000;
# WSL2's shared cgroup namespace means we often use 1001. See docs.
DEFAULT_UID=$(sed -n 's/^defaultUid[[:space:]]*=[[:space:]]*\([0-9]\+\).*/\1/p' \
  /etc/wsl-distribution.conf 2>/dev/null | head -1)
DEFAULT_UID=${DEFAULT_UID:-1000}
DEFAULT_GROUPS='wheel'
STATE_DIR=/var/lib/omarchy-wsl2
OOBE_RENAMED=""

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

# Rename the baked-in account to a name the user picks. Renaming (rather than
# delete + create) keeps the uid, home contents and Omarchy dotfiles intact.
rename_user() {
  local old="$1" new=""
  while true; do
    read -r -p 'Enter your preferred username: ' new || return 1
    [[ -z $new ]] && return 1
    if [[ ! $new =~ ^[a-z_][a-z0-9_-]*$ ]]; then
      warn "Invalid username. Use lowercase letters, digits, '-' and '_'."
      continue
    fi
    [[ $new == "$old" ]] && return 0
    if getent passwd "$new" >/dev/null; then
      warn "User '$new' already exists."
      continue
    fi

    if usermod -l "$new" -d "/home/$new" -m "$old" 2>/dev/null; then
      groupmod -n "$new" "$old" 2>/dev/null || true
      # Omarchy's config and this project's helpers live under the home dir,
      # which usermod -m has already moved; just fix any stale ownership.
      chown -R "$new":"$new" "/home/$new" 2>/dev/null || true
      echo "Renamed '$old' -> '$new'."
      return 0
    fi
    warn "Could not rename to '$new'."
    return 1
  done
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

  # CRITICAL: oobe.command runs on the FIRST shell of any kind, including
  # non-interactive ones (wsl -d omarchy -- somecommand). If we prompt when
  # stdin is not a terminal, every scripted first launch hangs forever.
  local interactive=0
  [[ -t 0 ]] && interactive=1

  if getent passwd "$DEFAULT_UID" >/dev/null; then
    # The image already bakes in an 'omarchy' user at DEFAULT_UID.
    local name
    name=$(getent passwd "$DEFAULT_UID" | cut -d: -f1)
    echo "Using the preconfigured account '${name}'."

    if (( interactive )); then
      echo
      echo "This image ships a ready-made account: '${name}'."
      echo "You can keep it, or create your own username instead."
      echo
      printf "Keep '%s'? [Y/n] " "$name"
      local keep=""
      read -r -t 60 keep || keep=y
      if [[ ${keep,,} == n* ]]; then
        if rename_user "$name"; then
          name=$(getent passwd "$DEFAULT_UID" | cut -d: -f1)
          OOBE_RENAMED=1
        else
          warn "Keeping '${name}'."
        fi
      fi

      echo
      echo "sudo is already passwordless for this account."
      printf "Set a login password for '%s' anyway? [y/N] " "$name"
      local reply=""
      read -r -t 30 reply || reply=n
      [[ ${reply,,} == y* ]] && passwd "$name"
    fi
  else
    if (( interactive )); then
      create_user || warn 'User setup was interrupted; falling back to root.'
    else
      warn "No uid ${DEFAULT_UID} account and no terminal to create one."
      warn "Run 'wsl -d omarchy' interactively to finish setup."
    fi
  fi

  sync_default_user
  mkdir -p "$STATE_DIR" && date -Is >"$STATE_DIR/oobe-completed"

  # A rename only takes full effect once WSL re-reads /etc/wsl.conf. Until the
  # distro is restarted, WSL keeps resolving the OLD name and commands fail
  # with: CreateProcessParseCommon: getpwnam(<old>) failed
  if [[ -n ${OOBE_RENAMED:-} ]]; then
    echo
    warn "Restart the distro to finish the rename:"
    warn "    wsl.exe --terminate \"\$WSL_DISTRO_NAME\""
    echo
  fi

  echo
  cyan 'Omarchy is ready.'
  echo
  echo '  omarchy-wsl-doctor     check WSLg / GPU / desktop readiness'
  echo '  omarchy-wsl-desktop    launch the nested Hyprland session'
  echo '  omarchy-theme-set      change the theme'
  echo '  oml "<question>"       ask the built-in Omarchy/WSL2 tutor'
  echo '  omarchy-wsl-help       what to do next'
  echo

  # NEVER fail: a non-zero exit locks the user out of the distro.
  exit 0
}

main "$@"
