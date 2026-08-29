#!/usr/bin/env bash
# 30-cli-tools.sh — modern CLI replacements + language/version managers.
# The list itself lives in the Brewfile under `#: group cli`, so this step and
# `brew bundle` can never disagree about what "cli" means.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos; require_brew

install_brewfile_group cli

# nvm needs its working dir to exist; the ~/.zshrc sources it from there.
run mkdir -p "$HOME/.nvm"

# fzf key-bindings & fuzzy completion (writes to its own files; safe to re-run)
if has fzf; then
  info "Setting up fzf key-bindings..."
  run "$(brew --prefix)/opt/fzf/install" --key-bindings --completion \
      --no-update-rc --no-bash --no-fish
fi

ok "Modern CLI tools installed."
info "Verify the Flutter toolchain later with: ${C_BOLD}flutter doctor${C_RESET}"
