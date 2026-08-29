#!/usr/bin/env bash
# install.sh — one entry point for the whole macOS dev-terminal setup.
#
#   ./install.sh                 interactive menu
#   ./install.sh all             run everything, in order
#   ./install.sh core            homebrew + terminal + shell + cli tools
#   ./install.sh devops          kubectl, argocd, vault, helm, k9s, terraform...
#   ./install.sh agents          Claude Code + runtimes (node, uv) — all local
#   ./install.sh link            copy configs into place (.zshrc, wezterm, starship, git)
#   ./install.sh <step-name>     run a single step (see list below)
#
# Flags (can combine):
#   --status / -s  report what's already installed, then exit
#   --yes / -y     assume "yes" to prompts (non-interactive)
#   --dry-run      print actions without making changes
#   --no-color     disable colored output
#   --help / -h    show this help

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

# Ordered list of steps:  key | script | description
STEPS=(
  "configure|05-configure.sh|Set your git identity → generate gitconfig (only personal data)"
  "homebrew|00-homebrew.sh|Install/verify Homebrew"
  "terminal|10-terminal.sh|WezTerm + Nerd Fonts (Cascadia/JetBrains)"
  "shell|20-shell.sh|Starship prompt + zsh plugins"
  "cli|30-cli-tools.sh|Modern CLI tools (eza, bat, rg, fzf, lazygit...)"
  "devops|40-devops.sh|kubectl, argocd, vault, helm, k9s, terraform..."
  "agents|50-coding-agents.sh|Claude Code + runtimes (node, uv) — local"
  "link|90-link-configs.sh|Copy configs into place — independent of this repo"
)

usage() {
  # Print the contiguous header comment block (lines 2.. up to first non-comment).
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "${BASH_SOURCE[0]}"
  echo
  step "Available steps"
  for s in "${STEPS[@]}"; do
    IFS='|' read -r key _ desc <<<"$s"
    printf '  %s%-10s%s %s\n' "$C_BOLD" "$key" "$C_RESET" "$desc"
  done
  echo
  printf '  %s%-10s%s %s\n' "$C_BOLD" "core" "$C_RESET" "configure + homebrew + terminal + shell + cli + link"
  printf '  %s%-10s%s %s\n' "$C_BOLD" "all" "$C_RESET" "every step above, in order"
}

banner() {
  cat <<'EOF'

   __  __         ___    ___   ___      _              ___
  |  \/  |__ _ __/ _ \  / __| |   \ ___| |__   ___ _ _|_  )
  | |\/| / _` / _\ (_) | \__ \ | |) / -_) V / |/ -_) ' \/ /
  |_|  |_\__,_\__|\___/  |___/ |___/\___|\_/  |_\___|_||_/___|
                  WezTerm-first developer terminal setup

EOF
}

run_step() {
  local key="$1"
  # The git-identity wizard is only ever needed once per invocation.
  if [[ "$key" == "configure" ]]; then
    if [[ "${CONFIGURED:-0}" == "1" ]]; then skip "git identity (configured earlier this run)"; return 0; fi
    CONFIGURED=1
  fi
  for s in "${STEPS[@]}"; do
    IFS='|' read -r k script desc <<<"$s"
    if [[ "$k" == "$key" ]]; then
      step "$desc"
      # NOT wrapped in run(): each step script handles DRY_RUN itself, so a
      # dry run has to actually execute them to show what they *would* do.
      bash "$REPO_ROOT/scripts/$script"
      return 0
    fi
  done
  # exit, not `return 1`: a non-zero return here would also trip the ERR trap
  # and print a second, scarier error on top of this one.
  err "Unknown step: $key"
  local keys=""
  for s in "${STEPS[@]}"; do keys="$keys ${s%%|*}"; done
  info "Valid steps:$keys, plus the groups: core all"
  exit 1
}

run_group() {
  case "$1" in
    all)    for s in "${STEPS[@]}"; do run_step "${s%%|*}"; done ;;
    core)   for k in configure homebrew terminal shell cli link; do run_step "$k"; done ;;
    *)      run_step "$1" ;;
  esac
}

# --- ./install.sh --status ---------------------------------------------------
# Reports against the same two sources the installer uses: the Brewfile groups
# and config_pairs(), so it can't disagree with what a real run would do.
status_group() {
  local group="$1" total=0 have=0 missing="" item leaf
  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    total=$((total + 1)); leaf="${item##*/}"
    if brew_has_formula "$leaf"; then have=$((have + 1)); else missing="$missing $leaf"; fi
  done < <(brewfile_items "$group" brew)
  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    total=$((total + 1))
    if brew_has_cask "$item"; then have=$((have + 1)); else missing="$missing $item"; fi
  done < <(brewfile_items "$group" cask)
  if [[ $have -eq $total ]]; then
    printf '  %s✓%s %-9s %s%d/%d%s\n' "$C_GREEN" "$C_RESET" "$group" "$C_DIM" "$have" "$total" "$C_RESET"
  else
    printf '  %s✗%s %-9s %d/%d%s  missing:%s%s\n' \
      "$C_YELLOW" "$C_RESET" "$group" "$have" "$total" "$C_DIM" "$C_RESET" "$missing"
  fi
}

status_report() {
  step "Packages (from Brewfile)"
  if ! has brew; then
    absent "Homebrew — run ./install.sh homebrew first"
  else
    local group
    for group in terminal shell cli devops; do status_group "$group"; done
  fi

  step "Configs (from config_pairs)"
  local src dst
  while IFS='|' read -r src dst; do
    [[ -n "$src" ]] || continue
    if [[ ! -f "$src" ]]; then
      absent "$(basename "$dst") — source not generated yet (./install.sh configure)"
    elif [[ ! -e "$dst" && ! -L "$dst" ]]; then
      absent "$dst"
    elif cmp -s "$src" "$dst"; then
      ok "$dst"
    else
      warn "$dst differs from this repo — ./install.sh link would replace it (backing yours up)"
    fi
  done < <(config_pairs)

  step "Agents"
  if has claude; then ok "claude → $(command -v claude)"; else absent "claude"; fi
  if has gh; then
    if gh auth status >/dev/null 2>&1; then ok "gh (logged in)"; else absent "gh login — run: gh auth login"; fi
  else
    absent "gh"
  fi
}

interactive_menu() {
  banner
  log "Pick what to install. Type numbers (e.g. ${C_BOLD}1 3 4${C_RESET}) or ${C_BOLD}a${C_RESET} for all."
  echo
  local i=1
  for s in "${STEPS[@]}"; do
    IFS='|' read -r key _ desc <<<"$s"
    printf '  %s%2d)%s %-9s %s\n' "$C_CYAN" "$i" "$C_RESET" "$key" "$desc"
    ((i++))
  done
  printf '  %s a)%s %s\n' "$C_CYAN" "$C_RESET" "everything (recommended on a fresh machine)"
  printf '  %s q)%s quit\n\n' "$C_CYAN" "$C_RESET"

  # `|| true` matters: without stdin (piped install, `< /dev/null`, CI) read
  # returns 1, which the ERR trap would turn into a red crash.
  local sel=""
  read -r -p "Selection: " sel || { echo; info "No input — nothing to do."; exit 0; }
  [[ "$sel" =~ ^[Qq]$ || -z "$sel" ]] && { info "Nothing to do."; exit 0; }
  if [[ "$sel" =~ ^[Aa]$ ]]; then run_group all; return; fi
  for n in $sel; do
    local idx=$((n-1))
    [[ $idx -ge 0 && $idx -lt ${#STEPS[@]} ]] || { warn "Ignoring '$n'"; continue; }
    run_step "${STEPS[$idx]%%|*}"
  done
}

main() {
  require_macos
  local targets=() want_status=0
  for arg in "$@"; do
    case "$arg" in
      -h|--help)     usage; exit 0 ;;
      -s|--status)   want_status=1 ;;
      -y|--yes)      export ASSUME_YES=1 ;;
      --dry-run)     export DRY_RUN=1 ;;
      --no-color)    export NO_COLOR=1 ;;
      -*)            err "Unknown flag: $arg"; usage; exit 1 ;;
      *)             targets+=("$arg") ;;
    esac
  done
  set_colors                       # re-apply now that --no-color has been parsed
  [[ "${DRY_RUN:-0}" == "1" ]] && warn "DRY-RUN: no changes will be made"

  if [[ $want_status -eq 1 ]]; then status_report; exit 0; fi

  # The git identity is the only thing we ask for, and it is asked by the
  # `configure` step itself — which leads `all`/`core`, is offered in the menu,
  # and is pulled in on demand by `link`. Steps that never touch it (devops,
  # cli, ...) therefore run without a single prompt.
  if [[ ${#targets[@]} -eq 0 ]]; then
    interactive_menu
  else
    for t in "${targets[@]}"; do run_group "$t"; done
  fi

  step "Done"
  ok "Setup finished."
  info "Open a new ${C_BOLD}WezTerm${C_RESET} window (or run: ${C_BOLD}exec zsh${C_RESET}) to load everything."
  info "Guide (tools, shortcuts, troubleshooting): ${C_BOLD}docs/README.md${C_RESET}"
}

main "$@"
