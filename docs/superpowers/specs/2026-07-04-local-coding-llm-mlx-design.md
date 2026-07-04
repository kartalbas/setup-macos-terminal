# Local coding LLM (MLX) — design

**Date:** 2026-07-04
**Status:** Approved design, pending user review → implementation plan
**Target:** Apple Silicon macOS, 48 GB unified memory, opencode as the only client.

This design adds a **local, offline coding LLM** to the `setup-macos-terminal`
installer as an opt-in step, mirroring the existing modular pattern
(`scripts/NN-*.sh` + `STEPS` array + `Brewfile` + `90-link-configs.sh`).

Every hard number and CLI detail below was fact-checked against primary sources
(Hugging Face `config.json`, the Rapid-MLX README, opencode docs, MLX issue
tracker). Corrections from that review are baked in.

---

## 1. Goal & scope

- Run a strong dense coding model **fully locally** on a 48 GB Mac, driven by
  **opencode** (no other client).
- **100k token context is a hard requirement** for sustained use.
- Start/stop on demand so the ~33 GiB footprint is only paid while coding.
- Integrate cleanly and safely into the existing installer (opt-in, no
  surprise 30 GB downloads, no unsafe `sudo` in unattended runs).

**Non-goals**

- 262k context on 48 GB — verified to need ~37.3 GiB and exceed the safe GPU
  wired cap; explicitly out of scope on this machine (see §5, §9).
- Vision/multimodal use — the model is VL-capable but we serve **text only**.
- Any always-on/autostart service by default.

---

## 2. Chosen stack (decisions)

| Layer | Decision | Notes |
|-------|----------|-------|
| **Model** | **Qwen3.6-27B**, dense, coding-focused (SWE-bench Verified 77.2%, vendor-reported) | Hybrid attention: 64 layers = **16 full-attention + 48 Gated-DeltaNet** (linear). It is a **vision-language checkpoint** (`Qwen3_5ForConditionalGeneration`, `language_model_only=false`) served **text-only**. |
| **Quant** | **`unsloth/Qwen3.6-27B-UD-MLX-6bit`** (Unsloth Dynamic 6-bit MLX) | 6 safetensors shards = **30.5 GB** on disk (real size; UD keeps embeddings/some layers at higher precision + includes the small vision tower). Never 4-bit. |
| **Runtime** | **Rapid-MLX** | OpenAI-compatible `/v1`; purpose-built opencode tool-calling (17 parsers + recovery). Ships explicit `qwen3.6-27b-*` aliases → Qwen3.6-27B is a supported text-serve target. |
| **KV cache** | **TurboQuant `k8v4`** (keys 8-bit, values 4-bit) | Serving-layer KV compression (Google/PolarQuant), orthogonal to the 6-bit weights. Applies **only to the 16 full-attention layers**; DeltaNet state untouched. |
| **Context** | **100k**, enforced **client-side** in `opencode.json` | Rapid-MLX has no `--max-context` flag; the model config allows 262k, so the ceiling must be set in opencode. |
| **Memory safety** | Wired cap **36 GiB** + `--gpu-memory-utilization 0.75` | Lower than the earlier 40 GiB (panic-safety, see §5/§9). |
| **Client** | **opencode** only | Points at the local endpoint. |
| **Server lifecycle** | **On-demand** `llm start/stop/status` | ~33 GiB only while running; freed on stop. |

---

## 3. Components & new repo files

| # | Component | Install / source | New file(s) |
|---|-----------|------------------|-------------|
| A | **Rapid-MLX** runtime | **`uv tool install rapid-mlx`** (verified PyPI pkg; matches repo's `uv tool` pattern). *Not* `brew install rapid-mlx` — not in homebrew-core. | `scripts/60-local-llm.sh` |
| B | **opencode** client | `brew "opencode"` (official homebrew-core formula ✓) → add to Brewfile | Brewfile section |
| C | **hf** downloader | `uv tool install huggingface_hub` → provides `hf` | (in step 60) |
| D | **Model** weights (~30.5 GB) | `hf download unsloth/Qwen3.6-27B-UD-MLX-6bit --local-dir ~/models/...` **or** let Rapid-MLX cache it — **one store only** (§7) | downloaded, git-ignored |
| E | **GPU wired-limit** LaunchDaemon (36 GiB) | plist → `/Library/LaunchDaemons` (root, interactive-only) | `config/system/com.setup.iogpu-wired-limit.plist` |
| F | **`llm` control script** (start/stop/status) | on-demand launcher w/ PID file | `bin/llm` |
| G | **opencode config** → local endpoint | committed standard config, symlinked | `config/opencode/opencode.json` |
| H | Installer wiring | new step, README row, Brewfile section | edits to `install.sh`, `README.md`, `Brewfile` |

---

## 4. Verified memory budget (100k context)

Physical RAM is binary: **48 GB = 48 GiB**. All figures in GiB (2³⁰).

| Component | GiB | Basis |
|-----------|----:|-------|
| Weights (6-bit UD) | **28.41** | 30.502 GB disk (exact shard bytes) ÷ 2³⁰; mmap'd as-is |
| TurboQuant K8V4 KV @100k | **2.48** | 16 full layers × 4 kv-heads × 256 × (1 B K + 0.5 B V) = 24,576 B/tok × 100k + ~0.19 overhead |
| DeltaNet recurrent state | **0.14** | 48 layers × 48 v-heads × 128 × 128 × 4 B (fp32); **constant**, context-independent |
| Activations (chunked prefill) | **~1.5** | estimate, range 0.3–2.5; last-token logits only |
| Runtime overhead | **~0.8** | measured ~0.2–0.4 idle, ≤0.8 under load |
| **Model process @100k** | **≈ 33.3** | fits under 36 GiB wired cap (~2.7 GiB margin); leaves **14.7 GiB** of 48 for macOS + apps |

- Per-token KV under k8v4 ≈ **24 KiB/token** → each +10k context ≈ +0.25 GiB.
- **262k** would be ~37.3 GiB → **exceeds the 36 GiB cap** → out of scope (§9).

The core arithmetic was independently reproduced and confirmed; the only soft
terms (activations, runtime overhead) are non-load-bearing at 100k given the
headroom, and are to be measured empirically at build time.

---

## 5. macOS GPU wired limit (safety-critical)

`iogpu.wired_limit_mb` raises the ceiling of GPU-wired memory Metal may
allocate (value in MiB; **it does not reserve RAM**). Default on a 48 GB Mac is
~34–36 GiB (macOS-version-sensitive; a fresh machine reads `0` = "use default
policy", not the effective value).

**Decision: cap at `36864` (36 GiB), not 40960 (40 GiB).**
Rationale: 40/48 GiB ≈ 83 % wired matches the exact profile of a **documented,
unrecoverable kernel panic** (mlx-lm #883) — wired memory bypasses macOS memory-
pressure handling, so over-allocation panics rather than OOM-recovers. Accepted
headroom guidance is 12–16 GiB, not 8. 36 GiB still comfortably fits the 33.3 GiB
100k footprint.

**Defense in depth (both applied):**
1. **Client-side context cap = 100k** in `opencode.json` → bounds KV growth (the
   real panic trigger is a runaway prefill; mlx #3186 panics from a single large
   prefill even under the cap).
2. **`--gpu-memory-utilization 0.75`** on the server → runtime hard-bound on
   device memory (Rapid-MLX exposes no `--max-kv-size`, but this flag serves the
   same purpose).

**Persistence:** the sysctl resets on reboot and `/etc/sysctl.conf` is not
honored on Apple Silicon → a root **LaunchDaemon** with `RunAtLoad`:

```xml
<!-- /Library/LaunchDaemons/com.setup.iogpu-wired-limit.plist  (root:wheel 0644) -->
<key>ProgramArguments</key>
<array>
  <string>/usr/sbin/sysctl</string>
  <string>-w</string>
  <string>iogpu.wired_limit_mb=36864</string>
</array>
<key>RunAtLoad</key><true/>
```

Load with `sudo launchctl bootstrap system /Library/LaunchDaemons/com.setup.iogpu-wired-limit.plist`
(the legacy `launchctl load` is deprecated on Sonoma+). Revert with
`sudo sysctl iogpu.wired_limit_mb=0`.

---

## 6. Runtime invocation & control script

**Correct serve command** (verified against the Rapid-MLX README — the earlier
`--model`/`--max-context`/port-5413 form was wrong):

```bash
rapid-mlx serve unsloth/Qwen3.6-27B-UD-MLX-6bit \
  --port 5413 \
  --kv-cache-turboquant k8v4 \
  --gpu-memory-utilization 0.75
```

- Model is a **positional** arg (HF id, local path, or alias) — no `--model`.
- `--kv-cache-turboquant` **requires a value**; `k8v4` is lowercase and must be
  **explicit** (the 27B is not one of the 9 default-on aliases, so k8v4 is not
  auto-enabled and is **not vendor-validated** for it → test tool-calls; fall
  back to `none` = fp16 KV if JSON tool-calls break).
- **No `--max-context`** exists (`--max-tokens` caps *output*, default 32768) —
  context is capped client-side.
- `--port 5413` overrides the default **8000**; it must match opencode's
  `baseURL` exactly (§8).

**`bin/llm` control script** — subcommands `start | stop | status | restart | logs`:

- `start`: verify wired limit is set (warn if not), launch server via `nohup`
  with a PID file under `~/.local/state/llm/`.
- `stop`: `kill` (SIGTERM) → **SIGKILL fallback** after timeout → RAM freed by
  the kernel immediately (no separate free step).
- `status`: report liveness (`kill -0` + PID-file **command-name match** to
  avoid PID reuse) and memory via **`footprint <pid>` / phys_footprint**, *not*
  `ps -o rss=` (RSS underreports unified/GPU memory).

Keep all runtime flags in **one place** in this script.

---

## 7. Model download & storage (single store)

Pick **one** store to avoid a duplicate ~30 GB copy (`--local-dir` does not
dedup against the HF hub cache):

- **Option A (default):** `hf download unsloth/Qwen3.6-27B-UD-MLX-6bit
  --local-dir ~/models/Qwen3.6-27B-UD-MLX-6bit`, then serve that **local path**.
- **Option B:** skip the explicit download and let `rapid-mlx serve <hf-id>`
  manage it in the HF cache (`HF_HOME` to relocate off the boot volume).

Download is **idempotent** (skip if present). Note the Rapid-MLX `qwen3.6-27b-ud`
alias is *not guaranteed* to equal the exact 6-bit build → always pass the
explicit HF id / local path.

---

## 8. opencode configuration

Global config `~/.config/opencode/opencode.json` (symlinked from
`config/opencode/opencode.json`; no secrets → committed as a standard config):

```jsonc
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

- **Port 5413 must match** the server's `--port` (default would be 8000).
- A bare `baseURL` is insufficient — the full `provider` block **and** top-level
  `"model"` selector are required. `apiKey` optional for local (set a dummy if
  `@ai-sdk/openai-compatible` complains).
- The exact model id must match what the server reports.
- Alternative: `rapid-mlx agents opencode --setup` can auto-write a matching
  config — use it to cross-check the hand-written file.

---

## 9. Installer integration

**New step `local-llm` (`scripts/60-local-llm.sh`), placed after `agents`.**

**Excluded from both `all` and `core`** — runnable only via explicit
`./install.sh local-llm`. Rationale: the repo's `confirm()` auto-returns *yes*
under `ASSUME_YES=1`, so leaving `local-llm` in `all` would make
`./install.sh all --yes` silently trigger a 30 GB download + `sudo sysctl` +
LaunchDaemon install. Implementation: keep it out of the `all`/`core`
enumerations (or special-case `all` to skip it); still listed in the menu and
dispatchable by name.

Step script requirements:
1. `require_macos; require_brew`; **ensure `uv`** itself (install if missing) so
   a standalone run doesn't depend on step 50 having run.
2. Big-download **confirm gate** that **defaults to NO under non-interactive /
   non-TTY** (do *not* honor `ASSUME_YES` for the destructive parts).
3. Wrap **every** heavy action (`hf download`, `uv tool install`, `sudo sysctl`,
   `launchctl`) in the repo's `run` helper → true `--dry-run` no-op.
4. `sudo`/LaunchDaemon actions are **interactive-only**; when non-interactive,
   print the manual `sudo` command instead of blocking.
5. Link `config/opencode/opencode.json` via `90-link-configs.sh`.

Ordering (step 60 after 50) is correct; `all` won't run it anyway.

---

## 10. Build-time verification checklist

Facts that docs could not fully close — verify on the real machine before
declaring done:

- [ ] `rapid-mlx serve unsloth/Qwen3.6-27B-UD-MLX-6bit …` **actually loads** the
      VL checkpoint text-only (mlx-lm vs mlx-vlm). If it fails, fall back to the
      `qwen3.6-27b-ud` alias or `-8bit`, or `pip install 'rapid-mlx[vision]'`.
- [ ] `rapid-mlx serve --help` — confirm final flag names/defaults
      (`--kv-cache-turboquant k8v4`, `--gpu-memory-utilization`, `--port`).
- [ ] End-to-end **tool-calling in opencode** works with `k8v4` (edit/read/bash
      tools produce valid JSON). If flaky → `--kv-cache-turboquant none`.
- [ ] Measured process footprint at 100k stays < 36 GiB (`footprint`/Activity
      Monitor); confirm no kernel-panic under a full 100k prefill.
- [ ] Rapid-MLX tap/install method current (`uv tool install rapid-mlx`).

---

## 11. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| VL checkpoint won't load text-only under mlx-lm | Alias fallback (`qwen3.6-27b-ud`/`-8bit`) or `rapid-mlx[vision]`; verified at build time (§10) |
| Kernel panic from wired over-allocation | 36 GiB cap + 100k client context cap + `--gpu-memory-utilization 0.75` (§5) |
| k8v4 breaks JSON tool-calls on 27B (unvalidated) | Parser recovery + fallback to `none` (fp16 KV) |
| `all --yes` triggers 30 GB download/sudo | Step excluded from `all`/`core`; confirm defaults NO non-interactively (§9) |
| Port mismatch → dead endpoint | Single source of truth; server `--port 5413` == opencode `baseURL` |
| Duplicate 30 GB model copies | One store only (§7) |

---

## 12. File manifest

```
scripts/60-local-llm.sh                              # new step (A,C,D,E,F wiring)
bin/llm                                              # start/stop/status control (F)
config/opencode/opencode.json                        # client config (G)
config/system/com.setup.iogpu-wired-limit.plist      # wired-limit daemon (E)
install.sh                                            # + STEPS entry, exclude from all/core
Brewfile                                              # + "Local LLM" section (opencode)
README.md                                             # + local-llm row
scripts/90-link-configs.sh                            # + link opencode.json
```
