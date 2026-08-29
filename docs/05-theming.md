# 05 — Theming

Omarchy's theme system is one of its best features. It restyles Hyprland,
waybar, the terminal, Neovim, btop, lazygit, the launcher and more from a
single command.

## Switching themes

```bash
omarchy-theme-list
omarchy-theme-set "Tokyo Night"
```

Bundled themes (from `/usr/share/omarchy/themes/`):

| | | |
|---|---|---|
| Catppuccin | Catppuccin Latte | Everforest |
| Gruvbox | Kanagawa | Matte Black |
| Nord | Osaka Jade | Ristretto |
| Rose Pine | Tokyo Night | Flexoki Light |
| Hackerman | Lumon | Ethereal |

## Theming without a compositor

`omarchy-theme-set` normally reloads Hyprland, waybar and swaybg — which don't
exist in Mode 1. Upstream provides escape hatches, and this project uses them at
build time:

```bash
OMARCHY_THEME_HEADLESS=1 OMARCHY_THEME_SKIP_BACKGROUND=1 \
  omarchy-theme-set "Gruvbox"
```

Use those two variables whenever you change theme from a headless shell.

Set the build-time default with:

```bash
make all OMARCHY_THEME="Catppuccin"
```

## Windows Terminal

In Modes 1 and 2, Windows Terminal *is* your visible environment, so match it to
your Omarchy theme.

### The easy way: `omarchy-wsl-wt`

The image ships a configurator that styles the Terminal profile for you:

```bash
omarchy-wsl-wt --interactive
```

It prompts for each setting and shows the current value as the default, so you
can just press Enter to accept:

```
  Colour scheme [tokyo-night]:
  Font face [JetBrainsMono Nerd Font]:
  Font size [11.0]:
  Background opacity (0-100) [90]:
  Use acrylic blur (yes/no) [yes]:
  Padding [10]:
  Cursor shape [filledBox]:
  Make this the default Windows Terminal profile (yes/no) [no]:
```

**Already like how another profile looks?** Inherit its settings as the
defaults, then tweak:

```bash
omarchy-wsl-wt --interactive --from-profile Ubuntu
```

```
  ✔ Inheriting look from profile 'Ubuntu'
      font_face = Hack
      opacity = 90
      acrylic = True
```

Non-interactive use:

```bash
omarchy-wsl-wt --theme "Gruvbox" --opacity 85 --font "Hack"
omarchy-wsl-wt --set-default
omarchy-wsl-wt --detect          # show what it would do, change nothing
omarchy-wsl-wt --list-themes
omarchy-wsl-wt --list-profiles
omarchy-wsl-wt --restore         # undo - it backs up settings.json first
```

It also installs the project icon to
`%LOCALAPPDATA%\omarchy-wsl2\omarchy-wsl2.ico` and points the profile at it, so
the tab and dropdown show the Omarchy mark.

You can also reach this from the wizard:

```bash
./omarchy-wsl2      # -> "Windows Terminal"
```

> Every change is preceded by a timestamped backup
> (`settings.json.omarchy-bak.<epoch>`), and `--restore` puts the most recent
> one back.

### Doing it by hand

WSL auto-generates a profile from `/usr/lib/wsl/terminal-profile.json` at
install time. To change it later, edit Windows Terminal's `settings.json`
(`Ctrl+Shift+,`) and adjust the `omarchy` profile:

```json
{
  "name": "omarchy",
  "colorScheme": "Omarchy Tokyo Night",
  "font": { "face": "JetBrainsMono Nerd Font", "size": 11 },
  "opacity": 90,
  "useAcrylic": true,
  "padding": "10",
  "icon": "%LOCALAPPDATA%\\omarchy-wsl2\\omarchy-wsl2.ico"
}
```

### Install the Nerd Font on Windows

Omarchy's prompt, `eza` icons and Neovim UI all use Nerd Font glyphs. The font
is installed *inside* the distro, but **Windows Terminal renders with Windows
fonts**, so you must install it on the Windows side too:

```powershell
winget install --id DEVCOM.JetBrainsMonoNerdFont
```

Or download from [nerdfonts.com](https://www.nerdfonts.com/font-downloads) and
install the `JetBrainsMono` TTFs.

Without this you'll see `` boxes instead of icons.

### Matching colour schemes

Ports of Omarchy's themes for Windows Terminal exist here:
[tvcam/omarchy-theme-wsl](https://github.com/tvcam/omarchy-theme-wsl) — 17
schemes for Windows Terminal and VS Code.

Or grab any scheme from
[windowsterminalthemes.dev](https://windowsterminalthemes.dev/) and paste it
into the `schemes` array.

## VS Code

Omarchy ships a theme-setter for VS Code:

```bash
omarchy-theme-set-vscode
```

When using the WSL remote extension, VS Code's UI runs on **Windows**, so
install the matching colour theme extension on the Windows side. Search the
marketplace for your theme (e.g. "Tokyo Night", "Catppuccin", "Gruvbox").

Then in `settings.json`:

```json
{
  "workbench.colorTheme": "Tokyo Night",
  "editor.fontFamily": "'JetBrainsMono Nerd Font', Consolas, monospace",
  "terminal.integrated.fontFamily": "'JetBrainsMono Nerd Font'"
}
```

## Wallpapers (Modes 3a/3b)

```bash
omarchy-theme-bg-next
```

Wallpapers live in `~/.config/omarchy/current/theme/backgrounds/`. In headless
mode there's nothing to draw them on, which is why the build sets
`OMARCHY_THEME_SKIP_BACKGROUND=1`.

## Writing your own theme

A theme is a directory of config fragments:

```
~/.config/omarchy/themes/my-theme/
├── alacritty.toml
├── backgrounds/
├── btop.theme
├── hyprland.conf
├── hyprlock.conf
├── mako.ini
├── neovim.lua
├── waybar.css
└── walker.css
```

Copy an existing one and edit:

```bash
cp -r /usr/share/omarchy/themes/tokyo-night ~/.config/omarchy/themes/my-theme
nvim ~/.config/omarchy/themes/my-theme/waybar.css
omarchy-theme-set "my-theme"
```

Themes in `~/.config/omarchy/themes/` survive `omarchy-update`; edits to
`/usr/share/omarchy/themes/` do not.

## Terminal inside the desktop

In Modes 3a/3b, `foot` is Omarchy's terminal and picks up the theme
automatically. Its config is `~/.config/foot/foot.ini`, themed via
`~/.config/omarchy/current/theme/foot.ini`.

## Consistency checklist

For a coherent look across Windows and Linux:

- [ ] `omarchy-theme-set "<theme>"` inside the distro
- [ ] Matching Windows Terminal colour scheme
- [ ] JetBrainsMono Nerd Font installed **on Windows**
- [ ] Matching VS Code theme extension installed on Windows
- [ ] `omarchy-theme-set-vscode` for the WSL-side settings
