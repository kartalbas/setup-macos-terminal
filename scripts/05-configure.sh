#!/usr/bin/env bash
# 05-configure.sh — configure the only user-specific data: your git identity.
#
# Asks for your git name & email, then renders config/git/gitconfig.example
# into generated/gitconfig. Everything else (WezTerm, Starship, zsh) ships as
# standard config and is symlinked as-is by the 'link' step — no rendering.
# Answers are saved to generated/answers.env so re-runs can reuse them.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$ROOT/generated"
ANSWERS="$GEN/answers.env"
run mkdir -p "$GEN"

ANSWER_VARS=(GIT_NAME GIT_EMAIL)

# ── Work out sensible defaults ─────────────────────────────────────────────
# Prefer a previously saved answer, then your existing global git config, then
# a generic placeholder. Nothing personal is ever hardcoded in this (public) repo.
[[ -f "$ANSWERS" ]] && source "$ANSWERS"   # may set GIT_NAME / GIT_EMAIL
default_name="${GIT_NAME:-}"
if [[ -z "$default_name" || "$default_name" == "Your Name" ]]; then
  default_name="$(git config --global user.name 2>/dev/null || echo 'Your Name')"
fi
default_email="${GIT_EMAIL:-}"
if [[ -z "$default_email" || "$default_email" == "you@example.com" ]]; then
  default_email="$(git config --global user.email 2>/dev/null || echo 'you@example.com')"
fi

# ── Ask the questions (only user-specific data lives here) ─────────────────
# Always prompt for the git identity — even under --yes — because it's the one
# thing we can't sensibly guess. (Falls back to defaults only when there's no
# terminal, e.g. piped/CI runs.)
step "Set up your git identity — the only personal data we store"
printf '%sPress Enter to accept the [default] shown in brackets.%s\n\n' "$C_DIM" "$C_RESET"

FORCE_INTERACTIVE=1 ask GIT_NAME  "Git author name" "$default_name"
FORCE_INTERACTIVE=1 ask GIT_EMAIL "Git email"       "$default_email"

# Persist answers (sourceable & shell-safe via %q)
if [[ "${DRY_RUN:-0}" != "1" ]]; then
  {
    echo "# Saved by ./install.sh configure. Edit then re-run: ./install.sh link"
    for v in "${ANSWER_VARS[@]}"; do printf '%s=%q\n' "$v" "${!v}"; done
  } > "$ANSWERS"
fi

# ── Render the only templated config ───────────────────────────────────────
step "Generating your git config"

render "$ROOT/config/git/gitconfig.example"          "$GEN/gitconfig" \
  "__GIT_NAME__"             "$GIT_NAME" \
  "__GIT_EMAIL__"            "$GIT_EMAIL"

# ── Summary ────────────────────────────────────────────────────────────────
step "Created this file"
row() { printf '  %s%s%s\n      %s%s%s\n' "$C_GREEN$C_BOLD" "$1" "$C_RESET" "$C_DIM" "$2" "$C_RESET"; }
row "generated/gitconfig"     "$GIT_NAME <$GIT_EMAIL>"
echo
printf '  %sAnswers saved to:%s generated/answers.env (edit & re-run to change)\n' "$C_DIM" "$C_RESET"
info "WezTerm, Starship & zsh are standard configs — symlinked as-is, nothing to answer."
ok "Configuration generated."
info "These get symlinked into place by the ${C_BOLD}link${C_RESET} step (run as part of ${C_BOLD}all${C_RESET}/${C_BOLD}core${C_RESET})."
