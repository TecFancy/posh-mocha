#!/usr/bin/env bash
#
# One-click setup for bash + Catppuccin Mocha terminal beautification on
# Debian/Ubuntu servers (oh-my-posh, zoxide, eza, fzf).
#
# Mirror of setup.ps1 (the Windows/PowerShell version) — same theme, same
# step order (CLI tools -> theme file -> shell profile). Keep the two in
# sync when editing either one.
#
# Idempotent — safe to re-run. Backs up ~/.bashrc before touching it.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/TecFancy/posh-mocha/main/setup-linux.sh | bash
#   # or, copy the file over first and run: bash setup-linux.sh

set -uo pipefail

step() { printf '\033[36m==> %s\033[0m\n' "$1"; }
ok()   { printf '\033[32m    OK: %s\033[0m\n' "$1"; }
skip() { printf '\033[33m    SKIP: %s\033[0m\n' "$1"; }
warn() { printf '\033[33m    WARN: %s\033[0m\n' "$1"; }

# --- 0. apt must exist ---
if ! command -v apt-get >/dev/null 2>&1; then
    echo "apt-get not found — this script only supports Debian/Ubuntu." >&2
    exit 1
fi

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

# --- 1. CLI tools via apt ---
step "CLI tools: zoxide, eza, fzf"
$SUDO apt-get update -qq
if $SUDO apt-get install -y zoxide eza fzf >/tmp/posh-mocha-apt.log 2>&1; then
    ok "zoxide, eza, fzf installed"
else
    warn "apt-get install failed, see /tmp/posh-mocha-apt.log — install zoxide/eza/fzf manually and re-run."
fi

# --- 2. oh-my-posh (binary + Catppuccin Mocha theme pack) ---
export PATH="$PATH:$HOME/.local/bin"
THEME_DIR=""
THEME_FILE=""
if command -v oh-my-posh >/dev/null 2>&1; then
    THEME_DIR="$(oh-my-posh cache path 2>/dev/null)/themes"
    THEME_FILE="$THEME_DIR/catppuccin_mocha.omp.json"
fi

if [ -n "$THEME_FILE" ] && [ -f "$THEME_FILE" ]; then
    ok "oh-my-posh + Catppuccin Mocha theme already installed"
else
    step "oh-my-posh (binary + Catppuccin Mocha theme pack)"
    # Installer pulls the binary and the theme pack from cdn.ohmyposh.dev,
    # not GitHub — see setup.ps1's theme step for why that matters.
    if curl -fsSL --max-time 15 https://ohmyposh.dev/install.sh -o /tmp/install-omp.sh 2>/tmp/posh-mocha-omp-curl.log \
        && bash /tmp/install-omp.sh >/tmp/posh-mocha-omp-install.log 2>&1; then
        export PATH="$PATH:$HOME/.local/bin"
        THEME_DIR="$(oh-my-posh cache path 2>/dev/null)/themes"
        THEME_FILE="$THEME_DIR/catppuccin_mocha.omp.json"
        ok "oh-my-posh installed, theme saved to $THEME_FILE"
    else
        warn "Could not install oh-my-posh (see /tmp/posh-mocha-omp-curl.log, /tmp/posh-mocha-omp-install.log)."
        warn "Retry later with: curl -s https://ohmyposh.dev/install.sh | bash"
    fi
    rm -f /tmp/install-omp.sh
fi

# --- 3. bash profile (~/.bashrc) ---
step "bash profile (~/.bashrc)"
BASHRC="$HOME/.bashrc"
BEGIN_MARK='# --- posh-mocha: Catppuccin Mocha terminal beautification (BEGIN) ---'
END_MARK='# --- posh-mocha: Catppuccin Mocha terminal beautification (END) ---'

if [ -f "$BASHRC" ]; then
    BACKUP="$BASHRC.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$BASHRC" "$BACKUP"
    if grep -qF "$BEGIN_MARK" "$BASHRC"; then
        awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
            $0==b {skip=1}
            !skip {print}
            $0==e {skip=0}
        ' "$BASHRC" > "$BASHRC.tmp" && mv "$BASHRC.tmp" "$BASHRC"
        warn "Existing posh-mocha block replaced (backup: $BACKUP)"
    else
        warn "Existing profile backed up to $BACKUP"
    fi
else
    : > "$BASHRC"
fi

# Trim trailing blank lines so re-runs don't accumulate blank space at the end
awk '{ lines[NR] = $0 } END {
    last = NR
    while (last > 0 && lines[last] == "") last--
    for (i = 1; i <= last; i++) print lines[i]
}' "$BASHRC" > "$BASHRC.tmp" && mv "$BASHRC.tmp" "$BASHRC"

FZF_KEYBINDINGS=""
for candidate in /usr/share/doc/fzf/examples/key-bindings.bash /usr/share/fzf/key-bindings.bash; do
    if [ -f "$candidate" ]; then
        FZF_KEYBINDINGS="$candidate"
        break
    fi
done
[ -z "$FZF_KEYBINDINGS" ] && warn "fzf key-bindings.bash not found — Ctrl+T/Ctrl+R won't be wired up, only Tab-completion."

{
    echo ""
    echo "$BEGIN_MARK"
    echo 'export PATH="$PATH:$HOME/.local/bin"'
    echo ""
    echo "# oh-my-posh (Catppuccin Mocha)"
    if [ -n "$THEME_FILE" ]; then
        echo "eval \"\$(oh-my-posh init bash --config $THEME_FILE)\""
    else
        echo "# WARN: theme file missing at setup time — re-run setup-linux.sh once oh-my-posh installs cleanly."
    fi
    echo ""
    echo "# zoxide (smarter cd, \"z <dir>\")"
    echo 'eval "$(zoxide init bash)"'
    echo ""
    echo "# fzf (fuzzy find: Ctrl+T files, Ctrl+R history, Alt+C cd)"
    if [ -n "$FZF_KEYBINDINGS" ]; then
        echo "[ -f $FZF_KEYBINDINGS ] && source $FZF_KEYBINDINGS"
    fi
    echo ""
    echo "# eza (modern ls replacement, icons)"
    echo 'if command -v eza >/dev/null 2>&1; then'
    echo '  alias ls="eza --icons --group-directories-first"'
    echo '  alias ll="eza --icons --group-directories-first -l"'
    echo '  alias la="eza --icons --group-directories-first -la"'
    echo '  alias lt="eza --icons --group-directories-first --tree"'
    echo 'fi'
    echo "$END_MARK"
} >> "$BASHRC"
ok "Profile written"

step 'Done'
echo "Open a new shell (or run 'exec bash') to see the new prompt."
echo "This only covers the remote/server side — the Nerd Font and terminal emulator settings still come from setup.ps1 on the client you connect from."
