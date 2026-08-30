# 13 — Post-install: finding your way around

You've built and installed the image. This is the tour: what this project adds
on top of Omarchy, and the order worth doing things in.

> Everything here is **specific to omarchy-wsl2**. Upstream Omarchy's own
> commands (`omarchy-theme-set`, `omarchy-pkg-add`, `omarchy-update`, …) all
> still work — see [05-theming.md](05-theming.md) and the
> [Omarchy manual](https://omarchy.org/manual/).

---

## First ten minutes

```bash
omarchy-wsl-doctor        # is everything actually working?
omarchy-wsl-help          # the cheat sheet, including every keybinding
oml "what omarchy-wsl helpers are available"
```

`omarchy-wsl-doctor` is the one to run whenever something feels wrong. It
checks WSL detection, systemd, the WSLg sockets, `/dev/dxg`, the renderer, and
whether the desktop pieces are installed — and tells you what a failure means
rather than just reporting it.

---

## The helpers

Every command this project adds is prefixed `omarchy-wsl-`, so tab completion
lists them:

```bash
omarchy-wsl-<TAB><TAB>
```

### Running the desktop — `omarchy-wsl-desktop`

```bash
omarchy-wsl-desktop                      # nested in a WSLg window
omarchy-wsl-desktop vnc                  # full screen over VNC  (recommended)
omarchy-wsl-desktop vnc --size 2560x1440 # match your monitor
omarchy-wsl-desktop --floating           # draggable windows with titlebars
omarchy-wsl-desktop --tiling             # Omarchy's tiling model (default)
```

| Flag | Purpose |
|---|---|
| `--size WxH` | Virtual output size in VNC mode |
| `--port N` | VNC port (default 5900) |
| `--bind ADDR` | VNC bind address (default `127.0.0.1`) |
| `--floating` / `--tiling` | Window behaviour; persists in `~/.config/sway/local.conf` |
| `--compositor hyprland` | Demonstrates why Hyprland can't run here |

**Prefer VNC.** `SUPER` keybindings work (WSLg intercepts them when nested),
and it composites once instead of twice. See
[03-modes.md](03-modes.md#mode-3b--headless--vnc-recommended).

**Shutting the desktop down.** In order of cleanliness:

| How | What happens |
|---|---|
| `SUPER+Shift+E` in the session | sway exits properly, tearing clients down in order. **Best.** |
| `swaymsg exit` from another shell | Identical, just triggered externally |
| `Ctrl-C` on the launching terminal | The launcher asks sway to exit via IPC, then falls back to `SIGTERM`, then `SIGKILL`. Safe |
| Closing the nested window | Same as `SIGTERM` to sway |
| `wsl --terminate <distro>` | Kills the whole VM. Fine, but nothing gets to save state |

`Ctrl-C` is **not** harmful — the launcher traps it and shuts sway down
gracefully. The only real cost of an abrupt exit is that applications don't
get to save unsaved work, exactly as on any desktop.

### Backgrounds — `omarchy-wsl-bg`

```bash
omarchy-wsl-bg                  # list; * marks the current one
omarchy-wsl-bg 3                # set the third
omarchy-wsl-bg next             # cycle          (also SUPER+Shift+W)
omarchy-wsl-bg ~/Pictures/x.png # any image
omarchy-wsl-bg --colour 0d1120  # flat colour
```

Changes apply to the **running session** immediately. It searches your theme's
backgrounds, `~/.config/omarchy/backgrounds/<theme>/`,
`~/Pictures/wallpapers/`, and the four gradients this project ships in
`/usr/share/omarchy-wsl2/wallpapers/`.

> Use this rather than `omarchy-theme-bg-next`, which pushes over IPC to
> Quickshell and does nothing here. See
> [05-theming.md](05-theming.md#wallpapers-modes-3a3b).

### GUI apps — `omarchy-wsl-app` and `omarchy-wsl-open`

```bash
omarchy-wsl-app chromium        # as an ordinary Windows window, D3D12 accelerated
omarchy-wsl-app nautilus ~/code
omarchy-wsl-open report.pdf     # open in the right app
omarchy-wsl-open https://…
```

**Use `omarchy-wsl-app` for anything GPU-bound** — browsers, video, anything
that scrolls a lot. Inside the desktop session those are CPU-rendered.

### Developer tools — `omarchy-wsl-devtools`

```bash
sudo omarchy-wsl-devtools --list
sudo omarchy-wsl-devtools gh mise docker
```

Bundles: `gh`, `mise`, `docker`, `copilot`, `wslu`, `learn`. See
[06-dev-tools.md](06-dev-tools.md).

### Windows Terminal — `omarchy-wsl-wt`

```bash
omarchy-wsl-wt -i               # interactive: theme the profile to match
omarchy-wsl-wt --restore        # undo the last change
```

Matters most in Mode 1, where Windows Terminal *is* your desktop.

### The tutor — `omarchy-learn` / `oml`

```bash
oml "how do I change the desktop background"
oml "why is the desktop sway and not Hyprland"
oml --topics                    # suggested questions
oml --check                     # verify Copilot CLI and auth
```

It reads this project's docs and the vendored Omarchy source before answering,
so it knows about the helpers above and about *your* setup's constraints — not
just generic Arch advice. See [11-omarchy-learn.md](11-omarchy-learn.md).

### Credentials — `omarchy-wsl-keyring`

If a tool asks:

```
System keychain unavailable. Store token in plaintext config file? (y/N)
```

answer **N**, then:

```bash
omarchy-wsl-keyring             # set up the keyring
omarchy-wsl-keyring --status    # what's running
omarchy-wsl-keyring --test      # store and read back a test secret
```

and re-run the tool. Affects GitHub Copilot CLI, `gh`, VS Code and anything
else using the Secret Service API.

**Why it's needed:** those tools look for `gnome-keyring` on D-Bus. On a
desktop the display manager starts it and PAM unlocks it at login; WSL has
neither. Current images start it with the desktop session and from
`omarchy-wsl-env`, so this is usually already working — the helper is for
first-time setup and for diagnosing.

By default the keyring is created with an **empty password** so it unlocks
without prompting. That is a deliberate WSL trade-off: the keyring file sits
in your distro's VHDX, already readable by anything running as you. It is
meaningfully better than plaintext config — secrets aren't in a dotfile that
gets committed or copied to `/mnt/c` — but it is not protection against
someone with your Windows account. For that:

```bash
omarchy-wsl-keyring --password  # prompts to unlock once per session
```

### Under the hood

| Command | Notes |
|---|---|
| `omarchy-wsl-env` | A sourced library of WSL/WSLg/D-Bus/keyring helpers, not a command |
| `xdg-terminal-exec` | A shim; Omarchy's TUI `.desktop` entries call it and it's AUR-only |
| `/etc/profile.d/omarchy-wsl-term.sh` | Repairs `$TERM` when its terminfo entry is missing, so readline keeps working |

---

## The wizard — `./omarchy-wsl2`

Run from the checkout, in **any** WSL2 distro. It is re-runnable and safe to
re-enter at any point.

```
1) Check prerequisites  Verify the host and offer to install what's missing
2) Build & install      Create a new Omarchy WSL2 distro from scratch
3) Modify existing      Change theme, add tools or tiers, update
4) Set up omarchy-learn AI tutor for Omarchy & WSL2 questions
5) Diagnostics          Check WSLg, GPU, systemd and desktop readiness
6) Windows extras       Nerd Font, Windows Terminal, VS Code
7) Documentation        Where to read more
8) Uninstall            Remove the distro
```

Choosing the **desktop** profile adds three questions — window layout, display
mode, and full-screen resolution (it detects your Windows resolution). Answers
are remembered in `.omarchy-wsl2.conf` beside the checkout.

Everything the wizard does is also a Makefile target, if you prefer:

```bash
make all PROFILE=desktop OMARCHY_LAYOUT=floating
make install
make doctor
```

See [02-build.md](02-build.md) and [10-reference.md](10-reference.md).

---

## Where your configuration lives

| Path | What |
|---|---|
| `~/.config/sway/local.conf` | **Your desktop overrides.** Included last, always wins |
| `~/.config/sway/config` | The generated session — re-created on rebuild |
| `~/.config/waybar-sway/` | The bar (sway-native; Omarchy's own is Hyprland-specific) |
| `~/.config/wofi/`, `~/.config/mako/` | Launcher and notifications |
| `~/.config/omarchy/` | Omarchy's own config and themes |
| `~/.local/share/applications/` | Desktop entries, including `Hidden=true` suppressions |
| `/usr/share/omarchy-wsl2/docs` | These docs, on the installed system |
| `/usr/share/omarchy/` | The vendored Omarchy source |

**Rule of thumb:** put personal changes in `local.conf`. Anything in
`~/.config/sway/config` is regenerated when you rebuild.

```bash
nvim ~/.config/sway/local.conf
swaymsg reload                 # apply without restarting the session
```

> Copying a fresh config set over `~/.config/sway/` replaces `local.conf` and
> silently reverts your layout choice. Re-run `omarchy-wsl-desktop --floating`
> afterwards.

---

## A sensible first session

```bash
# 1. Check the install
omarchy-wsl-doctor

# 2. Install a VNC viewer on Windows (PowerShell)
#    winget install -e --id TigerVNC.TigerVNC

# 3. Start the desktop full screen, floating if tiling is new to you
omarchy-wsl-desktop vnc --size 1920x1080 --floating

# 4. Connect TigerVNC to 127.0.0.1:5900, then press F8 -> Full screen
#    (Ctrl+M on TigerVNC 1.16+)

# 5. In the session
#    SUPER+Return   terminal          SUPER+Space  launcher
#    SUPER+W        close             SUPER+F      fullscreen
#    SUPER+Shift+W  next background   SUPER+Shift+E exit

# 6. Make it yours
omarchy-theme-set "Tokyo Night"
omarchy-wsl-bg
```

---

## When something doesn't work

1. `omarchy-wsl-doctor` — it explains failures, not just reports them
2. [09-troubleshooting.md](09-troubleshooting.md) — known failures and fixes
3. `oml "<what you saw>"` — the tutor reads these docs before answering
4. [12-wayland-on-wsl2.md](12-wayland-on-wsl2.md) — if it's graphics-related,
   the answer is probably "no DRM node", and this explains what that means

Messages that look alarming but are **harmless**, all covered in
[09-troubleshooting.md](09-troubleshooting.md):

```
MESA-EGL: warning: failed to get driver name for fd -1
ERROR: ../wayvnc/src/ext-image-copy-capture.c: No supported buffer formats were found
WARNING: dzn is not a conformant Vulkan implementation
swaybg: Could not find config for output HEADLESS-1
```

---

## Sane defaults you get out of the box

Things this project configures so you don't have to. All are overridable.

| Area | Default | Why |
|---|---|---|
| Compositor | sway, CPU-rendered | Hyprland cannot start on WSL2 at all |
| Window layout | Tiling | Omarchy's model; `--floating` if you prefer Windows/GNOME |
| Display mode | Your wizard choice | VNC full screen is recommended |
| `$TERM` | Repaired if terminfo is missing | Otherwise arrow keys print `^[[A` and history stops working |
| Readline | Up/Down search history by prefix, case-insensitive completion, `Ctrl-S` freeze disabled | Sane interactive shell |
| Keyring | `gnome-keyring` started with the session | Credentials stored properly, not in plaintext |
| D-Bus | Session bus started if systemd's user manager fails | Docker Desktop's WSL integration often breaks it |
| Xwayland | Disabled in the session | WSLg owns `/tmp/.X11-unix`; use `omarchy-wsl-app` for X11 |
| Launcher entries | Omarchy's, plus `Hidden=true` stubs for junk | Stops broken tools appearing in `SUPER+Space` |
| `wayvnc` bind | `127.0.0.1` | Reachable from Windows, not from your LAN |
| Wallpaper | Theme's, falling back to a shipped gradient | Never a black screen |
| pacman DBs | Kept in the image | `pacman -S` works on first run |
| `systemd-binfmt` | Masked | Stopping this distro would otherwise break `.exe` in every distro |
