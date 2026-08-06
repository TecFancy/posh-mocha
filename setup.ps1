<#
.SYNOPSIS
    One-click setup for PowerShell + Windows Terminal beautification
    (oh-my-posh Catppuccin Mocha theme, PSReadLine, zoxide, eza, fzf,
    a CJK-capable Nerd Font, Windows Terminal Catppuccin Mocha + acrylic
    transparency).

.DESCRIPTION
    Idempotent — safe to re-run. Backs up any file it overwrites before
    touching it (PowerShell profile, Windows Terminal settings.json).

    Mirror of setup-linux.sh (the bash/Debian-Ubuntu version for remote
    servers) — same theme, same step order. Keep the two in sync when
    editing either one.

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

# --- 3. Nerd Font with CJK glyphs (Maple Mono NF CN) ---
Write-Step "Nerd Font (Maple Mono NF CN)"
# Plain Nerd Fonts like CaskaydiaCove ship zero Chinese glyphs, so Windows
# silently falls back to a different system CJK font for Chinese text —
# mismatched weight/width vs. the Latin glyphs, which breaks oh-my-posh's
# segment alignment. Maple Mono NF CN bundles Nerd Font icons AND
# width-matched CJK glyphs in one family, so Latin + Chinese render
# consistently. Source: https://github.com/subframe7536/maple-font
#
# Installed per-user (%LOCALAPPDATA%\Microsoft\Windows\Fonts + HKCU
# registration), same mechanism `oh-my-posh font install` already uses for
# the fallback font below. No admin rights needed, and packaged apps like
# Windows Terminal pick it up immediately — unlike a system-wide install
# (C:\Windows\Fonts + HKLM), which on some machines only gets read into the
# session's font table at the *next* sign-out/reboot, and sometimes not
# even then, which made that path unreliable for a one-shot script.
Add-Type -AssemblyName System.Drawing
$targetFont = 'Maple Mono NF CN'
$fallbackFont = 'CaskaydiaCove NFM'
$installedFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name

if ($installedFamilies -contains $targetFont) {
    Write-Ok "$targetFont already installed"
    $PromptFont = $targetFont
} else {
    $zipPath = Join-Path $env:TEMP 'MapleMono-NF-CN.zip'
    $extractDir = Join-Path $env:TEMP "MapleMono-NF-CN-$([guid]::NewGuid())"
    try {
        Invoke-WebRequest -Uri 'https://github.com/subframe7536/maple-font/releases/latest/download/MapleMono-NF-CN.zip' `
            -OutFile $zipPath -UseBasicParsing -TimeoutSec 60
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

        Add-Type -MemberDefinition @'
[DllImport("gdi32.dll", CharSet=CharSet.Unicode)]
public static extern int AddFontResourceEx(string lpszFilename, uint fl, IntPtr pdv);
[DllImport("user32.dll", SetLastError=true)]
public static extern bool SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@ -Name Win32Font -Namespace PoshMocha -PassThru | Out-Null

        $userFontsDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
        New-Item -ItemType Directory -Path $userFontsDir -Force | Out-Null
        $regPath = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        Get-ChildItem -Path $extractDir -Recurse -Include *.ttf | ForEach-Object {
            $dest = Join-Path $userFontsDir $_.Name
            Copy-Item -Path $_.FullName -Destination $dest -Force

            $fc = New-Object System.Drawing.Text.PrivateFontCollection
            $fc.AddFontFile($dest)
            $familyName = $fc.Families[0].Name
            $fc.Dispose()

            # A family can span several files (Regular/Bold/Italic/...);
            # keep prior filenames for the same family name instead of
            # clobbering them. Per-user entries need the full path (a bare
            # filename resolves against C:\Windows\Fonts instead).
            $valueName = "$familyName (TrueType)"
            $existing = (Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue).$valueName
            $newValue = if ($existing -and $existing -notlike "*$dest*") { "$existing,$dest" } else { $dest }
            New-ItemProperty -Path $regPath -Name $valueName -Value $newValue -PropertyType String -Force | Out-Null

            [PoshMocha.Win32Font]::AddFontResourceEx($dest, 0, [IntPtr]::Zero) | Out-Null
        }

        $broadcastResult = [UIntPtr]::Zero
        [PoshMocha.Win32Font]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 5000, [ref]$broadcastResult) | Out-Null

        Write-Ok "$targetFont installed for current user"
        $PromptFont = $targetFont
    } catch {
        Write-Warn2 "Could not install $targetFont ($($_.Exception.Message)). Falling back to $fallbackFont."
        oh-my-posh font install CascadiaCode
        $PromptFont = $fallbackFont
    } finally {
        Remove-Item -Path $zipPath, $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
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
            $json.profiles.defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{ face = $PromptFont }) -Force
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
if ($PromptFont -eq $fallbackFont) {
    Write-Warn2 "Prompt font is $fallbackFont (Latin-only) — Chinese text will look mismatched. Check your network connection and re-run this script to try installing $targetFont again."
}
