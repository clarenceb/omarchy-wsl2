# 09 — Troubleshooting

Run this first — it checks almost everything below:

```bash
omarchy-wsl-doctor
```

---

## Build-time problems

### `wsl --import` fails with `0x80070050`

The install directory already exists and isn't empty.

```bash
make clean && make seed
```

### `pacman-key --populate archlinux` fails on ARM

Arch Linux ARM uses a different keyring. The build handles this, but if you're
doing it by hand:

```bash
pacman-key --init
pacman-key --populate archlinuxarm
pacman -S archlinuxarm-keyring
```

### `error: GPGME error: No data` / signature errors

Stale keyring in the base image:

```bash
wsl -d omarchy-build -u root
rm -rf /etc/pacman.d/gnupg
pacman-key --init && pacman-key --populate archlinux
pacman -Sy archlinux-keyring
```

### `could not open file ... Permission denied` during download

Pacman's Landlock download sandbox doesn't work in unprivileged image builds.
`00-pacman.sh` disables it; if you're building by hand, in `/etc/pacman.conf`:

```ini
[options]
DisableSandbox
#DownloadUser = alpm
```

`90-cleanup.sh` re-enables it before export.

### `error: not enough free disk space`

WSL misreports free space. The build comments out `CheckSpace`; verify with:

```bash
grep CheckSpace /etc/pacman.conf     # should be commented
```

### Build succeeds but packages are missing

Expected on aarch64. Check what was skipped:

```bash
wsl -d omarchy-build -u root -- cat /var/log/omarchy-wsl2-missing.log
```

See [08-arm64.md](08-arm64.md).

### `make export` produces a huge file

Run cleanup, and confirm the package cache was cleared:

```bash
wsl -d omarchy-build -u root -- du -sh /var/cache/pacman/pkg
```

---

## Install-time problems

### Double-clicking the `.wsl` does nothing

`[oobe] defaultName` must be set in `/etc/wsl-distribution.conf`. Verify:

```bash
tar -xzOf dist/omarchy-desktop-x86_64.wsl etc/wsl-distribution.conf | head
```

Or install explicitly:

```powershell
wsl --install --from-file omarchy-desktop-x86_64.wsl --name omarchy
```

### `WSL_E_DISTRO_NOT_FOUND` / "invalid distribution"

Your WSL is older than 2.4.4:

```powershell
wsl --version
wsl --update
```

### First launch drops me at a `root` prompt

`oobe.command` only runs for `wsl --install --from-file`, not `wsl --import`.
Set the default user manually:

```powershell
wsl --manage omarchy --set-default-user omarchy
```

### "The system cannot find the file specified" on launch

Usually a broken `/etc/wsl.conf`. Get in as root and inspect:

```powershell
wsl -d omarchy -u root
```

---

## Runtime problems

### systemd isn't running

```bash
systemctl status          # "System has not been booted with systemd"
```

Check `/etc/wsl.conf` contains:

```ini
[boot]
systemd=true
```

then from Windows:

```powershell
wsl --shutdown
```

A full `--shutdown` is required — restarting the terminal isn't enough.

### GUI apps don't start

```bash
omarchy-wsl-doctor
```

Common causes:

| Symptom | Cause | Fix |
|---|---|---|
| `/mnt/wslg` missing | WSLg not installed | `wsl --update` |
| No Wayland socket | Socket not in `XDG_RUNTIME_DIR` | `source /usr/local/bin/omarchy-wsl-env && owsl_export_wslg_env` |
| `cannot open display` | `DISPLAY` unset | `export DISPLAY=:0` |
| Works as root, not as user | `XDG_RUNTIME_DIR` perms | `chmod 700 /run/user/$(id -u)` |

### OpenGL falls back to `llvmpipe`

```bash
glxinfo -B | grep "OpenGL renderer"
```

If it's software on an Intel iGPU, that's
[microsoft/wslg#996](https://github.com/microsoft/wslg/issues/996):

```bash
sudo ln -s /usr/lib/libedit.so /usr/lib/libedit.so.2
```

Also confirm the driver packages exist:

```bash
sudo pacman -S mesa mesa-utils vulkan-icd-loader vulkan-dzn
export GALLIUM_DRIVER=d3d12
```

### No sound

```bash
ls -l /mnt/wslg/PulseServer
export PULSE_SERVER=/mnt/wslg/PulseServer
```

### Hyprland: `wlr_backend_get_drm_fd() failed!`

You're trying to run the DRM backend. It cannot work under WSL2 — there's no
KMS device. Use the helper:

```bash
omarchy-wsl-desktop          # nested
omarchy-wsl-desktop vnc      # headless + VNC
```

Never run bare `Hyprland` on WSL.

### Nested Hyprland starts then exits immediately

Check the log:

```bash
tail -50 ~/.local/share/hyprland/hyprland.log
```

Then try software rendering:

```bash
omarchy-wsl-desktop --software
```

Also confirm the WSL override file is being sourced:

```bash
grep -n 'conf/wsl.conf' ~/.config/hypr/hyprland.conf
```

### Nested Hyprland ignores my `SUPER` keybindings

Expected. WSLg's outer compositor claims some combinations first. Use VNC mode,
which owns its own input:

```bash
omarchy-wsl-desktop vnc
```

### VNC client can't connect

```bash
ss -tlnp | grep 5900        # is wayvnc listening?
```

If yes but Windows can't reach it, you're probably in mirrored networking mode.
Either switch back in `.wslconfig`:

```ini
[wsl2]
networkingMode=NAT
```

or connect to the distro's address:

```bash
hostname -I
```

### `omarchy-theme-set` hangs or errors headlessly

It's trying to reload a compositor that isn't running:

```bash
OMARCHY_THEME_HEADLESS=1 OMARCHY_THEME_SKIP_BACKGROUND=1 \
  omarchy-theme-set "Tokyo Night"
```

### Fonts render as boxes

The Nerd Font must be installed **on Windows**, since Windows Terminal renders
with Windows fonts:

```powershell
winget install --id DEVCOM.JetBrainsMonoNerdFont
```

### `omarchy-update` tries to replay old migrations

The build marks them applied. If state was lost:

```bash
for m in /usr/share/omarchy/migrations/*.sh; do
  touch ~/.local/state/omarchy/migrations/"$(basename "$m" .sh)"
done
```

### Slow git / npm / builds

You're on `/mnt/c`. Move the project to the Linux filesystem:

```bash
mv /mnt/c/Users/you/code/project ~/code/project
```

### The distro won't stop / uses too much RAM

```powershell
wsl --shutdown
```

Cap it in `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
memory=8GB
processors=4
```

---

## Starting over

```bash
make uninstall              # remove the installed distro
make clean                  # remove the build distro
make all                    # rebuild
```

Keep a backup before experimenting:

```powershell
wsl --export omarchy C:\backups\omarchy.tar
```

---

## Getting help

Include the output of these when reporting an issue:

```bash
omarchy-wsl-doctor
wsl.exe --version
uname -m
cat /etc/omarchy.conf
cat /var/log/omarchy-wsl2-missing.log
tail -50 ~/.local/share/hyprland/hyprland.log
```

Upstream Omarchy questions belong at
[basecamp/omarchy](https://github.com/basecamp/omarchy/issues) — but note that
WSL is not supported upstream ([#469](https://github.com/basecamp/omarchy/issues/469)).
