# Brewfile — declarative package manifest for the macOS dev terminal setup.
# Apply with:  brew bundle --file=Brewfile
# Check state: brew bundle check --file=Brewfile
# Remove extras: brew bundle cleanup --file=Brewfile   (dry-run by default)

# ───────────────────────── Taps ─────────────────────────
tap "hashicorp/tap"          # vault, terraform (moved out of core after license change)

# ───────────────────── Terminal & Fonts ─────────────────
cask "wezterm"                              # GPU terminal; same app + config on macOS & Windows
cask "font-caskaydia-cove-nerd-font"        # Cascadia Code + glyphs (Windows Terminal's font)
cask "font-jetbrains-mono-nerd-font"        # great alternative coding font

# ─────────────────────── GUI apps ───────────────────────
cask "microsoft-edge"                       # Microsoft Edge browser
cask "jetbrains-toolbox"                     # JetBrains IDE manager (Toolbox)

# ───────────────────── Shell & Prompt ───────────────────
brew "starship"                  # fast, informative cross-shell prompt
brew "zsh-autosuggestions"       # ghost-text completion from history
brew "zsh-syntax-highlighting"   # command coloring as you type
brew "zsh-completions"           # extra completion definitions
brew "powershell"                # PowerShell LTS (pwsh) — cross-platform shell

# ───────────────────── Modern CLI core ──────────────────
brew "eza"            # ls replacement (icons, git status, tree)
brew "bat"           # cat with syntax highlighting
brew "ripgrep"       # rg — fast, gitignore-aware grep
brew "fd"            # friendly find
brew "fzf"           # fuzzy finder (Ctrl-R, file/branch pickers)
brew "zoxide"        # smarter cd that learns your dirs
brew "git-delta"     # gorgeous git diffs
brew "lazygit"       # git TUI
brew "gh"            # GitHub CLI
brew "tmux"          # terminal multiplexer / persistent sessions
brew "jq"            # JSON processor
brew "yq"            # YAML/JSON/XML processor
brew "tree"
brew "wget"
brew "htop"
brew "btop"          # prettier resource monitor
brew "tldr"          # concise command examples
brew "fastfetch"     # system info banner

# ─────────────── Languages & Version Management ──────────
brew "mise"          # polyglot runtime manager (node, python, go, ...)
brew "nvm"           # Node Version Manager — per-project node versions
brew "node"          # runtime for Claude Code MCP servers & JS tooling
brew "uv"            # fast Python package/runtime manager (+ uv tool)
brew "pipx"          # isolated installs of Python CLI apps
cask "flutter"       # Flutter SDK — mobile / web / desktop UI toolkit (flutter CLI)

# ──────────────── DevOps / Cloud-Native ─────────────────
brew "kubernetes-cli"            # kubectl
brew "kubectx"                   # kubectx + kubens (context/namespace switch)
brew "kubecolor"                 # colorized kubectl output
brew "helm"                      # Kubernetes package manager
brew "k9s"                       # Kubernetes cluster TUI
brew "stern"                     # multi-pod log tailing
brew "kustomize"                 # Kubernetes config customization
brew "argocd"                    # Argo CD GitOps CLI
brew "hashicorp/tap/vault"       # HashiCorp Vault CLI
brew "hashicorp/tap/terraform"   # Terraform
brew "opentofu"                  # open-source Terraform fork (tofu)
brew "sops"                      # encrypted secrets in git
brew "dive"                      # inspect docker image layers

# Cloud provider CLIs
brew "awscli"                    # AWS    → aws
brew "azure-cli"                 # Azure  → az
cask "google-cloud-sdk"          # Google → gcloud / gsutil / bq
# gh (GitHub CLI) is installed in the CLI step

# ──────────── Container runtime (local Docker + k8s) ─────
cask "orbstack"      # lightweight Docker Desktop alternative + local Kubernetes

# ─────────────────── Local coding LLM (opt-in) ──────────
# Installed only by `./install.sh local-llm` (never by `all`). opencode is the
# terminal client; the Rapid-MLX runtime + hf downloader are Python CLIs installed
# via `uv tool` inside scripts/60-local-llm.sh (uv tool install rapid-mlx huggingface_hub).
brew "opencode"      # AI coding agent for the terminal → points at the local Rapid-MLX server
