#!/usr/bin/env bash
# 90-link-configs.sh — COPY the repo's configs into place so they are fully
# independent of this repo. After install you can delete setup-macos-terminal
# entirely and every config keeps working (no symlinks pointing back here).
# Existing real files are backed up to <file>.backup.<timestamp> first; an old
# symlink from a previous install is replaced by a real copy.
#
# The src|dst list lives in config_pairs() in lib/common.sh, shared with
# `./install.sh --status` so the two can't drift.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos

# Only the git config carries user-specific data and is rendered from a
# template. If it doesn't exist yet, run the wizard so we never deploy the
# un-rendered gitconfig.example. The rest are standard configs, copied as-is.
if [[ ! -f "$REPO_ROOT/generated/gitconfig" ]]; then
  warn "No generated gitconfig found — running the configuration wizard first."
  run bash "$REPO_ROOT/scripts/05-configure.sh"
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
    backup_path "$dst" "$REPO_ROOT"
  fi
  run cp "$src" "$dst"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '%s[dry-run]%s would install %s\n' "$C_DIM" "$C_RESET" "$(basename "$dst")"
  else
    ok "installed $(basename "$dst") (copy — independent of this repo)"
  fi
}

while IFS='|' read -r src dst; do
  [[ -n "$src" ]] || continue
  install_config "$src" "$dst"
done < <(config_pairs)

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  info "Dry run — nothing was written."
else
  ok "Configs installed as independent copies — you can delete this repo now if you want."
  info "Open a new shell (${C_BOLD}exec zsh${C_RESET}) or a fresh WezTerm window to load them."
fi
# Deliberately NOT "edit ~/.zshrc": re-running this step replaces it with the
# repo's copy (backing yours up). The *.local files are never touched.
info "Machine-specific tweaks go in ${C_BOLD}~/.zshrc.local${C_RESET} / ${C_BOLD}~/.config/powershell/profile.local.ps1${C_RESET} — sourced last, and re-runs never touch them."
info "To change a config for every machine, edit it under ${C_BOLD}config/${C_RESET} here and re-run ${C_BOLD}./install.sh link${C_RESET}."
