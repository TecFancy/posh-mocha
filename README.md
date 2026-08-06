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
| [Maple Mono NF CN](https://github.com/subframe7536/maple-font) | Monospace font with prompt icons + Chinese glyphs (see "Fonts and Chinese text" below); falls back to Latin-only CaskaydiaCove Nerd Font without admin rights |
| PSReadLine | Command-line syntax highlighting + history prediction (built-in module, just configured) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `z <dirname>` smart jump, remembers frequently-used paths |
| [eza](https://github.com/eza-community/eza) | Icon-enabled `ls` replacement, takes over `ls`/`ll`/`la`/`lt` |
| [fzf](https://github.com/junegunn/fzf) + PSFzf | Fuzzy search: `Ctrl+T` find files, `Ctrl+R` search history, `Alt+C` change directory |
| Windows Terminal color scheme | Adds a "Catppuccin Mocha" scheme and sets it as default, dark + 82% acrylic transparency |

## Prerequisites

- Windows 10 1809+ / Windows 11
- `winget` installed (bundled with App Installer; if missing, install "App Installer" from the Microsoft Store first)
- Windows Terminal installed (Microsoft Store or winget build, either works)
- Network access to `cdn.ohmyposh.dev` (theme download), `github.com` (Chinese Nerd Font download), and whatever sources `winget` is configured to use
- For Chinese text to render correctly, open PowerShell **as Administrator**
  before running the script (see "Fonts and Chinese text" below). It still
  runs fine without admin rights — the font just falls back to a
  Latin-only build.

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

## Remote servers (Linux / bash)

For Debian/Ubuntu servers you SSH into — there's no Windows Terminal side
to patch there, but the *client* terminal you're connecting from still
needs the Nerd Font, which `setup.ps1` installs locally:

```bash
curl -fsSL https://raw.githubusercontent.com/TecFancy/posh-mocha/master/setup-linux.sh | bash
```

If the server can't reach `raw.githubusercontent.com`, copy the file over
first instead (e.g. `scp setup-linux.sh myserver:/tmp/`) and run
`bash setup-linux.sh`.

It installs oh-my-posh (same Catppuccin Mocha theme, fetched from
`cdn.ohmyposh.dev` rather than GitHub), zoxide, eza and fzf via `apt`, and
wires them into `~/.bashrc` inside a marked block. Idempotent — backs up
`~/.bashrc` before touching it, and replaces (rather than duplicates) its
own block on every re-run. See `setup-linux.sh`'s header comment for
details; it mirrors `setup.ps1`'s step order.

## What the script does (idempotent, safe to re-run)

1. Checks that `winget` exists; errors out if it doesn't.
2. Checks for / installs PowerShell 7 (pwsh).
3. Installs oh-my-posh, zoxide, fzf, eza via `winget` (skips any that are already installed).
4. Installs the font (skips if already installed):
   - **Elevated**: downloads `Maple Mono NF CN` from GitHub, installs it
     system-wide (`C:\Windows\Fonts` + `HKLM` registration), restarts the
     font cache service, and broadcasts a font-change notification so
     every app in the current session — including packaged apps like
     Windows Terminal — picks it up immediately.
   - **Not elevated**: falls back to `oh-my-posh font install CascadiaCode`
     (Latin-only Nerd Font) and prints a WARN that Chinese text will look
     mismatched.
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

## Fonts and Chinese text

**Root cause**: plain Nerd Fonts like CaskaydiaCove ship zero Chinese
glyphs, so Windows silently falls back to a different system CJK font for
Chinese text — mismatched weight/width against the Latin glyphs, which also
throws off oh-my-posh's segment alignment. `Maple Mono NF CN` merges Nerd
Font icons and width-matched Chinese glyphs into one family, fixing this at
the root.

**Font installed but Windows Terminal still says "font not found"**:
Windows Terminal is a packaged (MSIX/AppContainer) app — it can only see
fonts installed system-wide (`C:\Windows\Fonts` + `HKLM` registration), not
a per-user-only ("install for me") font, even if the file is genuinely on
disk and `AddFontResourceEx` already loaded it into the current session.
That's why the font step in `setup.ps1` needs admin rights to take the
system-wide path — without it, the script falls back to the Latin-only
CaskaydiaCove Nerd Font and prints a WARN.

If Windows Terminal still complains after a system-wide install: fully
close every Windows Terminal window and reopen. If that doesn't help,
restart the Windows Font Cache service (`Restart-Service FontCache` — the
script already does this automatically) or sign out and back in to force a
full refresh.

**Chinese text also looks wrong over SSH into a Linux server?** That's
unrelated to `setup-linux.sh` — font rendering happens entirely on the
*client* side (your local Windows Terminal), whether you're in a local
PowerShell tab or SSH'd into a remote box. Running `setup.ps1` once
(elevated) fixes both the local and remote case; `setup-linux.sh` needs no
changes.

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

Full palette (all 26 colors): <https://catppuccin.com/palette/>
and as JSON: <https://raw.githubusercontent.com/catppuccin/palette/main/palette.json>

## Rollback

- PowerShell profile: overwrite `$PROFILE` with the script-generated `.bak-timestamp` backup.
- Windows Terminal: overwrite
  `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
  with its `settings.json.bak-timestamp` backup.
- CLI tools (oh-my-posh/zoxide/eza/fzf): `winget uninstall --id <package ID>`.
- Nerd Font: `Maple Mono NF CN` was installed system-wide — search
  "Maple Mono NF CN" under Settings → Fonts and remove it there (this also
  cleans up the `HKLM` registration and the files under
  `C:\Windows\Fonts`). The fallback `CaskaydiaCove` build is a per-user
  install — same removal path under Settings → Fonts (oh-my-posh itself
  doesn't ship an uninstall command).
- `setup-linux.sh` (remote servers): overwrite `~/.bashrc` with its
  `.bak-timestamp` backup, then `sudo apt remove zoxide eza fzf` and
  `rm ~/.local/bin/oh-my-posh`.

## License

MIT for the scripts in this repo. The bundled tools each carry their own
upstream licenses (see the table above) — this kit just installs and
configures them.
