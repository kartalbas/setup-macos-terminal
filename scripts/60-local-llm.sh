#!/usr/bin/env bash
# 60-local-llm.sh — opt-in local coding LLM: Qwen3.6-27B (6-bit MLX) via
# Rapid-MLX, driven by opencode. Heavy (~30 GB download) + touches GPU memory
# settings (sudo). Excluded from `all`/`core`; run explicitly: ./install.sh local-llm
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos; require_brew
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MODEL_ID="unsloth/Qwen3.6-27B-UD-MLX-6bit"
MODEL_DIR="$HOME/models/Qwen3.6-27B-UD-MLX-6bit"
WIRED_MB=36864
PLIST="com.setup.iogpu-wired-limit.plist"
PLIST_SRC="$ROOT/config/system/$PLIST"
PLIST_DST="/Library/LaunchDaemons/$PLIST"

# --- Safety gate: never run the heavy parts non-interactively / under --yes ---
if [[ "${DRY_RUN:-0}" == "1" ]]; then
  info "DRY-RUN: showing local-llm actions without prompting."
elif [[ ! -t 0 ]]; then
  warn "local-llm is opt-in (≈30 GB download + sudo) and needs an interactive terminal."
  info  "Run it directly:  ./install.sh local-llm"
  exit 0
else
  printf '%s' "This downloads ~30 GB and can change GPU memory settings (sudo). Continue? [y/N] "
  read -r _ans
  [[ "$_ans" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
fi

# --- Ensure uv (self-contained: don't assume the cli/agents step ran) ---------
if has uv; then skip "uv"; else info "Installing uv…"; run brew install uv; fi
case ":$PATH:" in *":$HOME/.local/bin:"*) :;; *) export PATH="$HOME/.local/bin:$PATH";; esac

# --- Runtime + downloader (Python CLIs via uv tool) ---------------------------
if has rapid-mlx; then skip "rapid-mlx"; else info "Installing rapid-mlx (uv tool)…"; run uv tool install rapid-mlx; fi
if has hf;        then skip "hf (huggingface_hub)"; else info "Installing huggingface_hub…"; run uv tool install huggingface_hub; fi

# --- Client (opencode via Homebrew) -------------------------------------------
if brew_has_formula opencode; then skip "opencode"; else info "Installing opencode…"; run brew install opencode; fi

# --- Model weights (~30 GB, idempotent, single store) -------------------------
if [[ -d "$MODEL_DIR" && -n "$(ls -A "$MODEL_DIR" 2>/dev/null)" ]]; then
  skip "model already present ($MODEL_DIR)"
else
  info "Downloading $MODEL_ID (~30 GB) → $MODEL_DIR …"
  run hf download "$MODEL_ID" --local-dir "$MODEL_DIR"
fi

# --- Control script on PATH ---------------------------------------------------
run mkdir -p "$HOME/.local/bin"
run ln -sfn "$ROOT/bin/llm" "$HOME/.local/bin/llm"

# --- opencode config (self-contained link; no secrets) ------------------------
run mkdir -p "$HOME/.config/opencode"
backup_path "$HOME/.config/opencode/opencode.json" "$ROOT"
run ln -sfn "$ROOT/config/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
ok "linked opencode.json → local Rapid-MLX endpoint (port 5413, 100k context)"

# --- GPU wired-limit LaunchDaemon (sudo, interactive-only) --------------------
if confirm "Raise GPU wired limit to 36 GiB and persist across reboots (needs sudo)?"; then
  run sudo cp "$PLIST_SRC" "$PLIST_DST"
  run sudo chown root:wheel "$PLIST_DST"
  run sudo chmod 0644 "$PLIST_DST"
  run sudo launchctl bootstrap system "$PLIST_DST" || warn "bootstrap failed (already loaded?)"
  run sudo sysctl -w "iogpu.wired_limit_mb=$WIRED_MB"
  ok "GPU wired limit set to 36 GiB (persists via LaunchDaemon)."
else
  info "Skipped wired-limit change. Set it manually when needed:"
  info "  sudo sysctl -w iogpu.wired_limit_mb=$WIRED_MB"
fi

step "local-llm summary"
ok   "runtime : $(command -v rapid-mlx 2>/dev/null || echo 'not found')"
ok   "client  : $(command -v opencode  2>/dev/null || echo 'not found')"
ok   "control : llm start | llm status | llm stop"
info "Start the server (${C_BOLD}llm start${C_RESET}), then run ${C_BOLD}opencode${C_RESET} in a project."
info "First-run checklist: docs/superpowers/specs/2026-07-04-local-coding-llm-mlx-design.md (§10)."
