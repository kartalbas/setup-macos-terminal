# Local coding LLM (MLX) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in `local-llm` installer step that runs Qwen3.6-27B (6-bit MLX) locally via Rapid-MLX and drives it from opencode at 100k context, with an on-demand start/stop control script.

**Architecture:** A new `scripts/60-local-llm.sh` step installs the Rapid-MLX runtime (via `uv tool`), the opencode client (via Homebrew), downloads the model, links a committed opencode config, installs a `bin/llm` start/stop/status control script, and optionally installs a LaunchDaemon that raises the macOS GPU wired limit. The step is excluded from `all`/`core` and gated so a 30 GB download never happens non-interactively.

**Tech Stack:** bash, Homebrew, `uv tool`, Hugging Face `hf` CLI, Rapid-MLX (PyPI), opencode, macOS `launchd` + `sysctl`, MLX/Metal.

## Global Constraints

Copied verbatim from the design spec (`docs/superpowers/specs/2026-07-04-local-coding-llm-mlx-design.md`). Every task's requirements implicitly include these:

- **Platform:** Apple Silicon macOS, 48 GB unified memory. Client is **opencode only**.
- **Model:** `unsloth/Qwen3.6-27B-UD-MLX-6bit` (dense, 6-bit MLX, ~30.5 GB, VL checkpoint served **text-only**). Never 4-bit.
- **Runtime:** Rapid-MLX via **`uv tool install rapid-mlx`** — NOT `brew install rapid-mlx` (not in homebrew-core).
- **opencode:** via **`brew install opencode`** (homebrew-core).
- **Downloader:** `hf` from **`uv tool install huggingface_hub`**.
- **Serve command (exact):** `rapid-mlx serve <model-path> --port 5413 --kv-cache-turboquant k8v4 --gpu-memory-utilization 0.75`. Model is **positional** (no `--model`). `--kv-cache-turboquant` requires the value `k8v4` (lowercase, explicit — not default-on for the 27B). There is **no `--max-context`** flag.
- **Context ceiling:** 100k, enforced **client-side** in `opencode.json` via `"limit": { "context": 100000 }`.
- **GPU wired limit:** **36 GiB = `36864` MiB** (not 40960). Persisted by a root LaunchDaemon.
- **Runtime memory bound:** `--gpu-memory-utilization 0.75`.
- **Port:** `5413` must match end-to-end (server `--port` == opencode `baseURL`).
- **Model store:** ONE location — `~/models/Qwen3.6-27B-UD-MLX-6bit`. Serve from that local path.
- **Installer safety:** step **excluded from `all` and `core`**; runnable only via explicit `./install.sh local-llm`. Destructive actions default to **NO** when non-interactive; every heavy action wrapped in the repo's `run` helper for true `--dry-run`; `sudo`/LaunchDaemon actions interactive-only.
- **Repo helpers** (from `lib/common.sh`): `run`, `step`, `info`, `ok`, `warn`, `err`, `skip`, `has`, `confirm`, `require_macos`, `require_brew`, `brew_has_formula`, `backup_path`. Colors: `$C_BOLD $C_DIM $C_RESET` etc.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `config/opencode/opencode.json` | opencode client config → local Rapid-MLX endpoint, 100k context cap. Standard config, symlinked. |
| `config/system/com.setup.iogpu-wired-limit.plist` | LaunchDaemon: set `iogpu.wired_limit_mb=36864` at boot. |
| `bin/llm` | On-demand server control: `start`/`stop`/`status`/`restart`/`logs`. One place for runtime flags. |
| `scripts/60-local-llm.sh` | The installer step: runtime + client + model + config link + control-script link + wired-limit daemon. Self-contained. |
| `install.sh` | Register `local-llm` in `STEPS`, exclude from the `all` group. |
| `Brewfile` | Document the opt-in `opencode` dependency (+ note rapid-mlx via uv). |
| `README.md` | Add the `local-llm` step row + a short usage note. |

Tasks are ordered so each produces an independently testable artifact before the artifacts that consume it.

---

### Task 1: opencode client config

**Files:**
- Create: `config/opencode/opencode.json`

**Interfaces:**
- Produces: a config consumed by opencode at `~/.config/opencode/opencode.json` (symlinked in Task 4). Defines provider id `local` → `http://localhost:5413/v1`, model `local/unsloth/Qwen3.6-27B-UD-MLX-6bit`, context limit `100000`.

- [ ] **Step 1: Write the validation check (expect failure)**

Run: `jq . config/opencode/opencode.json`
Expected: FAIL — `jq: error: Could not open ... No such file or directory`

- [ ] **Step 2: Create the config**

`config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "local": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Rapid-MLX (local)",
      "options": { "baseURL": "http://localhost:5413/v1" },
      "models": { "unsloth/Qwen3.6-27B-UD-MLX-6bit": {} }
    }
  },
  "model": "local/unsloth/Qwen3.6-27B-UD-MLX-6bit",
  "limit": { "context": 100000 }
}
```

- [ ] **Step 3: Verify it is valid JSON and has the required values**

Run:
```bash
jq -e '.provider.local.options.baseURL == "http://localhost:5413/v1" and .limit.context == 100000 and .model == "local/unsloth/Qwen3.6-27B-UD-MLX-6bit"' config/opencode/opencode.json
```
Expected: PASS — prints `true`, exit 0.

- [ ] **Step 4: Commit**

```bash
git add config/opencode/opencode.json
git commit -m "feat(local-llm): opencode config pointing at local Rapid-MLX endpoint"
```

---

### Task 2: GPU wired-limit LaunchDaemon

**Files:**
- Create: `config/system/com.setup.iogpu-wired-limit.plist`

**Interfaces:**
- Produces: a LaunchDaemon plist installed (by Task 4) to `/Library/LaunchDaemons/com.setup.iogpu-wired-limit.plist` that runs `/usr/sbin/sysctl -w iogpu.wired_limit_mb=36864` at load.

- [ ] **Step 1: Write the validation check (expect failure)**

Run: `plutil -lint config/system/com.setup.iogpu-wired-limit.plist`
Expected: FAIL — `... No such file or directory`

- [ ] **Step 2: Create the plist**

`config/system/com.setup.iogpu-wired-limit.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.setup.iogpu-wired-limit</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/sbin/sysctl</string>
    <string>-w</string>
    <string>iogpu.wired_limit_mb=36864</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardErrorPath</key>
  <string>/var/log/iogpu-wired-limit.err</string>
</dict>
</plist>
```

- [ ] **Step 3: Verify it lints and carries the right value**

Run:
```bash
plutil -lint config/system/com.setup.iogpu-wired-limit.plist && \
grep -q 'iogpu.wired_limit_mb=36864' config/system/com.setup.iogpu-wired-limit.plist && echo OK
```
Expected: PASS — `... OK` and `OK`.

- [ ] **Step 4: Commit**

```bash
git add config/system/com.setup.iogpu-wired-limit.plist
git commit -m "feat(local-llm): LaunchDaemon to persist 36 GiB GPU wired limit"
```

---

### Task 3: `bin/llm` control script

**Files:**
- Create: `bin/llm`

**Interfaces:**
- Consumes: `rapid-mlx` on PATH; model at `$HOME/models/Qwen3.6-27B-UD-MLX-6bit`.
- Produces: CLI `llm {start|stop|status|restart|logs}`. Overridable env: `LLM_MODEL`, `LLM_PORT` (default 5413), `LLM_GPU_UTIL` (0.75), `LLM_KV` (k8v4). Writes `~/.local/state/llm/server.pid` and `server.log`.

- [ ] **Step 1: Write the syntax + behavior check (expect failure)**

Run: `bash -n bin/llm`
Expected: FAIL — `bash: bin/llm: No such file or directory`

- [ ] **Step 2: Create the control script**

`bin/llm`:

```bash
#!/usr/bin/env bash
# llm — control the local coding LLM (Rapid-MLX server); frees RAM on stop.
#   llm start | stop | status | restart | logs
set -euo pipefail

MODEL="${LLM_MODEL:-$HOME/models/Qwen3.6-27B-UD-MLX-6bit}"
PORT="${LLM_PORT:-5413}"
GPU_UTIL="${LLM_GPU_UTIL:-0.75}"
KV="${LLM_KV:-k8v4}"                 # k8v4 | v4 | none
WIRED_MIN_MB=36864                   # LaunchDaemon should have set this
STATE_DIR="$HOME/.local/state/llm"
PIDFILE="$STATE_DIR/server.pid"
LOG="$STATE_DIR/server.log"
PROC_MATCH="rapid-mlx"               # substring to confirm PID identity (reuse guard)

c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_err=$'\033[31m'; c_dim=$'\033[2m'; c_rst=$'\033[0m'
msg() { printf '%s\n' "$*"; }

_alive() {  # $1=pid ; true if running AND its command matches PROC_MATCH
  local pid="${1:-}"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null || return 1
  ps -p "$pid" -o command= 2>/dev/null | grep -q "$PROC_MATCH"
}

_running_pid() {  # echoes live pid, or returns 1 (clearing a stale pidfile)
  [[ -f "$PIDFILE" ]] || return 1
  local pid; pid="$(cat "$PIDFILE" 2>/dev/null || true)"
  if _alive "$pid"; then printf '%s' "$pid"; return 0; fi
  rm -f "$PIDFILE"; return 1
}

_mem_gib() {  # $1=pid ; prefer phys_footprint (Activity-Monitor number), fallback rss
  local pid="$1" kb
  kb="$(/usr/bin/footprint -p "$pid" 2>/dev/null | awk -F'[^0-9]+' '/phys_footprint/{print $2; exit}')" || true
  if [[ -n "${kb:-}" ]]; then awk -v k="$kb" 'BEGIN{printf "%.1f GiB", k/1024/1024}'; return; fi
  kb="$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')"
  [[ -n "$kb" ]] && awk -v k="$kb" 'BEGIN{printf "%.1f GiB (rss)", k/1024/1024}' || printf '?'
}

cmd_start() {
  local pid
  if pid="$(_running_pid)"; then
    msg "${c_ok}already running${c_rst} (pid $pid) — http://localhost:$PORT/v1"; return 0
  fi
  local wired; wired="$(sysctl -n iogpu.wired_limit_mb 2>/dev/null || echo 0)"
  if [[ "${wired:-0}" -lt "$WIRED_MIN_MB" ]]; then
    msg "${c_warn}!${c_rst} GPU wired limit is ${wired} MiB (< ${WIRED_MIN_MB}); LaunchDaemon not active?"
    msg "  ${c_dim}sudo sysctl -w iogpu.wired_limit_mb=${WIRED_MIN_MB}${c_rst}"
  fi
  [[ -e "$MODEL" ]] || { msg "${c_err}✗${c_rst} model not found: $MODEL"; return 1; }
  command -v rapid-mlx >/dev/null || { msg "${c_err}✗${c_rst} rapid-mlx not on PATH"; return 1; }
  mkdir -p "$STATE_DIR"
  msg "starting rapid-mlx (model loads ~33 GiB)…"
  nohup rapid-mlx serve "$MODEL" \
      --port "$PORT" \
      --kv-cache-turboquant "$KV" \
      --gpu-memory-utilization "$GPU_UTIL" \
      >"$LOG" 2>&1 &
  echo $! > "$PIDFILE"
  msg "  pid $(cat "$PIDFILE") · logs: ${c_dim}llm logs${c_rst} · check: ${c_dim}llm status${c_rst}"
}

cmd_stop() {
  local pid
  if ! pid="$(_running_pid)"; then msg "not running"; return 0; fi
  msg "stopping (pid $pid)…"
  kill "$pid" 2>/dev/null || true
  local i
  for i in $(seq 1 20); do _alive "$pid" || break; sleep 0.5; done
  if _alive "$pid"; then msg "${c_warn}!${c_rst} unresponsive → SIGKILL"; kill -9 "$pid" 2>/dev/null || true; sleep 1; fi
  rm -f "$PIDFILE"
  msg "${c_ok}stopped — RAM freed${c_rst}"
}

cmd_status() {
  local pid
  if pid="$(_running_pid)"; then
    msg "${c_ok}running${c_rst} (pid $pid) · mem $(_mem_gib "$pid") · http://localhost:$PORT/v1"
  else
    msg "${c_dim}stopped (0 GiB)${c_rst}"
  fi
}

case "${1:-status}" in
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  status)  cmd_status ;;
  restart) cmd_stop; sleep 1; cmd_start ;;
  logs)    tail -f "$LOG" ;;
  *)       msg "usage: llm {start|stop|status|restart|logs}"; exit 2 ;;
esac
```

- [ ] **Step 3: Make executable and verify syntax + the no-server code paths**

Run:
```bash
chmod +x bin/llm
bash -n bin/llm && echo SYNTAX_OK
LLM_MODEL=/nonexistent bin/llm status         # exercises the 'stopped' path
bin/llm bogus; echo "exit=$?"                  # usage + exit 2
```
Expected:
- `SYNTAX_OK`
- `stopped (0 GiB)`
- `usage: llm {start|stop|status|restart|logs}` then `exit=2`

(Do NOT run `llm start` here — it would trigger the 30 GB load. Real start is covered in Task 7 on the target Mac.)

- [ ] **Step 4: Commit**

```bash
git add bin/llm
git commit -m "feat(local-llm): llm start/stop/status control script"
```

---

### Task 4: `scripts/60-local-llm.sh` installer step

**Files:**
- Create: `scripts/60-local-llm.sh`

**Interfaces:**
- Consumes: `lib/common.sh` helpers; `config/opencode/opencode.json` (Task 1); `config/system/com.setup.iogpu-wired-limit.plist` (Task 2); `bin/llm` (Task 3).
- Produces: installs `rapid-mlx` + `hf` (uv), `opencode` (brew); downloads model to `~/models/Qwen3.6-27B-UD-MLX-6bit`; symlinks `bin/llm`→`~/.local/bin/llm` and `opencode.json`→`~/.config/opencode/opencode.json`; installs+loads the LaunchDaemon. Self-contained (does not assume other steps ran).

- [ ] **Step 1: Write the dry-run check (expect failure)**

Run: `DRY_RUN=1 bash scripts/60-local-llm.sh </dev/null`
Expected: FAIL — `bash: scripts/60-local-llm.sh: No such file or directory`

- [ ] **Step 2: Create the step script**

`scripts/60-local-llm.sh`:

```bash
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
```

- [ ] **Step 3: Verify syntax, then dry-run shows the heavy actions without executing**

Run:
```bash
bash -n scripts/60-local-llm.sh && echo SYNTAX_OK
DRY_RUN=1 bash scripts/60-local-llm.sh </dev/null 2>&1 | tee /tmp/llm-dry.txt
grep -Eq 'uv tool install rapid-mlx' /tmp/llm-dry.txt \
  && grep -Eq 'hf download unsloth/Qwen3.6-27B-UD-MLX-6bit --local-dir' /tmp/llm-dry.txt \
  && grep -Eq 'brew install opencode' /tmp/llm-dry.txt \
  && grep -Eq 'iogpu.wired_limit_mb=36864' /tmp/llm-dry.txt \
  && echo DRYRUN_OK
```
Expected: `SYNTAX_OK`, the dry-run action list, then `DRYRUN_OK`. Nothing is actually installed/downloaded (the `run` helper prints under `DRY_RUN=1`). The interactive gate is skipped because `DRY_RUN=1`.

- [ ] **Step 4: Verify the non-interactive safety gate refuses to run heavy actions**

Run:
```bash
bash scripts/60-local-llm.sh </dev/null 2>&1 | tee /tmp/llm-noninteractive.txt
grep -q 'needs an interactive terminal' /tmp/llm-noninteractive.txt \
  && ! grep -q 'hf download' /tmp/llm-noninteractive.txt && echo GATE_OK
```
Expected: `GATE_OK` — with stdin not a TTY and `DRY_RUN` unset, the step exits early and never reaches the download.

- [ ] **Step 5: Commit**

```bash
git add scripts/60-local-llm.sh
git commit -m "feat(local-llm): self-contained installer step (runtime, model, config, daemon)"
```

---

### Task 5: Register the step in `install.sh` (excluded from `all`)

**Files:**
- Modify: `install.sh:29` (add `STEPS` entry after `agents`)
- Modify: `install.sh:76` (skip `local-llm` in the `all` group)

**Interfaces:**
- Consumes: `scripts/60-local-llm.sh` (Task 4).
- Produces: `./install.sh local-llm` dispatches the step; `./install.sh --help` lists it; `./install.sh all` and `core` do **not** run it.

- [ ] **Step 1: Write the checks (expect failure)**

Run:
```bash
./install.sh --help 2>&1 | grep -q 'local-llm' && echo LISTED || echo "NOT LISTED (expected before edit)"
```
Expected: `NOT LISTED (expected before edit)`

- [ ] **Step 2: Add the `STEPS` entry**

In `install.sh`, the `STEPS` array currently ends:

```bash
  "agents|50-coding-agents.sh|Claude Code + runtimes (node, uv) — local"
  "link|90-link-configs.sh|Symlink dotfiles (backs up existing)"
)
```

Insert the `local-llm` line between `agents` and `link`:

```bash
  "agents|50-coding-agents.sh|Claude Code + runtimes (node, uv) — local"
  "local-llm|60-local-llm.sh|(opt-in, ~30GB) Local coding LLM: Qwen3.6-27B MLX + Rapid-MLX + opencode"
  "link|90-link-configs.sh|Symlink dotfiles (backs up existing)"
)
```

- [ ] **Step 3: Exclude `local-llm` from the `all` group**

In `run_group()`, change the `all)` line:

```bash
    all)    for s in "${STEPS[@]}"; do run_step "${s%%|*}"; done ;;
```

to skip the opt-in step:

```bash
    all)    for s in "${STEPS[@]}"; do
              key="${s%%|*}"; [[ "$key" == "local-llm" ]] && continue
              run_step "$key"
            done ;;
```

(`core` already lists its steps explicitly and does not include `local-llm`, so it needs no change.)

- [ ] **Step 4: Verify listing, dispatch, and exclusion**

Run:
```bash
bash -n install.sh && echo SYNTAX_OK
./install.sh --help 2>&1 | grep -q 'local-llm' && echo LISTED
# exclusion: the all-group loop must skip local-llm
grep -A3 'all)    for s in' install.sh | grep -q 'local-llm.*continue' && echo EXCLUDED
# dispatch: the step is reachable and dry-runs (stdin not a tty -> its own gate exits cleanly)
DRY_RUN=1 ./install.sh local-llm </dev/null 2>&1 | grep -q 'DRY-RUN: showing local-llm' && echo DISPATCHED
```
Expected: `SYNTAX_OK`, `LISTED`, `EXCLUDED`, `DISPATCHED`.

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "feat(local-llm): register step, keep it out of the all/core groups"
```

---

### Task 6: Brewfile + README documentation

**Files:**
- Modify: `Brewfile` (append a "Local coding LLM (opt-in)" section)
- Modify: `README.md` (add the `local-llm` row + a usage note)

**Interfaces:**
- Consumes: nothing at runtime — documentation only.
- Produces: `opencode` documented in the manifest; users learn `./install.sh local-llm` and `llm start`.

- [ ] **Step 1: Write the check (expect failure)**

Run: `grep -q 'local-llm' README.md && grep -q 'opencode' Brewfile && echo DOCS_OK || echo "MISSING (expected before edit)"`
Expected: `MISSING (expected before edit)`

- [ ] **Step 2: Append the Brewfile section**

At the end of `Brewfile`, add:

```ruby
# ─────────────────── Local coding LLM (opt-in) ──────────
# Installed only by `./install.sh local-llm` (never by `all`). opencode is the
# terminal client; the Rapid-MLX runtime + hf downloader are Python CLIs installed
# via `uv tool` inside scripts/60-local-llm.sh (uv tool install rapid-mlx huggingface_hub).
brew "opencode"      # AI coding agent for the terminal → points at the local Rapid-MLX server
```

- [ ] **Step 3: Add the README step row + note**

In `README.md`, in the "What you get" table, add a row after the `agents` row:

```markdown
| **local-llm** | *(opt-in, ~30 GB)* Local coding LLM — **Qwen3.6-27B** (6-bit MLX) served by **Rapid-MLX** + **opencode**, controlled with `llm start`/`llm stop` |
```

Then add this short section after the table:

```markdown
### Local coding LLM (opt-in)

`./install.sh local-llm` installs a fully local coding model (Qwen3.6-27B, 6-bit
MLX) served by Rapid-MLX and driven by opencode at 100k context. It is **not**
part of `all`/`core` (it downloads ~30 GB and can raise the macOS GPU wired
limit via `sudo`). After install:

```bash
llm start      # load the model, serve on http://localhost:5413/v1 (~33 GiB RAM)
opencode       # in any project — uses the local model
llm status     # running? how much RAM?
llm stop       # unload and free the RAM
```
```

- [ ] **Step 4: Verify the docs landed**

Run:
```bash
grep -q '\*\*local-llm\*\*' README.md \
  && grep -q 'llm start' README.md \
  && grep -q 'brew "opencode"' Brewfile \
  && echo DOCS_OK
```
Expected: `DOCS_OK`.

- [ ] **Step 5: Commit**

```bash
git add Brewfile README.md
git commit -m "docs(local-llm): document opt-in step in Brewfile and README"
```

---

### Task 7: On-machine build-time verification (manual gate)

This task runs on the **real 48 GB Apple Silicon Mac** and closes the spec's §10
checklist — the parts that cannot be verified without the 30 GB model and sudo.
It is a verification task: no new files, one commit only if a fallback config
change is needed.

**Files:**
- (Possibly) Modify: `config/opencode/opencode.json` or `bin/llm` defaults if a fallback is required (see steps).

- [ ] **Step 1: Run the step for real**

Run: `./install.sh local-llm`
Answer `y` to the download gate and `y` to the wired-limit prompt.
Expected: rapid-mlx + hf + opencode installed; model at `~/models/Qwen3.6-27B-UD-MLX-6bit`; `sysctl iogpu.wired_limit_mb` reads `36864`.

- [ ] **Step 2: Confirm the runtime flags are current**

Run: `rapid-mlx serve --help`
Expected: confirms `--port`, `--kv-cache-turboquant {k8v4,v4,none}`, `--gpu-memory-utilization`. If any flag name differs, update `bin/llm` accordingly and re-commit Task 3.

- [ ] **Step 3: Confirm the VL checkpoint loads text-only (the open blocker)**

Run: `llm start` then `llm logs` (watch for a successful "listening" line), then `llm status`.
Expected: server reaches `http://localhost:5413/v1`; `llm status` shows running with mem **< 36 GiB**.
If loading fails (VL/`mlx-vlm` vs `mlx-lm`), apply a fallback in order and re-run:
1. serve the Rapid-MLX alias: set `LLM_MODEL=qwen3.6-27b-ud` (or `qwen3.6-27b-8bit`);
2. `uv tool install 'rapid-mlx[vision]'` then retry.
Record the working choice; if `LLM_MODEL` changed, update `bin/llm`'s default and the `models`/`model` ids in `config/opencode/opencode.json`, then commit.

- [ ] **Step 4: Confirm opencode tool-calling with k8v4**

Run: `opencode` in a scratch git project; ask it to read a file and make a one-line edit (exercises read/edit/bash tools).
Expected: tool calls succeed with valid JSON (no malformed-tool-call loops).
If tool calls are flaky, fall back to fp16 KV: `llm stop`, `LLM_KV=none llm start`, retest. If `none` is needed, change `bin/llm`'s `KV` default to `none` and commit.

- [ ] **Step 5: Confirm memory safety at 100k and the installer exclusion**

Run:
```bash
# drive a large context (near 100k) via opencode, then:
llm status                      # mem stays < 36 GiB, no kernel panic
./install.sh all --dry-run </dev/null 2>&1 | grep -c '60-local-llm'   # must print 0
llm stop                        # RAM returns to baseline
```
Expected: memory stays under 36 GiB during a ~100k run; `all --dry-run` count is `0`; after `llm stop` the ~33 GiB is freed.

- [ ] **Step 6: Commit any fallback changes (only if steps 3/4 required them)**

```bash
git add -A
git commit -m "fix(local-llm): apply build-time fallback (model/KV) from on-machine verification"
```

---

## Self-Review

**1. Spec coverage** — every spec section maps to a task:
- Model/quant/runtime/KV/context/memory decisions (spec §2) → Global Constraints + Tasks 1,3,4,7.
- Verified memory budget (§4) → enforced via `--gpu-memory-utilization`, 36 GiB cap, 100k client limit (Tasks 1,2,3,4).
- macOS wired limit + LaunchDaemon + panic-safety 36 GiB (§5) → Tasks 2,4; runtime warning in Task 3.
- Serve command / control script (§6) → Tasks 3,4; flag confirmation in Task 7.
- Model download / single store (§7) → Task 4.
- opencode config (§8) → Task 1; linked in Task 4.
- Installer integration, exclude from all/core, non-TTY gate, dry-run safety (§9) → Tasks 4,5.
- Build-time verification checklist (§10) → Task 7.
- Risks/mitigations (§11) → k8v4→none fallback (Task 7), VL-load fallback (Task 7), port consistency (Tasks 1,3), all/core exclusion (Task 5), single store (Task 4).
- File manifest (§12) → Tasks 1–6 (note: opencode.json is linked by the self-contained step 4, not 90-link-configs.sh — a deliberate refinement so `./install.sh local-llm` works standalone, per §9's self-containment requirement).

**2. Placeholder scan** — no TBD/TODO; every code step contains complete file content or exact edits; test steps give exact commands + expected output. Task 7 is intentionally manual (needs the 30 GB model + sudo) with concrete commands and decision branches, not placeholders.

**3. Type/name consistency** — verified consistent across tasks: model path `~/models/Qwen3.6-27B-UD-MLX-6bit`; port `5413`; KV `k8v4`; `--gpu-memory-utilization 0.75`; wired `36864`; context `100000`; LaunchDaemon label `com.setup.iogpu-wired-limit`; env overrides `LLM_MODEL`/`LLM_PORT`/`LLM_KV`/`LLM_GPU_UTIL`; provider id `local` / model id `local/unsloth/Qwen3.6-27B-UD-MLX-6bit`.
