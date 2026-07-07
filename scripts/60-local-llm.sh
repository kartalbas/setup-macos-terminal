#!/usr/bin/env bash
# 60-local-llm.sh — opt-in local coding LLM, fully self-contained under ~/llm.
# Everything (Python venv with Rapid-MLX + hf, the Qwen3.6-27B 6-bit model, the
# opencode config, the control script, runtime state) lives in ~/llm and is run
# from there (~/llm/llm …). The ONLY file placed outside is the opencode config
# copy at ~/.config/opencode (opencode reads its config only from there).
# opencode (the client) comes from Homebrew. Heavy (~30 GB download); run
# explicitly: ./install.sh local-llm
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos; require_brew
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LLM_HOME="$HOME/llm"
VENV="$LLM_HOME/venv"
MODEL_ID="unsloth/Qwen3.6-27B-UD-MLX-6bit"
MODEL_DIR="$LLM_HOME/models/Qwen3.6-27B-UD-MLX-6bit"

# --- Safety gate: never run the heavy parts non-interactively / under --yes ---
if [[ "${DRY_RUN:-0}" == "1" ]]; then
  info "DRY-RUN: showing local-llm actions without prompting."
elif [[ ! -t 0 ]]; then
  warn "local-llm is opt-in (≈30 GB download) and needs an interactive terminal."
  info  "Run it directly:  ./install.sh local-llm"
  exit 0
else
  printf '%s' "This downloads ~30 GB into ~/llm. Continue? [y/N] "
  read -r _ans
  [[ "$_ans" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
fi

# --- Ensure uv (self-contained: don't assume the cli/agents step ran) ---------
if has uv; then skip "uv"; else info "Installing uv…"; run brew install uv; fi

# --- ~/llm skeleton -----------------------------------------------------------
run mkdir -p "$LLM_HOME/models" "$LLM_HOME/state"

# --- Python venv INSIDE ~/llm with the runtime + downloader -------------------
if [[ -x "$VENV/bin/rapid-mlx" ]]; then
  skip "rapid-mlx venv ($VENV)"
else
  info "Creating Python venv at $VENV …"
  run uv venv "$VENV"
  info "Installing rapid-mlx + huggingface_hub into the venv…"
  run uv pip install --python "$VENV/bin/python" rapid-mlx huggingface_hub
fi

# --- Client (opencode via Homebrew) -------------------------------------------
if brew_has_formula opencode; then skip "opencode"; else info "Installing opencode…"; run brew install opencode; fi

# --- Control script + config, copied INTO ~/llm (self-contained) --------------
run cp "$ROOT/bin/llm" "$LLM_HOME/llm"
run chmod +x "$LLM_HOME/llm"
run cp "$ROOT/config/opencode/opencode.json" "$LLM_HOME/opencode.json"

# --- Deploy the opencode config (the ONE unavoidable external file) -----------
# Nothing else leaves ~/llm — run the control script as ~/llm/llm. opencode only
# ever reads its config from ~/.config/opencode, so we copy it there; edit
# ~/llm/opencode.json and `~/llm/llm sync` (or `start`) re-copies it.
run mkdir -p "$HOME/.config/opencode"
backup_path "$HOME/.config/opencode/opencode.json" "$ROOT"
run cp "$LLM_HOME/opencode.json" "$HOME/.config/opencode/opencode.json"
ok "opencode config deployed (edit $LLM_HOME/opencode.json, then '$LLM_HOME/llm sync')"

# --- Model weights (~30 GB, idempotent) into ~/llm/models ---------------------
if [[ -d "$MODEL_DIR" && -n "$(ls -A "$MODEL_DIR" 2>/dev/null)" ]]; then
  skip "model already present ($MODEL_DIR)"
else
  info "Downloading $MODEL_ID (~30 GB) → $MODEL_DIR …"
  run "$VENV/bin/hf" download "$MODEL_ID" --local-dir "$MODEL_DIR"
fi

# --- GPU wired limit: optional, no daemon (100k fits the default ~36 GiB cap) --
info "Optional: for very long contexts you can raise the GPU wired limit"
info "(needs sudo, resets on reboot):  sudo sysctl -w iogpu.wired_limit_mb=36864"

step "local-llm summary — everything under $LLM_HOME"
ok   "runtime : $VENV/bin/rapid-mlx"
ok   "model   : $MODEL_DIR"
ok   "config  : $LLM_HOME/opencode.json  (copied to ~/.config/opencode; '~/llm/llm sync' to re-deploy)"
ok   "control : run it from ~/llm — ${C_BOLD}~/llm/llm start | status | stop | sync${C_RESET}"
info "Start it: ${C_BOLD}cd $LLM_HOME && ./llm start${C_RESET}   then run ${C_BOLD}opencode${C_RESET} in a project."
