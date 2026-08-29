# 06 — Development tools

Omarchy is a developer's distribution. Here's how to wire it up on WSL2.

## VS Code

**Install VS Code on Windows, not inside the distro.** The WSL extension runs a
server inside Omarchy while the UI stays native on Windows — you get full Linux
tooling with none of the GUI overhead.

```powershell
winget install Microsoft.VisualStudioCode
```

Then install the [WSL extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl),
and from inside Omarchy:

```bash
cd ~/code/my-project
code .
```

Recommended `settings.json` (Windows side):

```json
{
  "terminal.integrated.defaultProfile.windows": "omarchy",
  "terminal.integrated.fontFamily": "'JetBrainsMono Nerd Font'",
  "remote.WSL.fileWatcher.polling": false,
  "files.eol": "\n"
}
```

> Don't install `visual-studio-code-bin` inside the distro unless you
> specifically want it as a WSLg app. It's a much heavier path for no benefit.

### Alternative: full GUI VS Code via WSLg

If you want VS Code as a Linux app inside the Hyprland session:

```bash
yay -S visual-studio-code-bin     # x86_64 only
omarchy-wsl-app code
```

On aarch64 use the ARM64 `.deb`/tarball from Microsoft, or stick with the
Windows + WSL-extension approach.

## GitHub Copilot CLI

Omarchy's repo ships `github-copilot-cli` as a package (x86_64), but the
official npm distribution works everywhere:

```bash
npm install -g @github/copilot
copilot
```

Authenticate with `/login` inside the CLI, or:

```bash
export GH_TOKEN=$(gh auth token)
```

On x86_64 you can instead use the prebuilt package:

```bash
omarchy-pkg-add github-copilot-cli
```

Other AI CLIs available from Omarchy's repo on x86_64:

```bash
omarchy-pkg-add claude-code       # Anthropic Claude Code
omarchy-pkg-add openai-codex-bin  # OpenAI Codex
omarchy-pkg-add opencode          # OpenCode
```

On aarch64, install these via `npm -g` instead.

## GitHub CLI

```bash
sudo pacman -S github-cli
gh auth login          # opens your Windows browser via $BROWSER
```

`gh auth login` opens a browser — with WSL interop enabled it launches your
Windows browser automatically. If it doesn't:

```bash
sudo omarchy-wsl-devtools wslu     # or rely on the built-in omarchy-wsl-open
```

## Git

Git is preinstalled. Set your identity:

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```

### Share Windows credentials

Reuse Git Credential Manager from your Windows install — no second login, and
it handles 2FA:

```bash
git config --global credential.helper \
  "/mnt/c/Program\\ Files/Git/mingw64/bin/git-credential-manager.exe"
```

### Line endings

Because you'll cross filesystems:

```bash
git config --global core.autocrlf input
```

### SSH keys

Generate inside the distro (fastest), or reuse your Windows keys:

```bash
# reuse Windows keys
cp -r /mnt/c/Users/$USER/.ssh ~/.ssh
chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_*
```

## Opening links and files on Windows

In headless mode the distro has no browser, so interactive logins
(`gh auth login`, `copilot login`, `az login`) have nowhere to send you.

The image ships **`omarchy-wsl-open`**, a dependency-free shim that hands URLs
and files to the Windows default application, and wires it up as `$BROWSER`:

```bash
omarchy-wsl-open https://github.com
omarchy-wsl-open report.pdf
omarchy-wsl-open .              # opens the current dir in File Explorer
```

For the fuller toolset — `wslview`, `wslvar`, `wslsys`, `wslusc` — install
[wslu](https://github.com/wslutilities/wslu):

```bash
sudo omarchy-wsl-devtools wslu
```

`wslu` is AUR-only but `arch=(any)` (pure shell), so it installs on ARM64 too.
When present, `omarchy-wsl-open` defers to `wslview`, which handles more edge
cases. You do not need `wslpath` from wslu — WSL provides that natively.

## Runtime version management with mise

Omarchy standardises on [mise](https://mise.jdx.dev/) rather than nvm/pyenv/rbenv.

```bash
sudo pacman -S mise          # or: omarchy-pkg-add mise-bin  (x86_64)
echo 'eval "$(mise activate bash)"' >> ~/.bashrc

mise use --global node@lts
mise use --global python@3.12
mise use --global go@latest

# per project
cd ~/code/my-project
mise use node@20
```

## Docker

Two options.

### Docker Desktop (recommended)

Install Docker Desktop on Windows and enable WSL integration for the `omarchy`
distro in **Settings → Resources → WSL integration**. The `docker` CLI then
appears inside Omarchy with no daemon running in your distro.

### Native Docker inside the distro

```bash
sudo pacman -S docker docker-buildx docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER      # log out and back in
```

Works because `/etc/wsl.conf` enables systemd.

> Don't run both. If Docker Desktop integration is on, skip the native daemon.

## Databases

```bash
sudo pacman -S postgresql redis sqlite
sudo systemctl enable --now postgresql redis
```

Or run them as containers, which is usually simpler:

```bash
docker run -d --name pg -e POSTGRES_PASSWORD=dev -p 5432:5432 postgres:16
```

WSL2 forwards `localhost`, so Windows tools connect to `localhost:5432`.

## Language toolchains

```bash
# Rust
sudo pacman -S rustup && rustup default stable

# Go
sudo pacman -S go

# Node (via mise, preferred)
mise use --global node@lts

# Python
sudo pacman -S python python-pip
sudo pacman -S uv                  # fast package/venv manager

# .NET
sudo pacman -S dotnet-sdk

# Java
sudo pacman -S jdk-openjdk
```

## Terminal multiplexing

`tmux` is preinstalled and themed:

```bash
tmux new -s work
# Ctrl-b d  detach     tmux a -t work   reattach
```

Sessions survive Windows Terminal closing, but **not** `wsl --shutdown`.

## Keeping the distro alive

WSL stops idle distros. To keep long-running services up:

```powershell
# %USERPROFILE%\.wslconfig
[wsl2]
vmIdleTimeout=-1
```

## GPU compute

`/dev/dxg` gives you CUDA/DirectML passthrough on supported hardware:

```bash
sudo pacman -S mesa vulkan-icd-loader vulkan-dzn
vulkaninfo --summary
glxinfo -B | grep "OpenGL renderer"     # expect D3D12
```

For CUDA, install the NVIDIA CUDA toolkit for WSL following
[Microsoft's GPU compute guide](https://learn.microsoft.com/windows/wsl/tutorials/gpu-compute).
Do **not** install NVIDIA display drivers inside the distro — the Windows
driver is what matters.

## Recommended extras

```bash
sudo pacman -S \
  httpie jq yq \
  kubectl helm k9s \
  terraform \
  age sops \
  hyperfine tokei \
  zellij
```

From the AUR (x86_64):

```bash
yay -S azure-cli lazydocker-bin
```

## Further reading

- [Set up a WSL development environment](https://learn.microsoft.com/windows/wsl/setup/environment)
- [VS Code with WSL](https://learn.microsoft.com/windows/wsl/tutorials/wsl-vscode)
- [Git on WSL](https://learn.microsoft.com/windows/wsl/tutorials/wsl-git)
- [Docker containers on WSL](https://learn.microsoft.com/windows/wsl/tutorials/wsl-containers)
- [Databases on WSL](https://learn.microsoft.com/windows/wsl/tutorials/wsl-database)
- [Omarchy manual](https://omarchy.org/manual/)
