# Managed by repos/setup-macos-terminal — reload after edits with:  . $PROFILE
# PowerShell (pwsh) developer profile.
#
# SIBLING FILE: config/zsh/zshrc. The aliases, the eza icon handling and the
# kubectl/git shortcuts below are deliberate mirrors of it — change one, change
# the other. (Checked by nothing but your eyes; the two shells are too different
# to share a generated file.)

# ───────────────────────────── PATH ─────────────────────────────
$localBin = Join-Path $HOME '.local/bin'                  # Claude Code + user binaries
if ((Test-Path $localBin) -and ($env:PATH -notlike "*$localBin*")) {
  $env:PATH = "${localBin}:$env:PATH"
}

# Homebrew (Apple Silicon → /opt/homebrew, Intel → /usr/local)
foreach ($brewBin in '/opt/homebrew/bin/brew', '/usr/local/bin/brew') {
  if (Test-Path $brewBin) { (& $brewBin shellenv) | Invoke-Expression; break }
}

# ─────────────────────────── PSReadLine ─────────────────────────
# History-based autosuggestions (ghost text), better history search + keys.
# Syntax highlighting is built in. Mirrors zsh-autosuggestions/-syntax-highlighting.
if (Get-Module -ListAvailable -Name PSReadLine) {
  Import-Module PSReadLine
  Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView
  Set-PSReadLineOption -HistoryNoDuplicates -HistorySearchCursorMovesToEnd
  Set-PSReadLineOption -Colors @{ InlinePrediction = "$([char]0x1b)[90m" }  # dim ghost text (fg=8)
  Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
  Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
  Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
}

# ─────────────── Optional PSGallery modules (dev nicety) ─────────
# Installed by scripts/20-shell.sh; loaded only if present so the profile
# never errors on a fresh box.
if (Get-Module -ListAvailable -Name Terminal-Icons) { Import-Module Terminal-Icons }
if (Get-Module -ListAvailable -Name PSFzf) {
  Import-Module PSFzf
  # Ctrl-T files, Ctrl-R fuzzy history — mirrors zsh fzf key-bindings.
  Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
  $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
  $env:FZF_DEFAULT_OPTS    = '--height 40% --layout=reverse --border --info=inline'
}

# ──────────────────── Prompt + navigation ───────────────────────
if (Get-Command starship -ErrorAction SilentlyContinue) { Invoke-Expression (& starship init powershell) }
if (Get-Command zoxide   -ErrorAction SilentlyContinue) { Invoke-Expression (zoxide init powershell | Out-String) }
if (Get-Command mise     -ErrorAction SilentlyContinue) { Invoke-Expression (mise activate pwsh    | Out-String) }

# ──────────────────────────── Aliases ───────────────────────────
# Functions (not Set-Alias) because PowerShell aliases can't carry arguments.
if (Get-Command eza -ErrorAction SilentlyContinue) {
  # Same two traps as ~/.zshrc — keep the two files in step:
  #   1. The glyphs live in the terminal's *font*, not in eza. This profile is
  #      machine-wide, so only turn icons on where a Nerd Font is likely.
  #   2. eza's own `--icons=auto` renders NOTHING (0.23.x), and a bare `--icons`
  #      means exactly that auto — so always pass an explicit always/never.
  # Override per machine in profile.local.ps1:  $env:EZA_ICONS = 'always'
  if (-not $env:EZA_ICONS) {
    $env:EZA_ICONS = if ($env:TERM_PROGRAM -in 'WezTerm','iTerm.app','ghostty','kitty','Alacritty') { 'always' } else { 'never' }
  }
  # A function, not a fixed string: $env:EZA_ICONS and the redirection check are
  # evaluated per call, so a later profile.local.ps1 override still wins and
  # `ll > file` stays free of private-use glyphs.
  function Get-EzaIcons { if ([Console]::IsOutputRedirected) { 'never' } else { $env:EZA_ICONS } }
  function ls { eza "--icons=$(Get-EzaIcons)" --group-directories-first @args }
  function ll { eza "--icons=$(Get-EzaIcons)" -lah --git --group-directories-first @args }
  function la { eza "--icons=$(Get-EzaIcons)" -a @args }
  function lt { eza "--icons=$(Get-EzaIcons)" --tree --level=2 @args }
}
if (Get-Command bat -ErrorAction SilentlyContinue) {
  function cat { bat --paging=never @args }
  $env:BAT_THEME = 'ansi'
}
if (Get-Command lazygit -ErrorAction SilentlyContinue) { function lg  { lazygit @args } }
if (Get-Command btop    -ErrorAction SilentlyContinue) { function top { btop    @args } }

# git
function g   { git @args }
function gs  { git status -sb @args }
function gd  { git diff @args }
function gp  { git push @args }
function gl  { git pull @args }
function gco { git checkout @args }

# ──────────────────── Kubernetes / DevOps ───────────────────────
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
  if (Get-Command kubecolor -ErrorAction SilentlyContinue) { function k { kubecolor @args } }
  else { function k { kubectl @args } }
  kubectl completion powershell | Out-String | Invoke-Expression
  function kgp   { kubectl get pods @args }
  function kgs   { kubectl get svc  @args }
  function kga   { kubectl get all  @args }
  function kdesc { kubectl describe @args }
  function kctx  { kubectx @args }
  function kns   { kubens  @args }
  $env:KUBE_EDITOR = 'vim'
}
if (Get-Command helm   -ErrorAction SilentlyContinue) { helm completion powershell   | Out-String | Invoke-Expression }
if (Get-Command argocd -ErrorAction SilentlyContinue) { argocd completion powershell | Out-String | Invoke-Expression }
if (Get-Command gh     -ErrorAction SilentlyContinue) { gh completion -s powershell   | Out-String | Invoke-Expression }

# ───────────────────────────── Misc ─────────────────────────────
$env:EDITOR  = 'vim'
$env:VISUAL  = 'vim'
$env:CLICOLOR = '1'
$env:LANG    = 'en_US.UTF-8'

# Per-machine overrides that shouldn't live in git (like ~/.zshrc.local):
$localProfile = Join-Path $HOME '.config/powershell/profile.local.ps1'
if (Test-Path $localProfile) { . $localProfile }
