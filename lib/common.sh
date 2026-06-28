#!/usr/bin/env bash
# lib/common.sh — shared helpers for the setup scripts.
# Source this at the top of every script:  source "$(dirname "$0")/../lib/common.sh"
#
# Provides: colored logging, error trapping, idempotency guards,
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
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_MAGENTA=$'\033[35m'; C_CYAN=$'\033[36m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_MAGENTA=''; C_CYAN=''
fi

log()      { printf '%s\n' "$*"; }
info()     { printf '%s•%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()       { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()     { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()      { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
step()     { printf '\n%s%s▸ %s%s\n' "$C_BOLD" "$C_CYAN" "$*" "$C_RESET"; }
skip()     { printf '%s↪ %s (already done)%s\n' "$C_DIM" "$*" "$C_RESET"; }

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
confirm() {
  local prompt="${1:-Continue?}"
  [[ "${ASSUME_YES:-0}" == "1" ]] && return 0
  local reply=""
  read -r -p "$prompt [y/N] " reply || true
  [[ "$reply" =~ ^[Yy]$ ]]
}

# Resolve the repo root regardless of where a script is invoked from.
repo_root() { cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd; }

# ---------------------------------------------------------------------------
# Interactive prompts (used by the configuration wizard)
# ---------------------------------------------------------------------------

# ask <var> <prompt> [default]
# Reads a free-text answer into <var>. Falls back to <default> on empty input,
# or automatically when ASSUME_YES=1 / no TTY.
# Set FORCE_INTERACTIVE=1 (e.g. for required personal data) to prompt even
# under ASSUME_YES — a TTY is still required, otherwise we fall back to default.
ask() {
  local __var="$1" __prompt="$2" __default="${3:-}" __reply=""
  if [[ ! -t 0 || ( "${ASSUME_YES:-0}" == "1" && "${FORCE_INTERACTIVE:-0}" != "1" ) ]]; then
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

# choose <var> <prompt> <opt1> [opt2...]   (first option is the default)
# Presents a numbered menu and stores the chosen option text in <var>.
choose() {
  local __var="$1" __prompt="$2"; shift 2
  local __opts=("$@") __i __sel
  if [[ "${ASSUME_YES:-0}" == "1" || ! -t 0 ]]; then
    printf -v "$__var" '%s' "${__opts[0]}"
    printf '%s?%s %s\n  %s→%s %s %s(default)%s\n' \
      "$C_CYAN" "$C_RESET" "$__prompt" "$C_GREEN" "$C_RESET" "${__opts[0]}" "$C_DIM" "$C_RESET"
    return
  fi
  printf '%s?%s %s\n' "$C_CYAN" "$C_RESET" "$__prompt"
  for __i in "${!__opts[@]}"; do
    if [[ $__i -eq 0 ]]; then
      printf '    %s%2d)%s %s %s(default)%s\n' "$C_CYAN" "$((__i+1))" "$C_RESET" "${__opts[$__i]}" "$C_DIM" "$C_RESET"
    else
      printf '    %s%2d)%s %s\n' "$C_CYAN" "$((__i+1))" "$C_RESET" "${__opts[$__i]}"
    fi
  done
  read -r -p "$(printf '  choose [1-%d]: ' "${#__opts[@]}")" __sel || true
  [[ "$__sel" =~ ^[0-9]+$ ]] && (( __sel>=1 && __sel<=${#__opts[@]} )) || __sel=1
  printf -v "$__var" '%s' "${__opts[$((__sel-1))]}"
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
  warn "Backed up existing $(basename "$target") → $backup"
}
