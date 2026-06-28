#!/usr/bin/env bash
# 90-link-configs.sh — symlink the repo's dotfiles into place.
# Existing real files are backed up to <file>.backup.<timestamp> first.
# Re-running is safe: links already pointing into the repo are left alone.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$ROOT/generated"
CFG="$ROOT/config"

# Only the git config carries user-specific data and is rendered from a
# template. If it doesn't exist yet, run the wizard so we never symlink the
# un-rendered gitconfig.example. The rest are standard configs, linked as-is.
if [[ ! -f "$GEN/gitconfig" ]]; then
  warn "No generated gitconfig found — running the configuration wizard first."
  run bash "$ROOT/scripts/05-configure.sh"
fi

link() {
  local src="$1" dst="$2"
  [[ -f "$src" ]] || { err "Missing source: $src"; return 1; }
  run mkdir -p "$(dirname "$dst")"
  backup_path "$dst" "$ROOT"
  run ln -sfn "$src" "$dst"
  ok "linked $(basename "$dst") → ${src#"$HOME"/}"
}

# Standard tooling configs — committed in the repo, linked as-is.
link "$CFG/wezterm/wezterm.lua"   "$HOME/.config/wezterm/wezterm.lua"
link "$CFG/starship/starship.toml" "$HOME/.config/starship.toml"
link "$CFG/zsh/zshrc"             "$HOME/.zshrc"
link "$CFG/pwsh/profile.ps1"      "$HOME/.config/powershell/profile.ps1"
# User-specific config — rendered into generated/ (git-ignored).
link "$GEN/gitconfig"             "$HOME/.gitconfig"

ok "Dotfiles linked."
info "Open a new shell (${C_BOLD}exec zsh${C_RESET}) or a fresh WezTerm window to load them."
