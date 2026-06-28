#!/usr/bin/env bash
# 10-terminal.sh — install WezTerm and the Nerd Fonts that make it look sharp.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos; require_brew

install_cask() {
  local cask="$1"
  if brew_has_cask "$cask"; then
    skip "$cask"
  else
    info "Installing $cask..."
    run brew install --cask "$cask"
  fi
}

install_cask wezterm
install_cask font-caskaydia-cove-nerd-font     # Cascadia Code + glyphs (Windows Terminal font)
install_cask font-jetbrains-mono-nerd-font

ok "Terminal + fonts installed."
info "Config gets linked by the 'link' step → ~/.config/wezterm/wezterm.lua"
