#!/bin/sh
# omarchy-wsl-term.sh - keep TERM resolvable so readline keeps working.
#
# Symptom this prevents: arrow keys echoing ^[[A ^[[C instead of moving the
# cursor or walking shell history, and Home/End/Delete doing nothing.
#
# Cause: bash's line editor (readline) needs a terminfo entry for $TERM. When
# there is none it falls back to a minimal mode with no key bindings, so the
# raw escape sequences get printed instead of interpreted.
#
# Under WSL2 this bites in two ways:
#   * terminals set their own TERM (alacritty, foot, ghostty) and the matching
#     terminfo entry may not be installed - it often lives in a separate
#     package, or the terminal is newer than the installed ncurses
#   * Windows Terminal and some SSH clients can pass through a TERM that does
#     not exist on the Linux side at all
#
# We only override when the entry is genuinely missing, so a correctly
# configured terminal keeps its own capabilities (true colour, etc).

if [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ] && command -v infocmp >/dev/null 2>&1; then
    if ! infocmp "$TERM" >/dev/null 2>&1; then
        for _owsl_t in xterm-256color xterm-color xterm vt100; do
            if infocmp "$_owsl_t" >/dev/null 2>&1; then
                [ -n "${OMARCHY_WSL_TERM_QUIET:-}" ] || printf \
                  'note: no terminfo for TERM=%s - using %s so arrow keys work\n' \
                  "$TERM" "$_owsl_t" >&2
                TERM="$_owsl_t"
                export TERM
                break
            fi
        done
        unset _owsl_t
    fi
fi

# COLORTERM tells applications true colour is available. WSLg, Windows
# Terminal and every terminal we ship support it, but not all set it.
[ -n "${COLORTERM:-}" ] || export COLORTERM=truecolor
