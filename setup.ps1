<#
.SYNOPSIS
    One-click setup for PowerShell + Windows Terminal beautification
    (oh-my-posh Catppuccin Mocha theme, PSReadLine, zoxide, eza, fzf,
    Nerd Font, Windows Terminal Catppuccin Mocha + acrylic transparency).

.DESCRIPTION
    Idempotent — safe to re-run. Backs up any file it overwrites before
    touching it (PowerShell profile, Windows Terminal settings.json).

.PARAMETER SkipWindowsTerminal
    Skip patching Windows Terminal's settings.json. Use this if you only
    want the PowerShell-side setup (profile, prompt, CLI tools).

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File .\setup.ps1
#>

[CmdletBinding()]
param(
    [switch]$SkipWindowsTerminal
)

$ErrorActionPreference = 'Stop'

function Write-Step  ($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok    ($msg) { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Skip  ($msg) { Write-Host "    SKIP: $msg" -ForegroundColor Yellow }
function Write-Warn2 ($msg) { Write-Host "    WARN: $msg" -ForegroundColor DarkYellow }

# --- 0. winget must exist ---
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install 'App Installer' from the Microsoft Store first, then re-run."
}

# --- 1. Make sure we're running on PowerShell 7+ (pwsh) ---
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Step "Installing PowerShell 7 (pwsh)"
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        Write-Ok "pwsh already installed"
    } else {
        winget install -e --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements --silent
    }
    Write-Warn2 "This script must finish running under PowerShell 7 (the profile path and PSReadLine features differ from Windows PowerShell 5.1)."
    Write-Host "Re-run with:  pwsh -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -ForegroundColor Magenta
    exit 0
}

# --- 2. CLI tools via winget ---
$packages = @(
    @{ Id = 'JanDeDobbeleer.OhMyPosh'; Cmd = 'oh-my-posh' },
    @{ Id = 'ajeetdsouza.zoxide';      Cmd = 'zoxide' },
    @{ Id = 'junegunn.fzf';            Cmd = 'fzf' },
    @{ Id = 'eza-community.eza';       Cmd = 'eza' }
)
foreach ($p in $packages) {
    Write-Step "oh-my-posh / CLI tool: $($p.Id)"
    if (Get-Command $p.Cmd -ErrorAction SilentlyContinue) {
        Write-Ok "$($p.Cmd) already installed"
        continue
    }
    winget install -e --id $p.Id --accept-package-agreements --accept-source-agreements --silent
    Write-Ok "$($p.Cmd) installed"
}

# Refresh PATH for this session so freshly-installed commands are visible
$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'User') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path', 'Machine')

# --- 3. Nerd Font (CaskaydiaCove) ---
Write-Step "Nerd Font (CaskaydiaCove)"
$fontAlreadyThere = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue |
    ForEach-Object { $_.PSObject.Properties.Name } |
    Where-Object { $_ -like 'CaskaydiaCove*' }
if ($fontAlreadyThere) {
    Write-Ok "CaskaydiaCove Nerd Font already installed"
} else {
    oh-my-posh font install CascadiaCode
    Write-Ok "Font installed"
}

# --- 4. PSFzf module (fzf <-> PSReadLine integration) ---
Write-Step "PSFzf module"
if (Get-Module -ListAvailable PSFzf) {
    Write-Ok "PSFzf already installed"
} else {
    Install-Module -Name PSFzf -Scope CurrentUser -Force -AllowClobber
    Write-Ok "PSFzf installed"
}

# --- 5. oh-my-posh Catppuccin Mocha theme file ---
Write-Step "Catppuccin Mocha oh-my-posh theme"
$configDir = "$HOME\.config\oh-my-posh"
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
$themeFile = Join-Path $configDir 'catppuccin_mocha.omp.json'
if (Test-Path $themeFile) {
    Write-Ok "Theme already present at $themeFile"
} else {
    # Fetched from cdn.ohmyposh.dev (same CDN used by `oh-my-posh font install`)
    # instead of raw.githubusercontent.com, since GitHub itself is often
    # unreachable/times out from some networks while this CDN stays up.
    $zipPath = Join-Path $env:TEMP 'oh-my-posh-themes.zip'
    $tempDir = Join-Path $env:TEMP "oh-my-posh-themes-$([guid]::NewGuid())"
    try {
        Invoke-WebRequest -Uri 'https://cdn.ohmyposh.dev/releases/latest/themes.zip' `
            -OutFile $zipPath -UseBasicParsing -TimeoutSec 15
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        Copy-Item -Path (Join-Path $tempDir 'catppuccin_mocha.omp.json') -Destination $themeFile -Force
        Write-Ok "Theme saved to $themeFile"
    } catch {
        Write-Warn2 "Could not download the theme from cdn.ohmyposh.dev ($($_.Exception.Message))."
        Write-Warn2 "Save it manually as $themeFile — download the theme pack from https://ohmyposh.dev/docs/themes, or copy catppuccin_mocha.omp.json out of an existing oh-my-posh install's theme cache (run 'oh-my-posh cache path' to find it)\themes."
    } finally {
        Remove-Item -Path $zipPath, $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- 6. PowerShell profile ---
Write-Step "PowerShell profile ($PROFILE)"
$profileDir = Split-Path $PROFILE
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
if (Test-Path $PROFILE) {
    $backup = "$PROFILE.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $PROFILE $backup
    Write-Warn2 "Existing profile backed up to $backup"
}
Copy-Item -Path (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') -Destination $PROFILE -Force
Write-Ok "Profile written"

# --- 7. Windows Terminal: Catppuccin Mocha scheme + acrylic + Nerd Font ---
if ($SkipWindowsTerminal) {
    Write-Skip "Windows Terminal patch (-SkipWindowsTerminal)"
} else {
    Write-Step "Windows Terminal settings.json"
    $candidatePaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $wtSettingsPath = $candidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $wtSettingsPath) {
        Write-Warn2 "Windows Terminal settings.json not found. Install Windows Terminal first, then re-run with the same command (or add -SkipWindowsTerminal to skip)."
    } else {
        try {
            $backup = "$wtSettingsPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $wtSettingsPath $backup
            $json = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json -Depth 100

            $schemeName = 'Catppuccin Mocha'
            $scheme = [ordered]@{
                name                = $schemeName
                background          = '#1E1E2E'
                foreground          = '#CDD6F4'
                black               = '#45475A'
                blue                = '#89B4FA'
                cyan                = '#94E2D5'
                green               = '#A6E3A1'
                purple              = '#F5C2E7'
                red                 = '#F38BA8'
                white               = '#BAC2DE'
                yellow              = '#F9E2AF'
                brightBlack         = '#585B70'
                brightBlue          = '#89B4FA'
                brightCyan          = '#94E2D5'
                brightGreen         = '#A6E3A1'
                brightPurple        = '#F5C2E7'
                brightRed           = '#F38BA8'
                brightWhite         = '#A6ADC8'
                brightYellow        = '#F9E2AF'
                cursorColor         = '#F5E0DC'
                selectionBackground = '#585B70'
            }
            $existingSchemes = @($json.schemes | Where-Object { $_.name -ne $schemeName })
            $json.schemes = @($existingSchemes) + [pscustomobject]$scheme

            if (-not $json.profiles.defaults) {
                $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force
            }
            $json.profiles.defaults | Add-Member -NotePropertyName colorScheme -NotePropertyValue $schemeName -Force
            $json.profiles.defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{ face = 'CaskaydiaCove Nerd Font Mono' }) -Force
            $json.profiles.defaults | Add-Member -NotePropertyName opacity -NotePropertyValue 82 -Force
            $json.profiles.defaults | Add-Member -NotePropertyName useAcrylic -NotePropertyValue $true -Force

            $pwshProfile = $json.profiles.list | Where-Object { $_.source -eq 'Windows.Terminal.PowershellCore' } | Select-Object -First 1
            if ($pwshProfile) {
                $json.defaultProfile = $pwshProfile.guid
            } else {
                Write-Warn2 "No 'Windows.Terminal.PowershellCore' profile found yet — defaultProfile left untouched. Open Windows Terminal once after installing pwsh so it detects the profile, then re-run this script."
            }

            $json.theme = 'dark'

            ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $wtSettingsPath -Encoding utf8
            Write-Ok "Windows Terminal settings patched (backup: $backup)"
        } catch {
            Write-Warn2 "Could not patch settings.json automatically ($($_.Exception.Message))."
            Write-Warn2 "This usually means the file has // comments (not standard JSON) or a manual edit broke it. Restored from backup: $backup"
            Copy-Item $backup $wtSettingsPath -Force
        }
    }
}

Write-Step 'Done'
Write-Host 'Fully close and reopen Windows Terminal to see the new theme, font and transparency.' -ForegroundColor Magenta
