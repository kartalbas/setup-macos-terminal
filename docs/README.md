# Guide

Everything you need after running the installer, in one page:
[Tools](#tools) · [Shortcuts](#shortcuts) · [Local coding LLM](#local-coding-llm) · [Troubleshooting](#troubleshooting)

---

## Tools

What's installed and how to start it.

### Terminal & shell
| Tool | What it is | Try |
|------|-----------|-----|
| **WezTerm** | GPU terminal; same app/config on macOS & Windows | open it from Spotlight |
| **Starship** | Fast prompt: git, language, k8s context | shown automatically |
| **zsh-autosuggestions** | Grey ghost-text from history | press `→` to accept |
| **zsh-syntax-highlighting** | Colors commands as you type | invalid commands turn red |
| **PowerShell** | Cross-platform shell (`pwsh`) | `pwsh` |
| **Microsoft Edge** | Browser | open from Spotlight |

### Modern CLI
| Tool | Replaces | Try |
|------|----------|-----|
| `eza` | `ls` | `ll`, `lt` |
| `bat` | `cat` | `cat file.go` |
| `rg` (ripgrep) | `grep` | `rg TODO` |
| `fd` | `find` | `fd .lua` |
| `fzf` | — | `Ctrl+R`, `Ctrl+T` |
| `zoxide` | `cd` | `z myproject` |
| `delta` | git pager | `git diff` |
| `lazygit` | git TUI | `lg` |
| `gh` | GitHub CLI | `gh pr list` |
| `tmux` | multiplexer | `tmux` |
| `jq` / `yq` | JSON / YAML | `… \| jq .` |
| `btop` | `top` | `top` |
| `tldr` | man pages | `tldr tar` |

### Languages & runtimes
| Tool | What it is | Try |
|------|-----------|-----|
| **mise** | Polyglot version manager | `mise use node@22 python@3.12` |
| **nvm** | Node Version Manager (per-project node) | `nvm install 22 && nvm use 22` |
| **node** | JS runtime (Claude Code MCP, tooling) | `node -v` |
| **uv** | Fast Python pkg/runtime manager | `uv venv && uv pip install …` |
| **pipx** | Isolated Python CLI apps | `pipx list` |

### DevOps / cloud-native
| Tool | What it is | Try |
|------|-----------|-----|
| `kubectl` (`k`) | Kubernetes CLI (colorized via kubecolor) | `k get pods` |
| `kubectx` / `kubens` | Switch context / namespace | `kctx`, `kns` |
| `helm` | K8s package manager | `helm ls` |
| `k9s` | Cluster TUI | `k9s` |
| `stern` | Multi-pod log tailing | `stern myapp` |
| `kustomize` | K8s config overlays | `kustomize build .` |
| `argocd` | Argo CD GitOps CLI | `argocd version` |
| `vault` | HashiCorp Vault | `vault -version` |
| `terraform` / `tofu` | Infra as code | `terraform -version` |
| `sops` | Encrypted secrets in git | `sops -e secrets.yaml` |
| `dive` | Inspect Docker image layers | `dive <image>` |
| **OrbStack** | Local Docker engine + Kubernetes | launch app, then `docker ps` |

**Cloud CLIs:** `aws` (`aws configure` / `aws sso login`) · `az` (`az login`) · `gcloud` / `gsutil` / `bq` (`gcloud init`) · `gh` (`gh auth login`).

### Coding agents (local)
| Tool | What it is | Try |
|------|-----------|-----|
| **Claude Code** | Anthropic's agentic CLI, in `~/.local/bin` | `claude` in a project |
| **opencode** | Terminal coding agent (drives the [local LLM](#local-coding-llm)) | `opencode` |
| `aider` *(optional)* | Python pair-programming agent | `aider` |
| `gh copilot` *(optional)* | Copilot CLI (gh extension) | `gh copilot suggest "…"` |

The `agents` step also offers a one-time GitHub login (`gh auth login`). Claude Code reads project context from `CLAUDE.md` and can load node-based **MCP servers**.

---

## Shortcuts

WezTerm tuned to feel like Windows Terminal (`Ctrl` / `Ctrl+Shift`). Configured in [`config/wezterm/wezterm.lua`](../config/wezterm/wezterm.lua) — edit and press `Ctrl+Shift+R` to reload, no restart.

| Keys | Action |
|------|--------|
| `Ctrl+C` | Copy **if text selected**, else send SIGINT (Windows-Terminal behavior) |
| `Ctrl+V` / `Ctrl+Shift+C` / `Ctrl+Shift+V` | Paste / explicit copy / explicit paste |
| **Right-click** | Paste — or copy if text is selected |
| `Ctrl+Click` | Open link under cursor |
| `Ctrl+Shift+T` / `Ctrl+Shift+W` | New / close tab |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Next / previous tab |
| `Ctrl+Shift+1..4` | Jump to tab 1–4 |
| `Ctrl+Shift+D` / `Ctrl+Shift+E` | Split right / split down |
| `Ctrl+Shift+←/→/↑/↓` | Move focus between panes |
| `Ctrl+Shift+Z` | Zoom / un-zoom pane |
| `Ctrl+Shift+F` | Find in scrollback |
| `Ctrl+=` / `Ctrl+-` / `Ctrl+0` | Font zoom in / out / reset |
| `Ctrl+Shift+P` / `Ctrl+Shift+R` | Command palette / reload config |
| `Ctrl+R` / `Ctrl+T` / `Alt+C` | fzf: history / file / cd (from zsh + fzf) |
| `→` (right arrow) | Accept the grey autosuggestion |
| `z <partial>` | Jump to a frequent directory (zoxide) |

---

## Local coding LLM

An **opt-in**, fully offline coding model driven by **opencode**. Install with `./install.sh local-llm` (not part of `all`/`core` — it downloads ~30 GB).

- **Model:** Qwen3.6-27B, `unsloth/Qwen3.6-27B-UD-MLX-6bit` (dense, 6-bit MLX; a vision-language checkpoint served text-only).
- **Runtime:** [Rapid-MLX](https://github.com/raullenchai/Rapid-MLX) — OpenAI-compatible server on `http://localhost:5413/v1`, TurboQuant `k8v4` KV cache.
- **Context:** 100k tokens (capped client-side in opencode).
- **Footprint:** ~33 GiB RAM while running (fits a 48 GB Mac); freed on `llm stop`.

### Everything lives in `~/llm`
```
~/llm/
├── llm                              # control script
├── opencode.json                    # config
├── venv/bin/{rapid-mlx,hf}          # Python runtime + downloader
├── models/Qwen3.6-27B-UD-MLX-6bit/  # the model (~30 GB)
└── state/{server.pid,server.log}    # runtime state
```
Only one symlink points outside `~/llm`: `~/.local/bin/llm` (so `llm` is on `PATH`). The opencode config is **not** symlinked — you edit `~/llm/opencode.json` and `llm sync` (or `llm start`) copies it to opencode's fixed path (`~/.config/opencode/opencode.json`). opencode itself is a Homebrew formula.

### Use it
```bash
llm start      # deploy config, load the model, serve on :5413 (~33 GiB RAM)
opencode       # in any project — uses the local model
llm status     # running? how much RAM?
llm sync       # (re)copy ~/llm/opencode.json → ~/.config/opencode after an edit
llm stop       # unload and free the RAM
llm logs       # tail the server log
llm restart
```

### Tune it (env vars, read by `~/llm/llm`)
| Variable | Default | Meaning |
|----------|---------|---------|
| `LLM_MODEL` | `~/llm/models/Qwen3.6-27B-UD-MLX-6bit` | model path or HF id/alias |
| `LLM_PORT` | `5413` | server port (must match opencode's `baseURL`) |
| `LLM_KV` | `k8v4` | TurboQuant KV: `k8v4` \| `v4` \| `none` |
| `LLM_GPU_UTIL` | `0.75` | GPU-memory ceiling (fraction) |

Example: `LLM_KV=none llm start` (fp16 KV, if tool-calls misbehave).

### Config
Edit **`~/llm/opencode.json`** (the source of truth), then run **`llm sync`** to
copy it to `~/.config/opencode/opencode.json` where opencode reads it (`llm start`
also syncs automatically). It registers the `local` provider and the 100k cap:
```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "local": {
      "npm": "@ai-sdk/openai-compatible",
      "options": { "baseURL": "http://localhost:5413/v1" },
      "models": { "unsloth/Qwen3.6-27B-UD-MLX-6bit": { "limit": { "context": 100000, "output": 8192 } } }
    }
  },
  "model": "local/unsloth/Qwen3.6-27B-UD-MLX-6bit"
}
```

### If something's off
- **`llm status` shows `model not found`** — the download didn't finish; re-run `./install.sh local-llm` (idempotent).
- **opencode errors on startup** — the config is invalid JSON or points at the wrong port; check `~/.config/opencode/opencode.json` and that `LLM_PORT` matches its `baseURL`.
- **Model won't load** (VL checkpoint) — fall back to a Rapid-MLX alias: `LLM_MODEL=qwen3.6-27b-ud llm start` (or `qwen3.6-27b-8bit`), or `uv pip install --python ~/llm/venv/bin/python 'rapid-mlx[vision]'`.
- **Tool-calls produce broken JSON** — set `LLM_KV=none` (fp16 KV) and restart.
- **Very long contexts / OOM** — optionally raise the GPU wired limit (needs `sudo`, resets on reboot): `sudo sysctl -w iogpu.wired_limit_mb=36864`.

---

## Troubleshooting

### Icons show as boxes / `?` in the prompt
The terminal font isn't a Nerd Font. Ensure the cask installed, then fully quit and reopen WezTerm:
```bash
brew install --cask font-caskaydia-cove-nerd-font
```

### `Ctrl+C` won't interrupt a running command
By design it copies **only when text is selected**, otherwise sends SIGINT. Clear a stray selection (press `Esc` or click once), then `Ctrl+C`.

### `brew: command not found` after install
Open a new shell, or run `eval "$(/opt/homebrew/bin/brew shellenv)"`. The managed `.zshrc` already does this on every launch.

### `vault` or `terraform` won't install
They live in the HashiCorp tap. The devops step taps it automatically; manually:
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/vault hashicorp/tap/terraform
```

### Docker commands fail
OrbStack provides the Docker engine — launch the **OrbStack** app once so it starts; enable Kubernetes in its settings for a local cluster.

### `claude: command not found`
The native installer puts it in `~/.local/bin` (on `PATH` via the managed `.zshrc`). Reload with `exec zsh`, or:
```bash
export PATH="$HOME/.local/bin:$PATH"
curl -fsSL https://claude.ai/install.sh | bash   # (re)install / claude update
```

### Change your git name/email later
The only personal data. Re-run the wizard and re-link:
```bash
./install.sh configure          # re-answer name & email
./install.sh link               # re-render generated/gitconfig, then symlink
```
`config/git/gitconfig.example` feeds the wizard, which renders the git-ignored `generated/gitconfig`.

### Change a tooling config (font, colors, prompt, aliases…)
WezTerm, Starship and zsh are standard configs in `config/`, symlinked into place. Edit them directly — changes take effect on the next new window / `exec zsh`.

### Restore a backup / re-run one step
The `link` step backs up originals (`~/.zshrc.backup.*`, `~/.gitconfig.backup.*`). Everything is idempotent:
```bash
./install.sh shell            # re-run a single step
./install.sh --dry-run all    # preview without changing anything
```
