#!/usr/bin/env bash
# 90-link-configs.sh — COPY the repo's configs into place so they are fully
# independent of this repo. After install you can delete setup-macos-terminal
# entirely and every config keeps working (no symlinks pointing back here).
# Existing real files are backed up to <file>.backup.<timestamp> first; an old
# symlink from a previous install is replaced by a real copy.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$ROOT/generated"
CFG="$ROOT/config"

# Only the git config carries user-specific data and is rendered from a
# template. If it doesn't exist yet, run the wizard so we never deploy the
# un-rendered gitconfig.example. The rest are standard configs, copied as-is.
if [[ ! -f "$GEN/gitconfig" ]]; then
  warn "No generated gitconfig found — running the configuration wizard first."
  run bash "$ROOT/scripts/05-configure.sh"
fi

install_config() {
  local src="$1" dst="$2"
  [[ -f "$src" ]] || { err "Missing source: $src"; return 1; }
  run mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    # Replace an old symlink (e.g. from a previous symlink-based install) — do
    # NOT cp through it, or we'd write back into the repo.
    run rm -f "$dst"
  elif [[ -e "$dst" ]]; then
    if cmp -s "$src" "$dst"; then ok "$(basename "$dst") already up to date"; return 0; fi
    backup_path "$dst" "$ROOT"
  fi
  run cp "$src" "$dst"
  ok "installed $(basename "$dst") (copy — independent of this repo)"
}

# Standard tooling configs — copied to their destinations as real files.
install_config "$CFG/wezterm/wezterm.lua"    "$HOME/.config/wezterm/wezterm.lua"
install_config "$CFG/starship/starship.toml" "$HOME/.config/starship.toml"
install_config "$CFG/zsh/zshrc"              "$HOME/.zshrc"
install_config "$CFG/pwsh/profile.ps1"       "$HOME/.config/powershell/profile.ps1"
# User-specific config — rendered into generated/ (git-ignored), then copied.
install_config "$GEN/gitconfig"              "$HOME/.gitconfig"

ok "Configs installed as independent copies — you can delete this repo now if you want."
info "Open a new shell (${C_BOLD}exec zsh${C_RESET}) or a fresh WezTerm window to load them."
info "To change a config later, edit the deployed file directly (e.g. ${C_BOLD}~/.zshrc${C_RESET})."
