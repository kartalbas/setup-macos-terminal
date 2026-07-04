# setup-macos-terminal

A robust, modular installer that turns a fresh macOS machine into a modern
developer terminal — **WezTerm** styled to feel like Windows Terminal, a
fast informative shell, the modern CLI toolbox, the full cloud-native DevOps
stack (kubectl, ArgoCD, Vault, Helm, k9s, Terraform…), and **coding agents
installed locally — Claude Code first**.

Built for Apple Silicon macOS + zsh + Homebrew.

---

## Quick start

```bash
cd ~/repos/setup-macos-terminal
./install.sh            # interactive menu
```

Or non-interactively:

```bash
./install.sh all --yes          # everything, no prompts
./install.sh core               # homebrew + terminal + shell + cli + link
./install.sh devops             # just the kubectl/argocd/vault/helm stack
./install.sh agents             # just Claude Code + runtimes
./install.sh --dry-run all      # preview every action, change nothing
```

After it finishes, open a **new WezTerm window** (or `exec zsh`).

---

## What you get

| Step | Installs |
|------|----------|
| **configure** | Asks your git identity (the only personal data) → renders `generated/gitconfig` (see below) |
| **homebrew** | Homebrew + Xcode Command Line Tools |
| **terminal** | WezTerm + Cascadia (CaskaydiaCove) & JetBrains Mono Nerd Fonts |
| **shell**    | Starship prompt, zsh autosuggestions / syntax-highlighting / completions, **PowerShell (pwsh)** |
| **cli**      | eza, bat, ripgrep, fd, fzf, zoxide, delta, lazygit, gh, tmux, jq, yq, btop, mise, **nvm**, node, uv… |
| **devops**   | kubectl, kubectx, kubecolor, helm, k9s, stern, kustomize, argocd, vault, terraform, opentofu, sops, dive, OrbStack + cloud CLIs **aws / az / gcloud** |
| **agents**   | **Claude Code** (native, in `~/.local/bin`), node/uv runtimes, optional **GitHub login** (`gh auth login`) + aider + Copilot CLI |
| **link**     | Symlinks `.zshrc`, WezTerm, Starship, `.gitconfig` (backs up existing) |

The package list lives in [`Brewfile`](./Brewfile) — edit it and re-run, or
`brew bundle --file=Brewfile` directly.

---

## Configuration: standard configs + your git identity

This repo is **public**, so the rule is simple:

- **Tooling configs are the committed default.** WezTerm, Starship and zsh live
  in [`config/`](./config) as plain, standard config files. They contain no
  personal data, so they're checked into git and used as-is during install —
  the **link** step symlinks them straight into place. No tokens, no rendering.
- **Only your git identity is personal.** `config/git/gitconfig.example` is the
  one template, carrying `__GIT_NAME__` / `__GIT_EMAIL__`. Everything else in
  that file (delta diffs, aliases, keychain credential helper…) is standard.

Because your name/email are personal, they're **never committed**: the
`configure` wizard renders them into `generated/gitconfig`, and the entire
`generated/` directory is git-ignored.

`configure` runs **automatically at startup** of `./install.sh` (and is the
first step of `all`/`core`). It asks only two things:

```
▸ Set up your git identity — the only personal data we store
? Git author name [Your Name]
? Git email [you@example.com]

▸ Created this file
  generated/gitconfig
      Your Name <you@example.com>
```

Defaults are pulled from your existing global git config — nothing personal is
hardcoded in the repo. Answers are saved to `generated/answers.env` (also
git-ignored). To change them later, re-run `./install.sh configure` (or edit
`generated/answers.env`) then `./install.sh link`.

**HTTPS git auth** uses the macOS Keychain (`credential.helper = osxkeychain`),
so you authenticate once and aren't prompted again.

The **link** step symlinks everything into place: `~/.zshrc`,
`~/.config/wezterm/wezterm.lua`, `~/.config/starship.toml` (from `config/`), and
`~/.gitconfig` (from `generated/`).

---

## Layout

```
setup-macos-terminal/
├── install.sh              # orchestrator with menu + per-step flags
├── Brewfile                # declarative package manifest
├── lib/common.sh           # logging, error trapping, idempotency helpers
├── scripts/                # one idempotent script per step
│   ├── 00-homebrew.sh
│   ├── 05-configure.sh     # asks git identity → renders generated/gitconfig
│   ├── 10-terminal.sh
│   ├── 20-shell.sh
│   ├── 30-cli-tools.sh
│   ├── 40-devops.sh
│   ├── 50-coding-agents.sh
│   └── 90-link-configs.sh
├── config/                 # standard configs, committed + linked as-is
│   ├── wezterm/wezterm.lua
│   ├── starship/starship.toml
│   ├── zsh/zshrc
│   └── git/gitconfig.example   # the ONLY template (user-specific: name/email)
├── generated/              # your rendered gitconfig (git-ignored, per-machine)
└── docs/
    ├── SHORTCUTS.md        # Windows-Terminal-style keybindings
    ├── TOOLS.md            # what every tool is + how to start
    └── TROUBLESHOOTING.md
```

---

## Design notes

- **Idempotent.** Every step checks before it installs; re-running is safe and
  fast. Already-installed packages are skipped, not reinstalled.
- **Safe linking.** Existing `~/.zshrc` etc. are moved to
  `*.backup.<timestamp>` before a symlink replaces them. Your current
  `export PATH="$HOME/.local/bin:$PATH"` (for Claude Code) is preserved in the
  managed `.zshrc`.
- **Modular.** Run one step or all. Each `scripts/*.sh` works standalone.
- **Dry-run + non-interactive.** `--dry-run` previews; `--yes` automates.
- **Local-first agents.** Claude Code is installed natively to `~/.local/bin`
  with its runtimes; nothing depends on a remote box.

See [`docs/SHORTCUTS.md`](./docs/SHORTCUTS.md) to learn the keys, and
[`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md) if something looks off.
