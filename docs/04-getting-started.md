# 04 — Getting started

Your first thirty minutes with Omarchy on WSL2.

## First launch

```bash
wsl -d omarchy
```

The OOBE runs once: it adopts the baked-in `omarchy` account (uid 1000) and
offers to set a password. Then you land in a themed bash shell.

```bash
omarchy-wsl-help        # the cheat sheet
omarchy-wsl-doctor      # verify WSLg, GPU, systemd, desktop readiness
fastfetch               # the obligatory screenshot
```

## Where everything lives

| Path | What |
|---|---|
| `/usr/share/omarchy/` | Vendored Omarchy: `bin/`, `config/`, `themes/`, `default/` |
| `/usr/share/omarchy/bin/` | The 284 `omarchy-*` commands (on your `PATH`) |
| `~/.config/` | **Your** dotfiles, seeded from Omarchy's `config/` |
| `~/.config/omarchy/current/theme` | Symlink to the active theme |
| `~/.config/omarchy-wsl2/env.sh` | WSLg environment, sourced by `.bashrc` |
| `~/.config/sway/local.conf` | Your desktop overrides (included last) |
| `/etc/omarchy.conf` | `OMARCHY_PATH` and version |
| `/etc/wsl.conf` | systemd, default user, interop |
| `/usr/local/bin/omarchy-wsl-*` | This project's helpers |

## Essential commands

```bash
# System
omarchy-update                # update Omarchy + system packages
omarchy-update-available      # anything pending?
sudo pacman -Syu              # plain system upgrade
omarchy-pkg-add <package>     # install a package

# Themes
omarchy-theme-set "Tokyo Night"
omarchy-theme-list

# WSL-specific (this project)
omarchy-wsl-doctor            # diagnostics
omarchy-wsl-app <cmd>         # run a GUI app through WSLg
omarchy-wsl-desktop           # nested in a WSLg window
omarchy-wsl-desktop vnc       # full screen over VNC
omarchy-wsl-help              # cheat sheet
```

## The TUI toolkit you now have

| Command | What it replaces |
|---|---|
| `nvim` | Omarchy's configured Neovim (LSP, treesitter, telescope) |
| `lazygit` | `git` porcelain — genuinely worth learning |
| `btop` | `top` / `htop` |
| `eza` | `ls` (`ls` is aliased to it) |
| `bat` | `cat` with syntax highlighting |
| `fd` | `find` |
| `rg` | `grep` |
| `fzf` | Fuzzy finder — `Ctrl-R` for history, `Ctrl-T` for files |
| `zoxide` | `cd` that learns — type `z proj` |
| `dua` | `du` with an interactive TUI |
| `tldr` | `man`, but examples first |

## Files, and the performance rule

This is the single most impactful thing to get right in WSL:

> **Keep Linux projects on the Linux filesystem.** Files under `/mnt/c` cross a
> 9p bridge and are dramatically slower for git, npm and builds.

```bash
# Fast   - native ext4 inside the WSL VHDX
~/code/my-project

# Slow   - Windows filesystem over 9p
/mnt/c/Users/you/code/my-project
```

Get to your Linux files from Windows via `\\wsl.localhost\omarchy\home\omarchy`,
or:

```bash
explorer.exe .
```

## Windows interop

```bash
explorer.exe .            # open the current directory in Explorer
code .                    # open VS Code (WSL remote) - see 06-dev-tools.md
notepad.exe file.txt
clip.exe < file.txt       # copy into the Windows clipboard
wslpath -w ~/code         # Linux path -> Windows path
wslpath -u 'C:\Users'     # Windows path -> Linux path
```

Clipboard works both ways with `wl-copy` / `wl-paste` once WSLg is up.

## Basic configuration

### Shell

`~/.bashrc` comes from Omarchy's `default/bashrc`, with this project's block
appended. Put your own changes at the end, or in a sourced file:

```bash
echo 'alias k=kubectl' >> ~/.bashrc
```

### The desktop session

The compositor is **sway**, not Hyprland — Hyprland cannot start under WSL2 at
all ([12-wayland-on-wsl2.md](12-wayland-on-wsl2.md)). Config lives in
`~/.config/sway/`:

| File | Purpose |
|---|---|
| `config` | The session, generated at build time. Safe to read, but re-created on rebuild |
| `local.conf` | **Your overrides.** Included last, so it always wins |
| `theme.conf` | Colours, written by the theme bridge |

Put your own changes in `local.conf`:

```bash
nvim ~/.config/sway/local.conf
swaymsg reload          # apply without restarting the session
```

`~/.config/hypr/` is still present so Omarchy's own config stays readable and
`omarchy-update` keeps working, but nothing reads it in this session.

### Neovim

```bash
nvim ~/.config/nvim/lua/config/       # your overrides
```

Omarchy's Neovim is LazyVim-based. Don't edit the Omarchy-managed files —
add your own under `lua/plugins/`.

## Keybindings worth knowing

These apply in Mode 3. `SUPER` is the **Windows key**.

**New to tiling? Start with these five.** They are enough to be productive:

| Keys | Action |
|---|---|
| `SUPER + Return` | Open a terminal |
| `SUPER + W` | Close the focused window |
| `SUPER + Space` | Launcher |
| `SUPER + H` / `SUPER + L` | Move focus left / right |
| `SUPER + F` | Fullscreen the focused window |

The rest:

| Keys | Action |
|---|---|
| `SUPER + J` / `SUPER + K` | Focus down / up (arrows work too) |
| `SUPER + SHIFT + H/J/K/L` | Move the window itself |
| `SUPER + 1..9` | Switch workspace |
| `SUPER + SHIFT + 1..9` | Move window to workspace |
| `SUPER + V` / `SUPER + G` | Split vertical / horizontal |
| `SUPER + T` | Tabbed layout |
| `SUPER + SHIFT + Space` | Toggle floating for this window |
| `SUPER + R` | Resize mode — arrows or `hjkl`, `Esc` to finish |
| `SUPER` + left-drag | Move a floating window |
| `SUPER` + right-drag | Resize any window |
| `SUPER + B` / `SUPER + E` | Browser / file manager |
| `Print` / `SHIFT + Print` | Region screenshot (annotate in satty) / full screen to clipboard |
| `SUPER + SHIFT + R` | Reload the config |
| `SUPER + SHIFT + E` | Exit the session |

Run `omarchy-wsl-help` — it is what the welcome terminal shows on startup.

### Don't want tiling?

```bash
omarchy-wsl-desktop --floating     # draggable windows with titlebars
omarchy-wsl-desktop --tiling       # back to Omarchy's model
```

> In Mode 3a (nested) the outer WSLg compositor claims some `SUPER`
> combinations before sway sees them. Mode 3b (VNC) doesn't have this
> problem — another reason to prefer it.

## Backups

The whole distro is one file:

```powershell
wsl --export omarchy C:\backups\omarchy-2026-08-29.tar
wsl --import omarchy-restored C:\wsl\restored C:\backups\omarchy-2026-08-29.tar
```

Rebuilding from this repo is also always an option — that's the point of it.

## Next

- [05-theming.md](05-theming.md) — make it yours
- [06-dev-tools.md](06-dev-tools.md) — VS Code, Copilot CLI, mise, Docker
- [03-modes.md](03-modes.md) — the desktop, in depth
- [Omarchy manual](https://omarchy.org/manual/) — upstream, and worth reading end to end
