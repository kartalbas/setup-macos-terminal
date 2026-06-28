#!/usr/bin/env bash
# 20-shell.sh — Starship prompt + zsh quality-of-life plugins.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos; require_brew

for f in starship zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
  if brew_has_formula "$f"; then skip "$f"; else
    info "Installing $f..."; run brew install "$f"
  fi
done

# PowerShell LTS (pwsh) — installed as a formula alongside zsh.
if brew_has_formula powershell; then
  skip "powershell"
else
  info "Installing powershell (pwsh)..."; run brew install powershell
fi

# PowerShell dev modules (PSGallery) — icons in listings + fzf key bindings.
# The pwsh profile (config/pwsh/profile.ps1) loads them only if present.
if command -v pwsh >/dev/null; then
  info "Ensuring PowerShell modules (Terminal-Icons, PSFzf)..."
  run pwsh -NoProfile -Command '
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    foreach ($m in "Terminal-Icons","PSFzf") {
      if (-not (Get-Module -ListAvailable -Name $m)) {
        Install-Module $m -Scope CurrentUser -Force
      }
    }'
fi

ok "Shell tooling installed."
info "The 'link' step wires these into ~/.zshrc and ~/.config/starship.toml"
