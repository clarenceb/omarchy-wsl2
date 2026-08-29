#!/bin/bash
# 00-pacman.sh - make pacman usable inside an unprivileged WSL container build.
set -euo pipefail

info "Configuring pacman"

# 1) Recent pacman runs downloads as the unprivileged 'alpm' user inside a
#    Landlock sandbox. That reliably fails in container/WSL image builds, so
#    disable it for the duration of the build.
sed -i 's/^[[:space:]]*DownloadUser/#DownloadUser/' /etc/pacman.conf || true
grep -q '^DisableSandbox' /etc/pacman.conf \
  || sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf

# 2) WSL's root filesystem reports space in a way that upsets CheckSpace.
sed -i 's/^[[:space:]]*CheckSpace/#CheckSpace/' /etc/pacman.conf || true

# 3) Parallel downloads make a 1000-package install far less painful.
if grep -q '^#*ParallelDownloads' /etc/pacman.conf; then
  sed -i 's/^#*ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf
else
  sed -i '/^\[options\]/a ParallelDownloads = 8' /etc/pacman.conf
fi

case "$TARGET_ARCH" in
  x86_64)
    info "Seeding Arch mirrorlist"
    cat >/etc/pacman.d/mirrorlist <<'EOF'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
EOF
    KEYRING_PKG=archlinux-keyring
    KEYRING_ID=archlinux
    ;;
  aarch64)
    info "Seeding Arch Linux ARM mirrorlist"
    cat >/etc/pacman.d/mirrorlist <<'EOF'
Server = http://mirror.archlinuxarm.org/$arch/$repo
EOF
    KEYRING_PKG=archlinuxarm-keyring
    KEYRING_ID=archlinuxarm
    ;;
esac

info "Initialising the pacman keyring ($KEYRING_ID)"
rm -rf /etc/pacman.d/gnupg
pacman-key --init >/dev/null 2>&1
pacman-key --populate "$KEYRING_ID" >/dev/null 2>&1 \
  || die "pacman-key --populate $KEYRING_ID failed"

info "Refreshing package databases"
pacman -Sy --noconfirm >/dev/null || die "pacman -Sy failed"
pacman -S --noconfirm --needed "$KEYRING_PKG" >/dev/null 2>&1 || true
pacman-key --populate "$KEYRING_ID" >/dev/null 2>&1 || true

info "Applying system upgrade"
pacman -Syu --noconfirm >/dev/null || die "pacman -Syu failed"

info "Configuring locale and time"
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^#\(en_AU.UTF-8 UTF-8\)/\1/' /etc/locale.gen || true
locale-gen >/dev/null
echo 'LANG=en_US.UTF-8' >/etc/locale.conf
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

info "pacman ready"
