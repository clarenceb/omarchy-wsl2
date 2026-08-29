<#
.SYNOPSIS
    Launch the omarchy-wsl2 wizard from Windows.

.DESCRIPTION
    The build itself runs inside an existing WSL2 distro - PowerShell is not
    required. This script is just a convenience launcher for people who'd
    rather start from Windows: it finds a suitable WSL distro and runs the
    bash wizard inside it.

.PARAMETER Distro
    The existing WSL2 distro to build from. Defaults to your WSL default.

.PARAMETER RepoPath
    Path to this repository as seen from inside that distro.
    Defaults to the translated location of this script.

.EXAMPLE
    .\windows\omarchy-wsl2.ps1

.EXAMPLE
    .\windows\omarchy-wsl2.ps1 -Distro Ubuntu
#>

[CmdletBinding()]
param(
    [string]$Distro,
    [string]$RepoPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Fail 'wsl.exe not found. Install WSL first:  wsl --install'
}

# wsl.exe emits UTF-16LE; normalise before parsing.
$prevEnc = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::Unicode
try {
    $distros = (wsl.exe --list --quiet) -split "`r?`n" |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_ -notmatch '^docker-desktop' }
}
finally {
    [Console]::OutputEncoding = $prevEnc
}

if (-not $distros) {
    Fail 'No WSL distros found. Install one first, e.g.:  wsl --install Ubuntu'
}

if (-not $Distro) {
    $Distro = $distros | Select-Object -First 1
    Write-Host "Using WSL distro: $Distro" -ForegroundColor Cyan
    Write-Host "(override with -Distro <name>; available: $($distros -join ', '))" -ForegroundColor DarkGray
}

if ($distros -notcontains $Distro) {
    Fail "Distro '$Distro' not found. Available: $($distros -join ', ')"
}

if (-not $RepoPath) {
    $winRepo = Split-Path -Parent $PSScriptRoot
    # Translate the Windows path into the distro's view of it.
    $RepoPath = (wsl.exe -d $Distro --cd / -- wslpath -u "$winRepo" 2>$null | Out-String).Trim()
    if (-not $RepoPath) { Fail "Could not translate '$winRepo' for distro '$Distro'." }
}

Write-Host "Repository path inside ${Distro}: $RepoPath" -ForegroundColor DarkGray
Write-Host ''

wsl.exe -d $Distro --cd "$RepoPath" -- bash ./omarchy-wsl2
exit $LASTEXITCODE
