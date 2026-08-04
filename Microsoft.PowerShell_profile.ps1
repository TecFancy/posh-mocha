# --- oh-my-posh (Catppuccin Mocha) ---
oh-my-posh init pwsh --config "$HOME\.config\oh-my-posh\catppuccin_mocha.omp.json" | Invoke-Expression

# --- PSReadLine: syntax highlighting + predictive IntelliSense ---
Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -Colors @{
    Command            = "#89b4fa"  # blue
    Parameter          = "#f9e2af"  # yellow
    Operator           = "#94e2d5"  # teal
    Variable           = "#f38ba8"  # red
    String             = "#a6e3a1"  # green
    Number             = "#fab387"  # peach
    Type               = "#cba6f7"  # mauve
    Comment            = "#6c7086"  # overlay0
    Keyword            = "#cba6f7"  # mauve
    Selection          = "#585b70"  # surface2
    InlinePrediction   = "#6c7086"  # overlay0
    Default            = "#cdd6f4"  # text
}
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# --- zoxide (smarter cd, "z <dir>") ---
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# --- fzf (fuzzy find: Ctrl+T files, Ctrl+R history, Alt+C cd) ---
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
Set-PsFzfOption -PSReadlineChordSetLocation 'Alt+c'

# --- eza (modern ls replacement, icons) ---
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -ErrorAction SilentlyContinue
    function ls  { eza --icons --group-directories-first @args }
    function ll  { eza --icons --group-directories-first -l @args }
    function la  { eza --icons --group-directories-first -la @args }
    function lt  { eza --icons --group-directories-first --tree @args }
}
