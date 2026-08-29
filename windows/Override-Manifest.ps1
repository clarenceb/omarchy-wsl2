<#
.SYNOPSIS
    Publish a locally built omarchy-wsl2 image in `wsl --list --online`.

.DESCRIPTION
    WSL discovers installable distributions through a manifest URL. This script
    writes a local manifest and points the machine at it via:

        HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss\DistributionListUrl

    After running this, `wsl --list --online` shows your image and it can be
    installed with `wsl --install omarchy`.

    Requires WSL >= 2.4.4 (for the file:// protocol) and an elevated prompt.

.PARAMETER WslPath
    Path to the built .wsl file.

.PARAMETER Flavor
    Flavor name used by `wsl --install <flavor>`. Default: omarchy

.PARAMETER Version
    Version name used by `wsl --install <version>`. Default: omarchy-wsl2

.PARAMETER FriendlyName
    Name shown in `wsl --list --online`.

.PARAMETER Append
    Add to the official list instead of replacing it (uses
    DistributionListUrlAppend).

.PARAMETER Revert
    Remove the override and restore the official distribution list.

.EXAMPLE
    .\Override-Manifest.ps1 -WslPath C:\wsl\omarchy-wsl2\dist\omarchy-desktop-x86_64.wsl

.EXAMPLE
    .\Override-Manifest.ps1 -Revert
#>

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$WslPath,
    [string]$Flavor = 'omarchy',
    [string]$Version = 'omarchy-wsl2',
    [string]$FriendlyName = 'Omarchy (WSL2)',
    [switch]$Append,
    [switch]$Revert
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LxssKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss'

if ($Revert) {
    foreach ($name in 'DistributionListUrl', 'DistributionListUrlAppend') {
        if (Get-ItemProperty -Path $LxssKey -Name $name -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $LxssKey -Name $name -Force
            Write-Host "Removed $name" -ForegroundColor Yellow
        }
    }
    Write-Host 'Reverted to the official distribution list.' -ForegroundColor Green
    return
}

if (-not $WslPath) {
    throw 'WslPath is required (or pass -Revert).'
}

$resolved = (Resolve-Path -LiteralPath $WslPath).Path
if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
    throw "Not a file: $resolved"
}

Write-Host "Hashing $([System.IO.Path]::GetFileName($resolved))..." -ForegroundColor Cyan
$hash = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash

# WSL matches the manifest entry against the host architecture.
$arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    'ARM64' { 'Arm64Url' }
    default { 'Amd64Url' }
}

$entry = [ordered]@{
    Name         = $Version
    Default      = $true
    FriendlyName = $FriendlyName
}
$entry[$arch] = [ordered]@{
    Url    = "file://$resolved"
    Sha256 = "0x$hash"
}

$manifest = [ordered]@{
    ModernDistributions = [ordered]@{
        $Flavor = @($entry)
    }
}

$manifestPath = Join-Path $PSScriptRoot 'omarchy-manifest.json'
$manifest | ConvertTo-Json -Depth 6 | Out-File -Encoding ascii -LiteralPath $manifestPath

$valueName = if ($Append) { 'DistributionListUrlAppend' } else { 'DistributionListUrl' }
Set-ItemProperty -Path $LxssKey -Name $valueName -Value "file://$manifestPath" -Type String -Force

Write-Host ''
Write-Host "Manifest written to $manifestPath"      -ForegroundColor Green
Write-Host "Registry value  : $valueName"           -ForegroundColor Green
Write-Host "Architecture    : $arch"                -ForegroundColor Green
Write-Host ''
Write-Host 'Now run:' -ForegroundColor Cyan
Write-Host "  wsl --list --online"
Write-Host "  wsl --install $Flavor"
Write-Host ''
Write-Host 'Undo with: .\Override-Manifest.ps1 -Revert' -ForegroundColor DarkGray
