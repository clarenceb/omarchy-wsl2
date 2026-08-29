#!/bin/bash
# scripts/lib.sh - shared host-side helpers for the omarchy-wsl2 build.
# Sourced by the other scripts; not executable on its own.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# ---------------------------------------------------------------- logging ---
_c() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
log()  { printf '%s %s\n' "$(_c '1;36' '==>')" "$*"; }
step() { printf '%s %s\n' "$(_c '1;35' ' ->')" "$*"; }
warn() { printf '%s %s\n' "$(_c '1;33' ' !!')" "$*" >&2; }
die()  { printf '%s %s\n' "$(_c '1;31' 'xx ')" "$*" >&2; exit 1; }

# ------------------------------------------------------------ environment ---
# wsl.exe emits UTF-16LE; strip the NUL bytes so the output is greppable.
wslx() { wsl.exe "$@" 2>&1 | tr -d '\0'; }

require_wsl_host() {
  command -v wsl.exe >/dev/null 2>&1 \
    || die "wsl.exe not found. Run this from inside a WSL2 distro on Windows."

  # Existing is not enough - it must actually execute. binfmt_misc is shared
  # across the whole WSL VM, and some distros' systemd-binfmt.service runs
  #     ExecStop=/usr/lib/systemd/systemd-binfmt --unregister
  # on shutdown, which flushes WSL's own WSLInterop handler. Every .exe then
  # fails with exit 126 ("cannot execute binary file: Exec format error").
  local rc=0
  wsl.exe --version >/dev/null 2>&1 || rc=$?
  if (( rc != 0 )); then
    if (( rc == 126 )) || [[ ! -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
      printf '\n'
      warn "Windows interop is broken in this distro (wsl.exe exits $rc)."
      warn "The WSLInterop binfmt_misc handler has been unregistered."
      printf '\n'
      printf '  This happens when another distro stops and its\n'
      printf '  systemd-binfmt.service unregisters every binfmt entry.\n'
      printf '\n'
      printf '  Fix, from a Windows PowerShell prompt:\n'
      printf '      wsl --shutdown\n'
      printf '  then reopen this terminal and re-run.\n'
      printf '\n'
      printf '  To stop it recurring, in each Arch/Omarchy distro:\n'
      printf '      sudo systemctl mask systemd-binfmt.service\n'
      printf '\n'
      die "Cannot continue without Windows interop."
    fi
    die "wsl.exe failed to run (exit $rc)."
  fi
}

# WSL >= 2.4.4 is required for tar-based .wsl distros and [oobe] support.
check_wsl_version() {
  local raw major minor patch
  raw=$(wslx --version | awk '/WSL version/{print $3}' | tr -d '\r')
  [[ -z $raw ]] && { warn "Could not determine WSL version; continuing."; return 0; }
  IFS=. read -r major minor patch _ <<<"$raw"
  if (( major < 2 )) || { (( major == 2 )) && (( minor < 4 )); } \
     || { (( major == 2 )) && (( minor == 4 )) && (( patch < 4 )); }; then
    die "WSL $raw is too old. Need >= 2.4.4 for .wsl distributions. Run: wsl --update"
  fi
  step "WSL version $raw (ok)"
}

# Target architecture of the image we are building.
target_arch() {
  case "${ARCH:-$(uname -m)}" in
    x86_64|amd64) echo x86_64 ;;
    aarch64|arm64) echo aarch64 ;;
    *) die "Unsupported architecture: ${ARCH:-$(uname -m)}" ;;
  esac
}

# Convert a Linux path to a Windows path for wsl.exe arguments.
winpath() { wslpath -w "$1"; }

ensure_dir() { mkdir -p "$1"; }

distro_exists() {
  wslx --list --quiet | sed 's/\r//' | grep -qx "$1"
}

unregister_distro() {
  local name="$1"
  if distro_exists "$name"; then
    step "Unregistering existing distro '$name'"
    wsl.exe --terminate "$name" >/dev/null 2>&1 || true
    wsl.exe --unregister "$name" >/dev/null 2>&1 || true
  fi
}

human_size() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "$1 bytes"; }
