#!/usr/bin/env bash
# install.sh — one entry point for the whole macOS dev-terminal setup.
#
#   ./install.sh                 interactive menu
#   ./install.sh all             run everything, in order
#   ./install.sh core            homebrew + terminal + shell + cli tools
#   ./install.sh devops          kubectl, argocd, vault, helm, k9s, terraform...
#   ./install.sh agents          Claude Code + runtimes (node, uv) — all local
#   ./install.sh link            symlink dotfiles (.zshrc, wezterm, starship, git)
#   ./install.sh <step-name>     run a single step (see list below)
#
# Flags (can combine):
#   --yes / -y     assume "yes" to prompts (non-interactive)
#   --dry-run      print actions without making changes
#   --no-color     disable colored output
#   --help / -h    show this help

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/common.sh"

# Ordered list of steps:  key | script | description
STEPS=(
  "configure|05-configure.sh|Set your git identity → generate gitconfig (only personal data)"
  "homebrew|00-homebrew.sh|Install/verify Homebrew"
  "terminal|10-terminal.sh|WezTerm + Nerd Fonts (Cascadia/JetBrains)"
  "shell|20-shell.sh|Starship prompt + zsh plugins"
  "cli|30-cli-tools.sh|Modern CLI tools (eza, bat, rg, fzf, lazygit...)"
  "devops|40-devops.sh|kubectl, argocd, vault, helm, k9s, terraform..."
  "agents|50-coding-agents.sh|Claude Code + runtimes (node, uv) — local"
  "local-llm|60-local-llm.sh|(opt-in, ~30GB) Local coding LLM: Qwen3.6-27B MLX + Rapid-MLX + opencode"
  "link|90-link-configs.sh|Symlink dotfiles (backs up existing)"
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
  # Configuration is gathered once up front; skip later re-runs in a group.
  if [[ "$key" == "configure" && "${CONFIGURED:-0}" == "1" ]]; then return 0; fi
  for s in "${STEPS[@]}"; do
    IFS='|' read -r k script desc <<<"$s"
    if [[ "$k" == "$key" ]]; then
      step "$desc"
      run bash "$ROOT/scripts/$script"
      return 0
    fi
  done
  err "Unknown step: $key"; return 1
}

run_group() {
  case "$1" in
    all)    for s in "${STEPS[@]}"; do
              key="${s%%|*}"; [[ "$key" == "local-llm" ]] && continue
              run_step "$key"
            done ;;
    core)   for k in configure homebrew terminal shell cli link; do run_step "$k"; done ;;
    *)      run_step "$1" ;;
  esac
}

interactive_menu() {
  banner
  log "Pick what to install. Type numbers (e.g. ${C_BOLD}1 3 4${C_RESET}) or ${C_BOLD}a${C_RESET} for all.\n"
  local i=1
  for s in "${STEPS[@]}"; do
    IFS='|' read -r key _ desc <<<"$s"
    printf '  %s%2d)%s %-9s %s\n' "$C_CYAN" "$i" "$C_RESET" "$key" "$desc"
    ((i++))
  done
  printf '  %s a)%s %s\n' "$C_CYAN" "$C_RESET" "everything (recommended on a fresh machine)"
  printf '  %s q)%s quit\n\n' "$C_CYAN" "$C_RESET"

  read -r -p "Selection: " sel
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
  local targets=()
  for arg in "$@"; do
    case "$arg" in
      -h|--help)    usage; exit 0 ;;
      -y|--yes)     export ASSUME_YES=1 ;;
      --dry-run)    export DRY_RUN=1; warn "DRY-RUN: no changes will be made" ;;
      --no-color)   export NO_COLOR=1 ;;
      -*)           err "Unknown flag: $arg"; usage; exit 1 ;;
      *)            targets+=("$arg") ;;
    esac
  done

  # Always gather the user-specific git identity first — the only thing we ask.
  # Everything else is standard config. Mark it done so groups don't re-prompt.
  run_step configure
  CONFIGURED=1

  if [[ ${#targets[@]} -eq 0 ]]; then
    interactive_menu
  else
    for t in "${targets[@]}"; do run_group "$t"; done
  fi

  step "Done"
  ok "Setup finished."
  info "Open a new ${C_BOLD}WezTerm${C_RESET} window (or run: ${C_BOLD}exec zsh${C_RESET}) to load everything."
  info "Guide (tools, shortcuts, local LLM, troubleshooting): ${C_BOLD}docs/README.md${C_RESET}"
}

main "$@"
