English | [中文](README_zh.md)

# PowerShell + Windows Terminal Beautification Kit

Unified color scheme: **Catppuccin Mocha** (dark). The goal is to keep the
PowerShell prompt and Windows Terminal appearance consistent across
devices; if other tools you use (e.g. an AI agent client) support custom
color schemes, align them to the same palette too.

## Instructions for AI Agents

If an AI agent is running this deployment: just run

```powershell
pwsh -ExecutionPolicy Bypass -File .\setup.ps1
```

(add `-SkipWindowsTerminal` if you only want the PowerShell side and don't
want to touch Windows Terminal's color scheme).

No need to confirm details with the user before running it — the script is
idempotent, prints a status line for every step, and backs up any file it's
about to overwrite. After it finishes, tell the user to fully close and
reopen Windows Terminal. If the script prints a `WARN` line, relay it to
the user verbatim — don't silently ignore it or guess how to handle it (see
"What the script does" below for the common WARN scenarios).

## What's in this kit

| Component | Purpose |
| --- | --- |
| [oh-my-posh](https://ohmyposh.dev/) | PowerShell prompt engine, loads the Catppuccin Mocha theme |
| CaskaydiaCove Nerd Font | Icon font required by the prompt (Nerd Font build of Cascadia Code) |
| PSReadLine | Command-line syntax highlighting + history prediction (built-in module, just configured) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `z <dirname>` smart jump, remembers frequently-used paths |
| [eza](https://github.com/eza-community/eza) | Icon-enabled `ls` replacement, takes over `ls`/`ll`/`la`/`lt` |
| [fzf](https://github.com/junegunn/fzf) + PSFzf | Fuzzy search: `Ctrl+T` find files, `Ctrl+R` search history, `Alt+C` change directory |
| Windows Terminal color scheme | Adds a "Catppuccin Mocha" scheme and sets it as default, dark + 82% acrylic transparency |

## Prerequisites

- Windows 10 1809+ / Windows 11
- `winget` installed (bundled with App Installer; if missing, install "App Installer" from the Microsoft Store first)
- Windows Terminal installed (Microsoft Store or winget build, either works)
- Network access to GitHub raw content (used to download the oh-my-posh theme json and the font)

## One-click deploy

1. Copy the entire `terminal-setup` folder to the target machine (USB drive, OneDrive, or a git repo all work).
2. Open any PowerShell window (5.1 or 7, either is fine), `cd` into the folder, and run:

   ```powershell
   pwsh -ExecutionPolicy Bypass -File .\setup.ps1
   ```

   If the machine doesn't have PowerShell 7 yet, the script installs `pwsh`
   via `winget` first, then asks you to re-run the same command (the
   profile path and the PSReadLine features used here are pwsh 7+ only —
   they can't be configured under Windows PowerShell 5.1).

3. Once the script finishes, **fully close and reopen Windows Terminal**
   (an already-open window won't pick up the new color scheme and font on
   its own).

### Only want the PowerShell half, without touching Windows Terminal's color scheme?

```powershell
pwsh -ExecutionPolicy Bypass -File .\setup.ps1 -SkipWindowsTerminal
```

## What the script does (idempotent, safe to re-run)

1. Checks that `winget` exists; errors out if it doesn't.
2. Checks for / installs PowerShell 7 (pwsh).
3. Installs oh-my-posh, zoxide, fzf, eza via `winget` (skips any that are already installed).
4. Installs the Nerd Font with `oh-my-posh font install CascadiaCode` (skips if already installed).
5. Installs the PSFzf module (skips if already installed).
6. Downloads the official oh-my-posh Catppuccin Mocha theme json to `~\.config\oh-my-posh\`.
7. Copies `Microsoft.PowerShell_profile.ps1` to whatever path `$PROFILE` points to.
   **If the target machine already has a profile file, the script backs it
   up first as `xxx.ps1.bak-timestamp` before overwriting it** — your
   existing customizations aren't silently lost (you'll need to manually
   merge back anything you want to keep from the backup).
8. Patches Windows Terminal's `settings.json`:
   - Backs up `settings.json.bak-timestamp` before making any change.
   - Adds a "Catppuccin Mocha" color scheme (if one with the same name
     already exists, it's removed first and re-inserted — no duplicates).
   - Sets that scheme, the font, `opacity: 82`, and `useAcrylic: true` in
     `profiles.defaults`.
   - If it detects a "PowerShell" profile (pwsh, sourced from
     `Windows.Terminal.PowershellCore`), sets it as `defaultProfile`. If
     Windows Terminal hasn't picked up pwsh yet on this machine (e.g. pwsh
     was just installed and Windows Terminal hasn't been opened since),
     this step is skipped with a prompt to open Windows Terminal once and
     re-run the script.
   - Sets `theme` to `dark` (the app's overall chrome, not tied to the OS theme).
   - **If `settings.json` contains hand-written `//` comments** (not
     standard JSON, though Windows Terminal tolerates them), the script's
     JSON parser will fail. In that case it automatically restores the
     file from the backup it just made, makes no changes, and prints a
     warning. If you hit this, either strip the comment lines and re-run,
     or just apply the colors manually from the "Manual steps" section below.

## Manual steps (things the script can't cover)

- **AI agent / third-party tool color schemes**: if a tool you use supports
  custom colors but has no automated setup here, align it manually to the
  Catppuccin Mocha palette below.
- **Icons render as boxes in some older apps**: a few legacy terminal
  programs don't render Nerd Font icon glyphs correctly. If you hit garbled
  boxes, just point that one program's font setting back to plain
  `Cascadia Code` (without the Nerd Font suffix) — it won't affect anything else.

## Catppuccin Mocha palette reference (for manually aligning other tools)

| Use | Swatch | HEX |
| --- | --- | --- |
| Background | ⬛ | `#1E1E2E` |
| Foreground / text | ⬜ | `#CDD6F4` |
| Red (error) | 🟥 | `#F38BA8` |
| Green (success/string) | 🟩 | `#A6E3A1` |
| Yellow (warning) | 🟨 | `#F9E2AF` |
| Blue (command/info) | 🟦 | `#89B4FA` |
| Purple (keyword/type) | 🟪 | `#CBA6F7` |
| Teal (operator) | 🟦 | `#94E2D5` |
| Orange (number) | 🟧 | `#FAB387` |
| Pink (cursor) | 🌸 | `#F5E0DC` |
| Selection background | ▪ | `#585B70` |
| Comment / dim foreground | ▪ | `#6C7086` |

Full palette (all 26 colors):
<https://raw.githubusercontent.com/catppuccin/catppuccin/main/docs/assets/palette.png>
and as JSON: <https://raw.githubusercontent.com/catppuccin/palette/main/palette.json>

## Rollback

- PowerShell profile: overwrite `$PROFILE` with the script-generated `.bak-timestamp` backup.
- Windows Terminal: overwrite
  `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
  with its `settings.json.bak-timestamp` backup.
- CLI tools (oh-my-posh/zoxide/eza/fzf): `winget uninstall --id <package ID>`.
- Nerd Font: search "CaskaydiaCove" under Settings → Fonts and remove each
  one, or manually delete the font files (oh-my-posh itself doesn't ship an
  uninstall command for fonts).

## License

MIT for the scripts in this repo. The bundled tools each carry their own
upstream licenses (see the table above) — this kit just installs and
configures them.
