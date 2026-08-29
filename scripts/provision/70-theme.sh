#!/bin/bash
# 70-theme.sh - apply an Omarchy theme at build time.
#
# omarchy-theme-set normally talks to a running compositor (to reload Hyprland,
# waybar, swaybg...). OMARCHY_THEME_HEADLESS and OMARCHY_THEME_SKIP_BACKGROUND
# are the upstream escape hatches that let it run without one.
set -euo pipefail

USER_HOME=$(getent passwd "$OMARCHY_USER" | cut -d: -f6)

if [[ ! -d $OMARCHY_SHARE/themes ]]; then
  info "No themes/ in the Omarchy checkout - skipping"
  exit 0
fi

info "Available themes: $(ls "$OMARCHY_SHARE/themes" | tr '\n' ' ')"
info "Applying theme: $OMARCHY_THEME"

if [[ -x $OMARCHY_SHARE/bin/omarchy-theme-set ]]; then
  # </dev/null and a timeout are essential: omarchy-theme-set may prompt (gum)
  # or wait on a compositor socket, which would hang the build forever.
  timeout 90 sudo -u "$OMARCHY_USER" \
    env HOME="$USER_HOME" \
        OMARCHY_PATH="$OMARCHY_SHARE" \
        PATH="$OMARCHY_SHARE/bin:$PATH" \
        OMARCHY_THEME_HEADLESS=1 \
        OMARCHY_THEME_SKIP_BACKGROUND=1 \
        omarchy-theme-set "$OMARCHY_THEME" </dev/null >/dev/null 2>&1 \
    || info "omarchy-theme-set did not complete headlessly; using the symlink fallback"
fi

# Fallback / belt-and-braces: point ~/.config/omarchy/current/theme at the
# theme directory, which is the layout the rest of Omarchy reads.
THEME_SLUG=$(echo "$OMARCHY_THEME" | tr '[:upper:] ' '[:lower:]-')
THEME_DIR="$OMARCHY_SHARE/themes/$THEME_SLUG"
if [[ -d $THEME_DIR ]]; then
  install -d -m 0755 "$USER_HOME/.config/omarchy/current"
  ln -sfn "$THEME_DIR" "$USER_HOME/.config/omarchy/current/theme"
  echo "$THEME_SLUG" >"$USER_HOME/.config/omarchy/current/theme.name"
  info "Theme linked: $THEME_SLUG"
else
  info "Theme directory not found for '$OMARCHY_THEME' (slug: $THEME_SLUG)"
fi

chown -R "$OMARCHY_USER":"$OMARCHY_USER" "$USER_HOME/.config" 2>/dev/null || true
info "Theming done"
