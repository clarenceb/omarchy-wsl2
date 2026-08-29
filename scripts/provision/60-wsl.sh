#!/bin/bash
# 60-wsl.sh - WSL integration: distro config, OOBE, icon, terminal profile and
# the omarchy-wsl-* helper commands.
set -euo pipefail

info "Installing /etc/wsl.conf and /etc/wsl-distribution.conf"
install -m 0644 -o root -g root "$SRC_DIR/wsl/wsl.conf" /etc/wsl.conf
install -m 0644 -o root -g root "$SRC_DIR/wsl/wsl-distribution.conf" /etc/wsl-distribution.conf

# Keep the default user in wsl.conf in step with the account we actually made.
sed -i -E "s/^default=.*/default=${OMARCHY_USER}/" /etc/wsl.conf

# oobe.defaultUid MUST match the baked account, or WSL starts the first shell
# as the wrong user. OMARCHY_UID is not always 1000 - see main.sh.
sed -i -E "s/^defaultUid = .*/defaultUid = ${OMARCHY_UID}/" /etc/wsl-distribution.conf

info "Installing the OOBE script"
install -m 0755 -o root -g root "$SRC_DIR/wsl/oobe.sh" /etc/oobe.sh

info "Installing the Start-menu icon and Windows Terminal profile"
install -d -m 0755 /usr/lib/wsl
if [[ -f $SRC_DIR/assets/omarchy-wsl2.ico ]]; then
  install -m 0644 "$SRC_DIR/assets/omarchy-wsl2.ico" /usr/lib/wsl/omarchy-wsl2.ico
else
  info "WARNING: assets/omarchy-wsl2.ico missing - run 'make logo' before building"
  sed -i 's#^icon = .*#\# icon not shipped#' /etc/wsl-distribution.conf
fi
install -m 0644 "$SRC_DIR/wsl/terminal-profile.json" /usr/lib/wsl/terminal-profile.json

info "Installing the omarchy-wsl-* helpers"
install -d -m 0755 /usr/local/bin
for f in "$SRC_DIR/overlay/usr/local/bin/"*; do
  install -m 0755 -o root -g root "$f" "/usr/local/bin/$(basename "$f")"
done

# ---------------------------------------------------------- omarchy-learn ---
# Lives in /opt (self-contained, with its own share/) and is symlinked into
# /usr/local/bin. We avoid /usr/bin because that is pacman-owned territory on
# Arch and stray files there can collide during package upgrades.
info "Installing omarchy-learn into /opt"
install -d -m 0755 /opt/omarchy-learn/bin /opt/omarchy-learn/share
install -m 0755 -o root -g root \
  "$SRC_DIR/overlay/opt/omarchy-learn/bin/omarchy-learn" \
  /opt/omarchy-learn/bin/omarchy-learn
install -m 0644 -o root -g root \
  "$SRC_DIR/overlay/opt/omarchy-learn/share/system-prompt.md" \
  /opt/omarchy-learn/share/system-prompt.md
ln -sfn /opt/omarchy-learn/bin/omarchy-learn /usr/local/bin/omarchy-learn
ln -sfn /opt/omarchy-learn/bin/omarchy-learn /usr/local/bin/oml
info "  omarchy-learn + 'oml' alias linked into /usr/local/bin"

# Ship this project's docs so omarchy-learn can ground its answers in them.
info "Installing omarchy-wsl2 documentation to /usr/share/omarchy-wsl2/docs"
install -d -m 0755 /usr/share/omarchy-wsl2/docs
if [[ -d $SRC_DIR/docs ]]; then
  install -m 0644 "$SRC_DIR/docs/"*.md /usr/share/omarchy-wsl2/docs/ 2>/dev/null || true
fi
[[ -f $SRC_DIR/README.md ]] && install -m 0644 "$SRC_DIR/README.md" /usr/share/omarchy-wsl2/README.md

# glow renders omarchy-learn's Markdown answers.
pacman -S --noconfirm --needed glow >/dev/null 2>&1 \
  && info "  glow installed (Markdown rendering)" \
  || info "  glow unavailable; omarchy-learn will fall back to plain text"

# --------------------------------------------------------- session env ------
info "Writing the per-user WSLg environment"
USER_HOME=$(getent passwd "$OMARCHY_USER" | cut -d: -f6)
for base in /etc/skel "$USER_HOME"; do
  install -d -m 0755 "$base/.config/omarchy-wsl2"
  cat >"$base/.config/omarchy-wsl2/env.sh" <<'EOF'
# Sourced by ~/.bashrc. Exports the WSLg Wayland/X11/audio environment so
# graphical apps "just work" from an interactive shell.
if [ -r /usr/local/bin/omarchy-wsl-env ]; then
    . /usr/local/bin/omarchy-wsl-env
    owsl_export_wslg_env 2>/dev/null || true
fi

# Send URLs to the Windows default browser. This is what makes interactive
# logins (gh auth login, copilot login, az login) work in headless mode, where
# the distro has no browser of its own.
if command -v wslview >/dev/null 2>&1; then
    export BROWSER=wslview
elif [ -x /usr/local/bin/omarchy-wsl-open ]; then
    export BROWSER=omarchy-wsl-open
fi
EOF
done

# ----------------------------------------------- Hyprland WSL overrides -----
if want_desktop; then
  info "Chaining the WSL Hyprland overrides into hyprland.conf"
  for base in /etc/skel "$USER_HOME"; do
    HYPR_CONF="$base/.config/hypr/hyprland.conf"
    [[ -f $HYPR_CONF ]] || continue
    grep -q 'conf/wsl.conf' "$HYPR_CONF" && continue
    printf '\n# omarchy-wsl2: WSL-specific overrides (must load last)\nsource = ~/.config/hypr/conf/wsl.conf\n' \
      >>"$HYPR_CONF"
  done
  # Make sure the override file itself reached the real home.
  install -d -m 0755 "$USER_HOME/.config/hypr/conf"
  [[ -f /etc/skel/.config/hypr/conf/wsl.conf ]] \
    && install -m 0644 /etc/skel/.config/hypr/conf/wsl.conf \
                       "$USER_HOME/.config/hypr/conf/wsl.conf"
fi

# ------------------------------------------------------------- branding -----
info "Writing /etc/os-release branding"
if ! grep -q omarchy-wsl2 /etc/os-release 2>/dev/null; then
  cat >>/etc/os-release <<EOF
OMARCHY_WSL2="true"
OMARCHY_WSL2_PROFILE="$PROFILE"
EOF
fi

cat >/etc/motd <<'EOF'

  omarchy-wsl2   `omarchy-wsl-help` for the cheat sheet
                 `omarchy-wsl-doctor` to check WSLg / GPU / desktop readiness

EOF

chown -R "$OMARCHY_USER":"$OMARCHY_USER" "$USER_HOME"
info "WSL integration installed"
