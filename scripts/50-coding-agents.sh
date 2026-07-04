#!/usr/bin/env bash
# 50-coding-agents.sh — install coding agents locally, Claude Code first.
#
# Everything lands on your machine (no remote dependency beyond the initial
# download): Claude Code in ~/.local/bin, Node for MCP servers, uv/pipx for
# Python-based agents. Optional extras (aider, GitHub Copilot CLI) at the end.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos; require_brew

# --- Runtimes the agents lean on (idempotent; also covered by the cli step) --
for f in node uv pipx; do
  if brew_has_formula "$f"; then skip "$f"; else
    info "Installing $f..."; run brew install "$f"
  fi
done
has pipx && run pipx ensurepath >/dev/null 2>&1 || true

# --- Claude Code (primary) ---------------------------------------------------
# Official native installer drops a self-contained binary in ~/.local/bin.
if has claude; then
  info "Claude Code present ($(claude --version 2>/dev/null || echo 'version unknown')). Updating..."
  run claude update || warn "claude update skipped/failed (continuing)"
else
  info "Installing Claude Code (native installer → ~/.local/bin)..."
  run bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
fi
# Ensure ~/.local/bin is on PATH (your ~/.zshrc already exports it; keep belt+braces)
case ":$PATH:" in *":$HOME/.local/bin:"*) :;; *) export PATH="$HOME/.local/bin:$PATH";; esac

ok "Claude Code ready. Run ${C_BOLD}claude${C_RESET} in any project; first run will prompt to log in."

# --- GitHub auth (gh) --------------------------------------------------------
# gh is installed in the cli step; authenticate it here so git push / PRs and
# the optional Copilot CLI work. Interactive + idempotent; skipped unattended.
if has gh; then
  if gh auth status >/dev/null 2>&1; then
    skip "gh auth (already logged in)"
  elif [[ "${ASSUME_YES:-0}" == "1" || ! -t 0 || "${DRY_RUN:-0}" == "1" ]]; then
    info "Skipping GitHub login (non-interactive). Run later: ${C_BOLD}gh auth login${C_RESET}"
  elif confirm "Log in to GitHub now (gh auth login)?"; then
    run gh auth login || warn "gh auth login skipped/failed (continuing)"
  fi
else
  info "gh not found — run the ${C_BOLD}cli${C_RESET} step first, then ${C_BOLD}gh auth login${C_RESET}."
fi

# --- Optional extra agents (skipped unless ASSUME_YES or you confirm) --------
if confirm "Also install optional agents (aider, GitHub Copilot CLI)?"; then
  # aider — Python-based pair-programming agent, isolated via uv tool
  if has aider; then skip "aider"; else
    info "Installing aider (via uv tool)..."
    run uv tool install --python 3.12 aider-chat || warn "aider install failed (continuing)"
  fi
  # GitHub Copilot CLI as a gh extension
  if has gh; then
    if gh extension list 2>/dev/null | grep -q 'gh-copilot'; then
      skip "gh copilot extension"
    else
      info "Installing GitHub Copilot CLI (gh extension)..."
      run gh extension install github/gh-copilot || warn "gh-copilot install failed (needs gh auth login)"
    fi
  fi
else
  info "Skipping optional agents."
fi

step "Coding agents summary"
ok   "claude  → $(command -v claude 2>/dev/null || echo 'not found')"
has aider && ok "aider   → $(command -v aider)"
info "Tip: Claude Code reads project context from CLAUDE.md and supports MCP servers (node-based)."
