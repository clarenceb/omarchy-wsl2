#!/bin/bash
# 50-user.sh - create the default Omarchy user.
#
# Microsoft's guidance: if the OOBE creates a user, the account uid and
# [oobe] defaultUid must match. We bake the account in so first boot is fast,
# and oobe.sh simply adopts it.
#
# The uid is OMARCHY_UID (default 1001, not 1000) because WSL2 shares one
# cgroup namespace across distros - see the comment in main.sh.
set -euo pipefail

# Arch Linux ARM images ship a stock 'alarm' user; get rid of it so the uid
# we want is free.
if id alarm >/dev/null 2>&1; then
  info "Removing the stock Arch Linux ARM 'alarm' user"
  userdel -r alarm >/dev/null 2>&1 || true
fi

if ! getent group wheel >/dev/null; then groupadd wheel; fi

if id "$OMARCHY_USER" >/dev/null 2>&1; then
  info "User '$OMARCHY_USER' already exists"
else
  info "Creating user '$OMARCHY_USER' (uid $OMARCHY_UID)"
  # NOTE: Arch has no `adduser`; useradd is the correct tool.
  useradd --uid "$OMARCHY_UID" --create-home --user-group \
          --groups wheel --shell /bin/bash "$OMARCHY_USER"
fi

# No password hash may ship in the image (Microsoft's packaging rules), so the
# account starts passwordless and oobe.sh offers to set one.
passwd -d "$OMARCHY_USER" >/dev/null 2>&1 || true
passwd -d root >/dev/null 2>&1 || true

info "Granting passwordless sudo to the wheel group"
cat >/etc/sudoers.d/99-omarchy-wsl2 <<'EOF'
# omarchy-wsl2: the WSL default user administers the distro.
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/99-omarchy-wsl2
visudo -c >/dev/null || die "sudoers validation failed"

# ------------------------------------------------------ Omarchy dotfiles ----
info "Installing Omarchy's config/ into the user profile"
USER_HOME=$(getent passwd "$OMARCHY_USER" | cut -d: -f6)

install -d -m 0755 "$USER_HOME/.config" /etc/skel/.config
if [[ -d $OMARCHY_SHARE/config ]]; then
  cp -RT "$OMARCHY_SHARE/config" /etc/skel/.config
  cp -RT "$OMARCHY_SHARE/config" "$USER_HOME/.config"
fi

# Omarchy hardcodes ~/.local/share/omarchy - its upstream install location - in
# roughly 29 files across bin/, config/ and default/. We vendor a single
# system-wide copy at /usr/share/omarchy, so point the expected path at it
# instead of trying to rewrite every reference (which is what an earlier sed
# attempted, and missed, because the files use ~/ rather than $HOME/).
info "Linking ~/.local/share/omarchy -> $OMARCHY_SHARE"
for base in /etc/skel "$USER_HOME"; do
  install -d -m 0755 "$base/.local/share"
  ln -sfn "$OMARCHY_SHARE" "$base/.local/share/omarchy"
done

if [[ -f $OMARCHY_SHARE/default/bashrc ]]; then
  info "Installing Omarchy's bashrc"
  cp "$OMARCHY_SHARE/default/bashrc" /etc/skel/.bashrc
  cp "$OMARCHY_SHARE/default/bashrc" "$USER_HOME/.bashrc"
fi

# Chain in the WSL-specific bits.
cat >>"$USER_HOME/.bashrc" <<'EOF'

# ---- omarchy-wsl2 ----
# TERM sanity first: without a resolvable terminfo entry readline switches
# itself off and arrow keys print ^[[A instead of editing the line. profile.d
# only runs for login shells, and terminals opened from the desktop launcher
# are not login shells, so source it here too.
[ -f /etc/profile.d/omarchy-wsl-term.sh ] && . /etc/profile.d/omarchy-wsl-term.sh
[ -f /etc/profile.d/omarchy.sh ] && . /etc/profile.d/omarchy.sh
[ -f "$HOME/.config/omarchy-wsl2/env.sh" ] && . "$HOME/.config/omarchy-wsl2/env.sh"

# Interactive-shell quality of life. Guarded so scp/rsync stay unaffected.
case $- in
  *i*)
    # Readline: history search on Up/Down, and sane word behaviour.
    bind '"\e[A": history-search-backward' 2>/dev/null
    bind '"\e[B": history-search-forward'  2>/dev/null
    bind 'set completion-ignore-case on'    2>/dev/null
    bind 'set show-all-if-ambiguous on'     2>/dev/null
    # Don't let a stray Ctrl-S freeze the terminal.
    [ -t 0 ] && stty -ixon 2>/dev/null
    ;;
esac
EOF
cp "$USER_HOME/.bashrc" /etc/skel/.bashrc

# Copy the migration state seeded in stage 20 into the real home.
if [[ -d /etc/skel/.local/state/omarchy ]]; then
  install -d -m 0755 "$USER_HOME/.local/state"
  cp -RT /etc/skel/.local/state "$USER_HOME/.local/state"
fi

chown -R "$OMARCHY_USER":"$OMARCHY_USER" "$USER_HOME"

info "User '$OMARCHY_USER' ready"
