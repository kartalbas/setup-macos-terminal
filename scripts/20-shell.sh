#!/usr/bin/env bash
# 20-shell.sh — Starship prompt, zsh quality-of-life plugins and PowerShell.
# The list itself lives in the Brewfile under `#: group shell`.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos; require_brew

install_brewfile_group shell

# PowerShell dev modules (PSGallery) — icons in listings + fzf key bindings.
# The pwsh profile (config/pwsh/profile.ps1) loads them only if present.
if has pwsh; then
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
