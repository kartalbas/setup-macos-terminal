# Tools — what's installed and how to start

## Terminal & shell
| Tool | What it is | Try |
|------|-----------|-----|
| **WezTerm** | GPU terminal; same app/config on macOS & Windows | open it from Spotlight |
| **Starship** | Fast prompt: git, language, k8s context | shown automatically |
| **zsh-autosuggestions** | Grey ghost-text from history | press `→` to accept |
| **zsh-syntax-highlighting** | Colors commands as you type | invalid commands turn red |

## Modern CLI
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
| `jq` / `yq` | JSON / YAML | `… | jq .` |
| `btop` | `top` | `top` |
| `tldr` | man pages | `tldr tar` |

## Languages & runtimes
| Tool | What it is | Try |
|------|-----------|-----|
| **mise** | Polyglot version manager | `mise use node@22 python@3.12` |
| **node** | JS runtime (Claude Code MCP, tooling) | `node -v` |
| **uv** | Fast Python pkg/runtime manager | `uv venv && uv pip install …` |
| **pipx** | Isolated Python CLI apps | `pipx list` |

## DevOps / cloud-native
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

### Cloud provider CLIs
| Tool | Cloud | First-time auth |
|------|-------|-----------------|
| `aws` | AWS | `aws configure` (or `aws sso login`) |
| `az` | Azure | `az login` |
| `gcloud` / `gsutil` / `bq` | Google Cloud | `gcloud init` |
| `gh` | GitHub | `gh auth login` |

## Coding agents (local)
| Tool | What it is | Try |
|------|-----------|-----|
| **Claude Code** | Anthropic's agentic CLI, in `~/.local/bin` | `claude` in a project |
| `aider` *(optional)* | Python pair-programming agent | `aider` |
| `gh copilot` *(optional)* | Copilot CLI (gh extension) | `gh copilot suggest "…"` |

### Claude Code first run
```bash
cd ~/your-project
claude                 # follow the login prompt the first time
claude update          # update to the latest version anytime
```
Claude Code reads project context from a `CLAUDE.md` file and can load
node-based **MCP servers** for extra tools.
