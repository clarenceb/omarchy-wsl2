# 10 — Reference

## Repository layout

```
omarchy-wsl2/
├── omarchy-wsl2                 interactive wizard (start here)
├── Makefile                     build pipeline entrypoint
├── README.md                    overview + diagrams
├── LICENSE                      MIT
├── assets/
│   ├── logo.svg                 original mark (source of truth)
│   ├── logo-wordmark.svg        mark + wordmark lockup
│   ├── omarchy-learn.svg        omarchy-learn mark
│   └── omarchy-wsl2.ico         generated; Start-menu icon
├── docs/                        this documentation
├── packages/
│   ├── base.packages            tier 1 - headless CLI/TUI
│   ├── apps.packages            tier 2 - WSLg GUI apps
│   ├── desktop.packages         tier 3 - Hyprland session
│   └── omarchy-repo.packages    x86_64-only, from pkgs.omarchy.org
├── overlay/
│   ├── usr/local/bin/
│   │   ├── omarchy-wsl-env      shared WSLg environment detection
│   │   ├── omarchy-wsl-doctor   diagnostics
│   │   ├── omarchy-wsl-app      run one GUI app via WSLg
│   │   ├── omarchy-wsl-desktop  nested / VNC Hyprland
│   │   ├── omarchy-wsl-devtools developer tool bundles
│   │   └── omarchy-wsl-help     cheat sheet
│   └── opt/omarchy-learn/
│       ├── bin/omarchy-learn    the AI tutor (symlinked as 'oml')
│       └── share/system-prompt.md
├── scripts/
│   ├── lib.sh                   host helpers
│   ├── fetch-rootfs.sh          download base rootfs
│   ├── seed.sh                  wsl --import the build distro
│   ├── provision.sh             stage sources + run the guest chain
│   ├── export.sh                wsl --export -> gzip -> .wsl
│   ├── make-logo.py             SVG -> PNG/ICO
│   └── provision/               in-guest stages 00..90
├── wsl/
│   ├── wsl.conf                 -> /etc/wsl.conf
│   ├── wsl-distribution.conf    -> /etc/wsl-distribution.conf
│   ├── oobe.sh                  -> /etc/oobe.sh
│   └── terminal-profile.json    -> /usr/lib/wsl/terminal-profile.json
└── windows/
    ├── omarchy-wsl2.ps1         launch the wizard from Windows
    └── Override-Manifest.ps1    publish in `wsl --list --online`
```

## Make variables

| Variable | Default | Purpose |
|---|---|---|
| `PROFILE` | `desktop` | `headless` \| `apps` \| `desktop` |
| `ARCH` | `$(uname -m)` | Target architecture |
| `NAME` | `omarchy` | Installed distro name |
| `DISTRO` | `$(NAME)` | Distro to install/run |
| `BUILD_DISTRO` | `$(NAME)-build` | Throwaway build distro |
| `OMARCHY_REF` | `master` | Omarchy git ref |
| `OMARCHY_REPO` | `basecamp/omarchy` | Upstream repo |
| `OMARCHY_THEME` | `Tokyo Night` | Build-time theme |
| `OMARCHY_USER` | `omarchy` | Baked uid 1000 account |
| `WIN_ROOT` | `/mnt/c/wsl/omarchy-wsl2` | Artefact root |
| `CACHE_DIR` | `$(WIN_ROOT)/cache` | Downloaded rootfs |
| `BUILD_DIR` | `$(WIN_ROOT)/build` | Build distro VHDX |
| `DIST_DIR` | `$(WIN_ROOT)/dist` | Output `.wsl` |

> WSL sets a `NAME` environment variable (the Windows hostname). The Makefile
> ignores it unless `NAME=` is given on the command line.

## Upstream Omarchy environment variables

Honoured by Omarchy's own scripts (verified against `basecamp/omarchy@master`):

| Variable | Effect |
|---|---|
| `OMARCHY_PATH` | Omarchy install location |
| `OMARCHY_REF` | Branch: `master` (stable), `dev` (edge), `rc` |
| `OMARCHY_REPO` | Source repo, default `basecamp/omarchy` |
| `OMARCHY_MIRROR` | `stable` \| `edge` \| `rc` pacman mirror |
| `OMARCHY_ONLINE_INSTALL` | Set by `boot.sh`; gates the online repo/keyring block |
| `OMARCHY_CHROOT_INSTALL` | Chroot mode: `systemctl enable` without `--now`, no reboot |
| `OMARCHY_USER_NAME` / `OMARCHY_USER_EMAIL` | Git identity, `.XCompose` |
| `OMARCHY_THEME_HEADLESS` | Theme without a running compositor |
| `OMARCHY_THEME_SKIP_BACKGROUND` | Skip wallpaper application |
| `OMARCHY_INSTALL_USER` | v4/quattro only — target user for `omarchy-apply-*` |

There is **no** `OMARCHY_BARE`, `OMARCHY_HEADLESS`, or `OMARCHY_WSL` flag, and
no WSL/VM auto-detection anywhere in the installer.

## This project's variables

| Variable | Where | Effect |
|---|---|---|
| `OMARCHY_WSL_PROFILE` | build | Tier selection inside the guest |
| `ARCH_WSL_MIRROR` | build | Override the Arch WSL image mirror |
| `ALARM_URL` | build | Override the Arch Linux ARM rootfs URL |
| `GALLIUM_DRIVER` | runtime | `d3d12` for WSLg GPU acceleration |
| `WLR_BACKENDS` | runtime | `wayland` (nested) or `headless` (VNC) |
| `WLR_RENDERER` | runtime | `pixman` forces software rendering |

## WSL configuration reference

### `/etc/wsl-distribution.conf`

| Key | Value | Notes |
|---|---|---|
| `oobe.command` | `/etc/oobe.sh` | Non-zero exit blocks shell access |
| `oobe.defaultUid` | `1000` | Must match the baked account |
| `oobe.defaultName` | `omarchy` | **Required** for double-click install |
| `shortcut.enabled` | `true` | Start-menu entry |
| `shortcut.icon` | `/usr/lib/wsl/omarchy-wsl2.ico` | `.ico`, ≤ 10 MB |
| `windowsterminal.enabled` | `true` | Auto-generate a Terminal profile |
| `windowsterminal.profileTemplate` | `/usr/lib/wsl/terminal-profile.json` | Fragment; omits `name`/`commandLine` |

### `/etc/wsl.conf`

| Section | Key | Value |
|---|---|---|
| `boot` | `systemd` | `true` |
| `user` | `default` | `omarchy` |
| `network` | `hostname` | `omarchy` |
| `network` | `generateResolvConf` | `true` |
| `interop` | `enabled` | `true` |
| `automount` | `options` | `metadata,umask=22,fmask=11` |

## systemd units masked in the image

Per Microsoft's custom-distro guidance, these break WSL distros:

```
systemd-resolved.service          systemd-networkd.service
NetworkManager.service            systemd-tmpfiles-setup.service
systemd-tmpfiles-clean.service    systemd-tmpfiles-clean.timer
systemd-tmpfiles-setup-dev.service
systemd-tmpfiles-setup-dev-early.service
tmp.mount
```

## Base images

| Arch | Source |
|---|---|
| x86_64 | `https://geo.mirror.pkgbuild.com/wsl/latest/archlinux-*.wsl` |
| aarch64 | `http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz` |

## Useful WSL commands

```powershell
wsl --version
wsl --list --verbose
wsl --list --online
wsl -d omarchy
wsl -d omarchy -u root
wsl --terminate omarchy
wsl --shutdown
wsl --unregister omarchy
wsl --export omarchy C:\backup\omarchy.tar
wsl --import omarchy C:\wsl\omarchy C:\backup\omarchy.tar --version 2
wsl --manage omarchy --set-default-user omarchy
wsl --install --from-file omarchy.wsl --name omarchy
wsl --set-default omarchy
```

## `%USERPROFILE%\.wslconfig`

```ini
[wsl2]
memory=8GB
processors=4
vmIdleTimeout=-1
networkingMode=NAT
```

## Upstream sources

| Topic | Link |
|---|---|
| Omarchy manual | https://omarchy.org/manual/ |
| Omarchy repo | https://github.com/basecamp/omarchy |
| Omarchy packages | https://pkgs.omarchy.org |
| Build a custom WSL distro | https://learn.microsoft.com/windows/wsl/build-custom-distro |
| WSL dev environment setup | https://learn.microsoft.com/windows/wsl/setup/environment |
| WSL advanced settings | https://learn.microsoft.com/windows/wsl/wsl-config |
| WSLg | https://github.com/microsoft/wslg |
| Arch on WSL | https://wiki.archlinux.org/title/Install_Arch_Linux_on_WSL |
| Arch Linux ARM | https://archlinuxarm.org |
| Hyprland wiki | https://wiki.hypr.land/ |
| Hyprland on WSL (won't fix) | https://github.com/hyprwm/Hyprland/issues/3479 |
| Omarchy WSL issue (closed) | https://github.com/basecamp/omarchy/issues/469 |
