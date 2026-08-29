#!/usr/bin/env bash
# lib/common.sh — shared helpers for the setup scripts.
# Source this at the top of every script:  source "$(dirname "$0")/../lib/common.sh"
#
# Provides: colored logging, error trapping, idempotency guards, Brewfile-driven
# Homebrew helpers, and dry-run support.

# ---------------------------------------------------------------------------
# Strict mode + error trap
# ---------------------------------------------------------------------------
set -Eeuo pipefail

# Print a friendly message with the failing command + line on any error.
_on_err() {
  local exit_code=$?
  local line=${1:-?}
  printf '\n\033[1;31m✗ Error (exit %s) on line %s:\033[0m %s\n' \
    "$exit_code" "$line" "${BASH_COMMAND:-unknown}" >&2
  printf '  Re-run with \033[1mDEBUG=1\033[0m for a full trace.\n' >&2
  exit "$exit_code"
}
trap '_on_err $LINENO' ERR

[[ "${DEBUG:-0}" == "1" ]] && set -x

# ---------------------------------------------------------------------------
# Colors (auto-disabled when not a TTY or NO_COLOR is set)
# ---------------------------------------------------------------------------
# A function, not a one-shot block: install.sh parses --no-color *after*
# sourcing this file and calls set_colors again to apply it.
set_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'
  else
    C_RESET=''; C_BOLD=''; C_DIM=''
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''
  fi
}
set_colors

log()      { printf '%s\n' "$*"; }
info()     { printf '%s•%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()       { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()     { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()      { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
step()     { printf '\n%s%s▸ %s%s\n' "$C_BOLD" "$C_CYAN" "$*" "$C_RESET"; }
skip()     { printf '%s↪ %s (already done)%s\n' "$C_DIM" "$*" "$C_RESET"; }
absent()   { printf '%s✗%s %s %s(missing)%s\n' "$C_YELLOW" "$C_RESET" "$*" "$C_DIM" "$C_RESET"; }

# ---------------------------------------------------------------------------
# Repo paths (resolved from this file, so scripts work from any cwd)
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWFILE="$REPO_ROOT/Brewfile"

# ---------------------------------------------------------------------------
# Dry-run support: set DRY_RUN=1 to print commands instead of running them.
# ---------------------------------------------------------------------------
run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '%s[dry-run]%s %s\n' "$C_DIM" "$C_RESET" "$*"
  else
    "$@"
  fi
}

# ---------------------------------------------------------------------------
# Idempotency / detection helpers
# ---------------------------------------------------------------------------
has()           { command -v "$1" >/dev/null 2>&1; }
is_macos()      { [[ "$(uname -s)" == "Darwin" ]]; }
is_arm()        { [[ "$(uname -m)" == "arm64" ]]; }

brew_prefix() { is_arm && echo /opt/homebrew || echo /usr/local; }

# True if a Homebrew formula/cask is already installed.
brew_has_formula() { brew list --formula --versions "$1" >/dev/null 2>&1; }
brew_has_cask()    { brew list --cask --versions "$1" >/dev/null 2>&1; }

require_macos() {
  is_macos || { err "This script only supports macOS."; exit 1; }
}

require_brew() {
  has brew || { err "Homebrew not found. Run scripts/00-homebrew.sh first."; exit 1; }
}

# Confirm helper — honors ASSUME_YES=1 (set by install.sh --yes).
# Under --dry-run we answer "yes" so the preview shows the full set of actions
# instead of stopping at a prompt; nothing is executed either way.
confirm() {
  local prompt="${1:-Continue?}"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '%s[dry-run]%s %s → assuming yes\n' "$C_DIM" "$C_RESET" "$prompt"
    return 0
  fi
  [[ "${ASSUME_YES:-0}" == "1" ]] && return 0
  local reply=""
  read -r -p "$prompt [y/N] " reply || true
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ---------------------------------------------------------------------------
# Interactive prompts (used by the configuration wizard)
# ---------------------------------------------------------------------------

# ask <var> <prompt> [default]
# Reads a free-text answer into <var>. Falls back to <default> on empty input,
# or automatically when ASSUME_YES=1 / DRY_RUN=1 / no TTY.
# Set FORCE_INTERACTIVE=1 (e.g. for required personal data) to prompt even
# under ASSUME_YES — a TTY is still required, otherwise we fall back to default.
ask() {
  local __var="$1" __prompt="$2" __default="${3:-}" __reply=""
  if [[ ! -t 0 || "${DRY_RUN:-0}" == "1" \
        || ( "${ASSUME_YES:-0}" == "1" && "${FORCE_INTERACTIVE:-0}" != "1" ) ]]; then
    __reply="$__default"
  else
    if [[ -n "$__default" ]]; then
      read -r -p "$(printf '%s?%s %s %s[%s]%s ' \
        "$C_CYAN" "$C_RESET" "$__prompt" "$C_DIM" "$__default" "$C_RESET")" __reply || true
    else
      read -r -p "$(printf '%s?%s %s ' "$C_CYAN" "$C_RESET" "$__prompt")" __reply || true
    fi
    [[ -z "$__reply" ]] && __reply="$__default"
  fi
  printf -v "$__var" '%s' "$__reply"
  printf '  %s→%s %s\n' "$C_GREEN" "$C_RESET" "${!__var}"
}

# render <template> <output> <TOKEN> <value> [<TOKEN> <value> ...]
# Copies <template> to <output>, substituting each TOKEN with its value.
# Uses bash string replacement so values with spaces/parens are safe.
render() {
  local tmpl="$1" out="$2"; shift 2
  [[ -f "$tmpl" ]] || { err "template missing: $tmpl"; return 1; }
  local content; content="$(cat "$tmpl")"
  while [[ $# -ge 2 ]]; do
    content="${content//$1/$2}"; shift 2
  done
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '%s[dry-run]%s would render → %s\n' "$C_DIM" "$C_RESET" "$out"
  else
    mkdir -p "$(dirname "$out")"
    printf '%s\n' "$content" > "$out"
  fi
}

# Back up a file/symlink to <path>.backup.<timestamp> if it exists and is not
# already a symlink into our repo.
backup_path() {
  local target="$1" repo="$2"
  [[ -e "$target" || -L "$target" ]] || return 0
  # If it already points into the repo, nothing to back up.
  if [[ -L "$target" && "$(readlink "$target")" == "$repo"* ]]; then
    return 0
  fi
  local stamp backup
  stamp="$(date +%Y%m%d-%H%M%S)"
  backup="${target}.backup.${stamp}"
  run mv "$target" "$backup"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '%s[dry-run]%s would back up %s → %s\n' \
      "$C_DIM" "$C_RESET" "$(basename "$target")" "$backup"
  else
    warn "Backed up existing $(basename "$target") → $backup"
  fi
}

# ---------------------------------------------------------------------------
# Deployed configs — the canonical src|dst list
# ---------------------------------------------------------------------------
# Single source for scripts/90-link-configs.sh (which installs them) and
# ./install.sh --status (which reports on them), so the two can't drift.
config_pairs() {
  cat <<PAIRS
$REPO_ROOT/config/wezterm/wezterm.lua|$HOME/.config/wezterm/wezterm.lua
$REPO_ROOT/config/starship/starship.toml|$HOME/.config/starship.toml
$REPO_ROOT/config/zsh/zshrc|$HOME/.zshrc
$REPO_ROOT/config/pwsh/profile.ps1|$HOME/.config/powershell/profile.ps1
$REPO_ROOT/generated/gitconfig|$HOME/.gitconfig
PAIRS
}

# ---------------------------------------------------------------------------
# Brewfile = the single source of truth for package lists
# ---------------------------------------------------------------------------
# Every entry in Brewfile belongs to the `#: group <name>` marker above it, and
# each install step asks for its own group instead of keeping a second copy of
# the list. Edit the Brewfile and the steps follow — nothing to keep in sync.
#
#   brewfile_items <group> <brew|cask|tap>   → one item per line
brewfile_items() {
  local group="$1" kind="$2"
  [[ -f "$BREWFILE" ]] || { err "Brewfile not found: $BREWFILE"; return 1; }
  awk -v group="$group" -v kind="$kind" '
    /^#:[[:space:]]*group[[:space:]]/ { g = $NF; next }
    g == group && $1 == kind && match($0, /"[^"]+"/) {
      print substr($0, RSTART + 1, RLENGTH - 2)
    }
  ' "$BREWFILE"
}

# Refresh the formula index at most once a day. `brew install` auto-updates on
# its own, so forcing an update on every run (and again per package) is wasted
# time; we do it once, then switch the per-install check off for this process.
_BREW_REFRESHED=0
brew_refresh_index() {
  [[ "$_BREW_REFRESHED" == "1" ]] && return 0
  _BREW_REFRESHED=1
  local stamp="$HOME/.cache/setup-macos-terminal/brew-update"
  if [[ -f "$stamp" && -z "$(find "$stamp" -mmin +1440 2>/dev/null)" ]]; then
    skip "brew update (index refreshed less than 24h ago)"
  else
    info "Updating Homebrew index..."
    run brew update --quiet || warn "brew update failed (continuing)"
    run mkdir -p "$(dirname "$stamp")"
    run touch "$stamp"
  fi
  export HOMEBREW_NO_AUTO_UPDATE=1
}

# install_formula <formula>...   — skip what's there, install what isn't.
# Accepts tapped names (hashicorp/tap/vault); `brew list` checks the leaf name.
install_formula() {
  local f leaf
  for f in "$@"; do
    leaf="${f##*/}"
    if brew_has_formula "$leaf"; then skip "$leaf"; continue; fi
    brew_refresh_index
    info "Installing $f..."; run brew install "$f"
  done
}

# install_cask <cask>...
install_cask() {
  local c
  for c in "$@"; do
    if brew_has_cask "$c"; then skip "$c"; continue; fi
    brew_refresh_index
    info "Installing $c..."; run brew install --cask "$c"
  done
}

# brew_tap <tap>...
brew_tap() {
  local t
  for t in "$@"; do
    if brew tap | grep -qx "$t"; then skip "tap $t"; continue; fi
    brew_refresh_index
    info "Tapping $t..."; run brew tap "$t"
  done
}

# install_brewfile_group <group>
# Install every tap/formula/cask tagged `#: group <group>` in the Brewfile.
install_brewfile_group() {
  local group="$1" item count=0
  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    count=$((count + 1)); brew_tap "$item"
  done < <(brewfile_items "$group" tap)
  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    count=$((count + 1)); install_formula "$item"
  done < <(brewfile_items "$group" brew)
  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    count=$((count + 1)); install_cask "$item"
  done < <(brewfile_items "$group" cask)
  [[ $count -gt 0 ]] || warn "No Brewfile entries tagged '#: group $group' — nothing to install."
}
