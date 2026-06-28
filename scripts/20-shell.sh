#!/usr/bin/env bash
# 20-shell.sh — Starship prompt + zsh quality-of-life plugins.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos; require_brew

for f in starship zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
  if brew_has_formula "$f"; then skip "$f"; else
    info "Installing $f..."; run brew install "$f"
  fi
done

ok "Shell tooling installed."
info "The 'link' step wires these into ~/.zshrc and ~/.config/starship.toml"
