# Guide

Everything you need after running the installer, in one page:
[Tools](#tools) · [Shortcuts](#shortcuts) · [Troubleshooting](#troubleshooting)

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
| **JetBrains Toolbox** | Installs/updates JetBrains IDEs | open from Spotlight |

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
| **Flutter** | UI toolkit SDK (mobile/web/desktop) | `flutter doctor` |
| **CocoaPods** | iOS/macOS dependency manager (Flutter iOS) | `pod --version` |

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
./install.sh link               # re-render generated/gitconfig, then copy into place
```
`config/git/gitconfig.example` feeds the wizard, which renders the git-ignored `generated/gitconfig`.

### Change a tooling config (font, colors, prompt, aliases…)
WezTerm, Starship and zsh are **copied** to their destinations on install (not symlinked), so the repo is only the installer and can be deleted. Where to put a change depends on whether you'll ever re-run the installer:

| You want | Edit | Survives `./install.sh link`? |
|----------|------|-------------------------------|
| A tweak on **this machine only** | `~/.zshrc.local` · `~/.config/powershell/profile.local.ps1` | **Yes** — never touched |
| A change for **every machine** | `config/zsh/zshrc` etc. here, then `./install.sh link` | Yes — it *is* the source |
| A one-off, repo already deleted | `~/.zshrc`, `~/.config/wezterm/wezterm.lua` directly | No — a later `link` replaces it (backup kept) |

`~/.zshrc.local` is sourced at the very bottom of the managed `~/.zshrc`, so it can override anything above it. Changes take effect on the next new window / `exec zsh`.

### See what's already installed
```bash
./install.sh --status         # per group: installed vs. missing, plus config drift
```
It reports against the same `Brewfile` groups and config list the installer uses, so it can't disagree with what a real run would do. A config line marked *differs from this repo* is exactly the third row of the table above.

### Restore a backup / re-run one step
The `link` step backs up originals (`~/.zshrc.backup.*`, `~/.gitconfig.backup.*`). Everything is idempotent:
```bash
./install.sh shell            # re-run a single step
./install.sh --dry-run all    # preview every action without changing anything
```
