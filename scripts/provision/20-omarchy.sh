#!/bin/bash
# 20-omarchy.sh - vendor Omarchy's assets and (on x86_64) its pacman repo.
#
# We deliberately do NOT run upstream install.sh. Its preflight guard
# (install/preflight/guard.sh) hard-requires a Limine bootloader, a Btrfs root
# filesystem, x86_64, a non-root user and bare-metal Arch. Under WSL those
# checks fail and are only bypassable through an interactive `gum confirm`,
# which a scripted build cannot answer.
#
# Instead we reuse Omarchy's real assets - bin/, config/, themes/, default/ -
# which is exactly what its own scripts operate on.
set -euo pipefail

info "Cloning $OMARCHY_REPO@$OMARCHY_REF"
rm -rf "$OMARCHY_SHARE"
git clone --depth 1 --branch "$OMARCHY_REF" \
  "https://github.com/${OMARCHY_REPO}.git" "$OMARCHY_SHARE" >/dev/null 2>&1 \
  || die "Failed to clone $OMARCHY_REPO@$OMARCHY_REF"

OMARCHY_VERSION=$(cat "$OMARCHY_SHARE/version" 2>/dev/null || echo unknown)
info "Omarchy $OMARCHY_VERSION vendored at $OMARCHY_SHARE"

# --------------------------------------------------- Omarchy's pacman repo ---
# https://pkgs.omarchy.org ships 200+ packages for x86_64 but ONLY
# omarchy-keyring for aarch64, so the repo is pointless on ARM.
if [[ $TARGET_ARCH == x86_64 ]]; then
  info "Adding the [omarchy] pacman repository"
  pacman-key --recv-keys 40DFB630FF42BCFFB047046CF0134EE680CAC571 \
      --keyserver keys.openpgp.org >/dev/null 2>&1 \
    && pacman-key --lsign-key 40DFB630FF42BCFFB047046CF0134EE680CAC571 >/dev/null 2>&1 \
    || info "Could not import the Omarchy signing key; skipping the repo"

  if pacman-key --list-keys 40DFB630FF42BCFFB047046CF0134EE680CAC571 >/dev/null 2>&1; then
    grep -q '^\[omarchy\]' /etc/pacman.conf || cat >>/etc/pacman.conf <<'EOF'

[omarchy]
SigLevel = Optional TrustAll
Server = https://pkgs.omarchy.org/$arch
EOF
    pacman -Sy --noconfirm >/dev/null 2>&1 || true

    mapfile -t OPKGS < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' \
      "$SRC_DIR/packages/omarchy-repo.packages" | tr -d '\r')
    info "Installing ${#OPKGS[@]} packages from [omarchy]"
    for p in "${OPKGS[@]}"; do
      pacman -S --noconfirm --needed "$p" >/dev/null 2>&1 \
        || { info "  unavailable: $p"; echo "$p" >>/var/log/omarchy-wsl2-missing.log; }
    done
  fi
else
  info "aarch64: skipping [omarchy] repo (x86_64-only). See docs/08-arm64.md."
fi

# ------------------------------------------------------------ PATH + state ---
info "Exposing Omarchy's bin/ on PATH"
cat >/etc/profile.d/omarchy.sh <<EOF
# Added by omarchy-wsl2
export OMARCHY_PATH="$OMARCHY_SHARE"
export PATH="\$OMARCHY_PATH/bin:\$PATH"
EOF
chmod 0644 /etc/profile.d/omarchy.sh

# /etc/profile.d is only sourced by LOGIN shells, so `wsl -d omarchy -- cmd`
# and any non-login shell would not find the omarchy-* commands. Add a symlink
# farm in /usr/local/bin, which is always on PATH.
info "Linking omarchy-* commands into /usr/local/bin"
install -d -m 0755 /usr/local/bin
linked=0
for f in "$OMARCHY_SHARE"/bin/*; do
  [[ -f $f && -x $f ]] || continue
  name=$(basename "$f")
  # Never shadow this project's own omarchy-wsl-* helpers.
  [[ $name == omarchy-wsl-* ]] && continue
  ln -sfn "$f" "/usr/local/bin/$name"
  linked=$((linked + 1))
done
info "  linked $linked commands"

printf 'OMARCHY_PATH=%s\nOMARCHY_VERSION=%s\n' "$OMARCHY_SHARE" "$OMARCHY_VERSION" \
  >/etc/omarchy.conf

# Omarchy's migrations replay historical changes on `omarchy-update`. A freshly
# built image is already current, so mark them all as applied.
info "Marking migrations as applied"
install -d -m 0755 /etc/skel/.local/state/omarchy
MIGRATION_STATE=/etc/skel/.local/state/omarchy/migrations
install -d -m 0755 "$MIGRATION_STATE"
if [[ -d $OMARCHY_SHARE/migrations ]]; then
  for m in "$OMARCHY_SHARE"/migrations/*.sh; do
    [[ -e $m ]] || continue
    touch "$MIGRATION_STATE/$(basename "$m" .sh)"
  done
fi

info "Omarchy assets ready"
