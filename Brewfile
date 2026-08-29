# Brewfile — declarative package manifest for the macOS dev terminal setup.
#
# This is the SINGLE source of truth for what gets installed. Every step in
# scripts/ reads its list from here (see brewfile_items in lib/common.sh), so
# editing this file is what changes the install — there is no second copy.
#
#   ./install.sh cli                     install one group through the installer
#   ./install.sh --status                show installed vs. missing, per group
#   brew bundle --file=Brewfile          install everything at once, no steps
#   brew bundle check --file=Brewfile    check without installing
#   brew bundle cleanup --file=Brewfile  list extras (dry-run by default)
#
# Each entry belongs to the `#: group <name>` marker above it. Group names match
# the installer steps: terminal, shell, cli, devops. A marker stays in effect
# until the next one, so keep each group's entries together.

# ───────────────────── Terminal & Fonts ─────────────────
#: group terminal
cask "wezterm"                              # GPU terminal; same app + config on macOS & Windows
cask "font-caskaydia-cove-nerd-font"        # Cascadia Code + glyphs (Windows Terminal's font)
cask "font-jetbrains-mono-nerd-font"        # great alternative coding font

# ─────────────────────── GUI apps ───────────────────────
#: group terminal
cask "microsoft-edge"                       # Microsoft Edge browser
cask "jetbrains-toolbox"                    # JetBrains IDE manager (Toolbox)

# ───────────────────── Shell & Prompt ───────────────────
#: group shell
brew "starship"                  # fast, informative cross-shell prompt
brew "zsh-autosuggestions"       # ghost-text completion from history
brew "zsh-syntax-highlighting"   # command coloring as you type
brew "zsh-completions"           # extra completion definitions
brew "powershell"                # PowerShell LTS (pwsh) — cross-platform shell

# ───────────────────── Modern CLI core ──────────────────
#: group cli
brew "eza"           # ls replacement (icons, git status, tree)
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
brew "shellcheck"    # shell script linter — what tools/lint.sh and CI run
brew "tree"
brew "wget"
brew "htop"
brew "btop"          # prettier resource monitor
brew "tldr"          # concise command examples
brew "fastfetch"     # system info banner

# ─────────────── Languages & Version Management ──────────
#: group cli
brew "mise"          # polyglot runtime manager (node, python, go, ...)
brew "nvm"           # Node Version Manager — per-project node versions
brew "node"          # runtime for Claude Code MCP servers & JS tooling
brew "uv"            # fast Python package/runtime manager (+ uv tool)
brew "pipx"          # isolated installs of Python CLI apps
brew "cocoapods"     # iOS/macOS dependency manager (Flutter iOS, Swift/ObjC)
cask "flutter"       # Flutter SDK — mobile / web / desktop UI toolkit (flutter CLI)

# ──────────────── DevOps / Cloud-Native ─────────────────
#: group devops
tap "hashicorp/tap"              # vault, terraform (moved out of core after license change)
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
# gh (GitHub CLI) lives in the cli group

# Container runtime (local Docker + k8s)
cask "orbstack"                  # lightweight Docker Desktop alternative + local Kubernetes
