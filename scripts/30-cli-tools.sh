#!/usr/bin/env bash
# 30-cli-tools.sh — modern CLI replacements + language/version managers.
# Uses `brew bundle` against the Brewfile so it stays declarative & idempotent,
# but only for the CLI + language groups (devops/agents have their own steps).
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos; require_brew

CLI_FORMULAE=(
  eza bat ripgrep fd fzf zoxide git-delta lazygit gh tmux
  jq yq tree wget htop btop tldr fastfetch
  mise node uv pipx
)

for f in "${CLI_FORMULAE[@]}"; do
  if brew_has_formula "$f"; then skip "$f"; else
    info "Installing $f..."; run brew install "$f"
  fi
done

# fzf key-bindings & fuzzy completion (writes to its own files; safe to re-run)
if has fzf && [[ "${DRY_RUN:-0}" != "1" ]]; then
  info "Setting up fzf key-bindings..."
  "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish >/dev/null
fi

ok "Modern CLI tools installed."
