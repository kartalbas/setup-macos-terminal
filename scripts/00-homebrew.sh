#!/usr/bin/env bash
# 00-homebrew.sh — ensure Homebrew + Xcode Command Line Tools are present.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos

# Xcode CLT (provides git, compilers) ----------------------------------------
if ! xcode-select -p >/dev/null 2>&1; then
  info "Installing Xcode Command Line Tools (a GUI prompt may appear)..."
  run xcode-select --install || true
  warn "Finish the Xcode CLT install in the popup, then re-run this script."
  # Don't hard-fail; brew can also trigger this.
else
  skip "Xcode Command Line Tools"
fi

# Homebrew --------------------------------------------------------------------
if has brew; then
  skip "Homebrew ($(brew --version | head -1))"
else
  info "Installing Homebrew..."
  run /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make sure brew is on PATH for the rest of this run + future shells ----------
BREW="$(brew_prefix)/bin/brew"
if [[ -x "$BREW" ]]; then
  eval "$("$BREW" shellenv)"
  if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
    info "Adding brew to ~/.zprofile"
    run bash -c "echo 'eval \"\$($BREW shellenv)\"' >> \"$HOME/.zprofile\""
  fi
fi

info "Updating Homebrew..."
run brew update --quiet || warn "brew update failed (continuing)"
ok "Homebrew ready."
