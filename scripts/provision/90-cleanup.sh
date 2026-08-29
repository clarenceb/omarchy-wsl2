#!/bin/bash
# 90-cleanup.sh - shrink the image and satisfy Microsoft's packaging rules.
#
# Rules we are honouring (learn.microsoft.com/windows/wsl/build-custom-distro):
#   * do NOT ship /etc/resolv.conf
#   * DO keep a uid 0 root entry in /etc/passwd
#   * no password hashes in /etc/shadow
#   * no kernel or initramfs in the archive
set -euo pipefail

info "Restoring pacman's normal security posture"
# The sandbox was only disabled so the image could be built unprivileged.
sed -i 's/^#\(DownloadUser\)/\1/' /etc/pacman.conf || true
sed -i '/^DisableSandbox$/d' /etc/pacman.conf || true

info "Re-enabling the pacman hooks disabled during the build"
# The installed image runs systemd for real, so these hooks must work again.
# Only remove OUR /dev/null overrides; leave any genuine user hooks alone.
if [[ -d /etc/pacman.d/hooks ]]; then
  find /etc/pacman.d/hooks -maxdepth 1 -type l -lname /dev/null -delete 2>/dev/null || true
  rmdir /etc/pacman.d/hooks 2>/dev/null || true
fi

# Re-assert the systemd-binfmt mask. Stage 10 masks it, but package upgrades
# during the build can reinstall the unit file. Its
#     ExecStop=/usr/lib/systemd/systemd-binfmt --unregister
# flushes every binfmt_misc entry - including WSL's WSLInterop handler, which
# is shared across the whole WSL VM. Without this, merely stopping this distro
# breaks .exe execution in EVERY other distro until `wsl --shutdown`.
info "Verifying systemd-binfmt.service is masked"
systemctl mask systemd-binfmt.service >/dev/null 2>&1 || true
if [[ -L /etc/systemd/system/systemd-binfmt.service ]] \
   && [[ $(readlink /etc/systemd/system/systemd-binfmt.service) == /dev/null ]]; then
  info "  masked"
else
  # Fall back to a drop-in that neutralises just the destructive ExecStop.
  install -d -m 0755 /etc/systemd/system/systemd-binfmt.service.d
  printf '[Service]\nExecStop=\n' \
    >/etc/systemd/system/systemd-binfmt.service.d/10-omarchy-wsl-no-unregister.conf
  info "  mask failed; neutralised ExecStop via drop-in instead"
fi

info "Clearing the package cache"
# NOTE: do NOT use `pacman -Scc --noconfirm` here. With --noconfirm it answers
# "yes" to the *second* prompt too ("remove unused repositories"), which wipes
# /var/lib/pacman/sync. The image then greets the user with
#     error: target not found / database file for 'core' does not exist
# on their very first `pacman -S`. Clearing the package cache directly has the
# same size benefit with none of that risk.
rm -rf /var/cache/pacman/pkg/* 2>/dev/null || true

# /var/lib/pacman/sync is deliberately KEPT so the first `pacman -S <pkg>` in
# a fresh install just works. Verify, and restore it if something removed it.
if ! compgen -G '/var/lib/pacman/sync/*.db' >/dev/null; then
  info "  sync databases are missing - refreshing them"
  pacman -Sy >/dev/null 2>&1 \
    || info "  WARNING: could not refresh sync databases; first pacman -S will need -Sy"
fi

info "Removing build staging and logs"
# NOTE: /tmp/omarchy-wsl2-src is this script's own location, so it is removed
# by scripts/provision.sh after main.sh returns, not here.
rm -rf /root/.cache /home/*/.cache 2>/dev/null || true
find /var/log -type f -exec truncate -s 0 {} + 2>/dev/null || true

info "Shutting down gpg-agent and removing its sockets"
# tar cannot archive unix sockets; leaving them makes `wsl --export` warn.
gpgconf --kill all >/dev/null 2>&1 || true
find /etc/pacman.d/gnupg /root/.gnupg -type s -delete 2>/dev/null || true

info "Removing /etc/resolv.conf (WSL generates it)"
rm -f /etc/resolv.conf

info "Clearing machine-id so each install gets its own"
: >/etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

info "Verifying no password hashes ship in the image"
if awk -F: 'length($2) > 1 && $2 !~ /^[!*]/ {print $1}' /etc/shadow | grep -q .; then
  info "WARNING: password hashes present:"
  awk -F: 'length($2) > 1 && $2 !~ /^[!*]/ {print "    " $1}' /etc/shadow
fi

info "Verifying a uid 0 root entry exists"
getent passwd 0 >/dev/null || die "no uid 0 entry in /etc/passwd"

info "Verifying no kernel/initramfs is present"
if compgen -G '/boot/vmlinuz*' >/dev/null || compgen -G '/boot/initramfs*' >/dev/null; then
  info "Removing bootloader artefacts from /boot"
  rm -f /boot/vmlinuz* /boot/initramfs* /boot/initrd* 2>/dev/null || true
fi

info "Verifying required config files"
for f in /etc/wsl.conf /etc/wsl-distribution.conf /etc/oobe.sh; do
  [[ -f $f ]] || die "missing $f"
done
[[ $(stat -c '%U:%G %a' /etc/wsl.conf) == "root:root 644" ]] \
  || die "/etc/wsl.conf must be root:root 0644"
[[ $(stat -c '%U:%G %a' /etc/wsl-distribution.conf) == "root:root 644" ]] \
  || die "/etc/wsl-distribution.conf must be root:root 0644"

if [[ -f /var/log/omarchy-wsl2-missing.log ]]; then
  info "Packages that were unavailable on $TARGET_ARCH:"
  sort -u /var/log/omarchy-wsl2-missing.log | sed 's/^/    /'
fi

info "Image size: $(du -shx --exclude=/mnt --exclude=/proc --exclude=/sys \
  --exclude=/dev --exclude=/run / 2>/dev/null | cut -f1)"
info "Cleanup complete"
