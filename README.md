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
./install.sh --status           # what's installed already, what's missing
```

Only `configure`, `core`, `all` and `link` ever ask a question (your git name
and email). `./install.sh devops`, `cli`, `agents`… run without a prompt.

After it finishes, open a **new WezTerm window** (or `exec zsh`).

---

## What you get

| Step | Installs |
|------|----------|
| **configure** | Asks your git identity (the only personal data) → renders `generated/gitconfig` (see below) |
| **homebrew** | Homebrew + Xcode Command Line Tools |
| **terminal** | WezTerm + Cascadia (CaskaydiaCove) & JetBrains Mono Nerd Fonts + Microsoft Edge + JetBrains Toolbox |
| **shell**    | Starship prompt, zsh autosuggestions / syntax-highlighting / completions, **PowerShell (pwsh)** |
| **cli**      | eza, bat, ripgrep, fd, fzf, zoxide, delta, lazygit, gh, tmux, jq, yq, btop, mise, **nvm**, node, uv, **Flutter**, cocoapods… |
| **devops**   | kubectl, kubectx, kubecolor, helm, k9s, stern, kustomize, argocd, vault, terraform, opentofu, sops, dive, OrbStack + cloud CLIs **aws / az / gcloud** |
| **agents**   | **Claude Code** (native, in `~/.local/bin`), node/uv runtimes, optional **GitHub login** (`gh auth login`) + aider + Copilot CLI |
| **link**     | Copies `.zshrc`, WezTerm, Starship, `.gitconfig` into place — real files, independent of this repo (backs up existing) |

### The Brewfile is the single source of truth

Package lists are **not** duplicated in the scripts. Every entry in
[`Brewfile`](./Brewfile) carries a `#: group <name>` marker, and each step
installs exactly its own group:

```ruby
#: group cli
brew "eza"           # ls replacement (icons, git status, tree)
brew "bat"           # cat with syntax highlighting
```

So adding a tool means editing one file. `./install.sh cli`, `--status` and
`brew bundle --file=Brewfile` all read the same list and cannot drift apart —
`tools/lint.sh` fails the build if a group ever resolves to nothing.

---

## Configuration: standard configs + your git identity

This repo is **public**, so the rule is simple:

- **Tooling configs are the committed default.** WezTerm, Starship and zsh live
  in [`config/`](./config) as plain, standard config files. They contain no
  personal data, so they're checked into git and used as-is during install —
  the **link** step copies them straight into place. No tokens, no rendering.
- **Only your git identity is personal.** `config/git/gitconfig.example` is the
  one template, carrying `__GIT_NAME__` / `__GIT_EMAIL__`. Everything else in
  that file (delta diffs, aliases, keychain credential helper…) is standard.

Because your name/email are personal, they're **never committed**: the
`configure` wizard renders them into `generated/gitconfig`, and the entire
`generated/` directory is git-ignored.

`configure` is the first step of `all`/`core`, the first entry in the menu, and
is pulled in on demand by `link` when `generated/gitconfig` is missing — so it
runs when it's needed and never prompts a step that doesn't use it. It asks only
two things:

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

The **link** step copies everything into place as real, independent files:
`~/.zshrc`, `~/.config/wezterm/wezterm.lua`, `~/.config/starship.toml` (from
`config/`), and `~/.gitconfig` (from `generated/`). Nothing symlinks back here —
you can delete this repo after install.

---

## Layout

```
setup-macos-terminal/
├── install.sh              # orchestrator with menu + per-step flags + --status
├── Brewfile                # declarative package manifest — THE package list
├── lib/common.sh           # logging, error trapping, Brewfile + idempotency helpers
├── tools/lint.sh           # bash -n + shellcheck + Brewfile sanity — run before committing
├── scripts/                # one idempotent script per step
│   ├── 00-homebrew.sh
│   ├── 05-configure.sh     # asks git identity → renders generated/gitconfig
│   ├── 10-terminal.sh
│   ├── 20-shell.sh
│   ├── 30-cli-tools.sh
│   ├── 40-devops.sh
│   ├── 50-coding-agents.sh
│   └── 90-link-configs.sh
├── config/                 # standard configs, committed + copied on install
│   ├── wezterm/wezterm.lua
│   ├── starship/starship.toml
│   ├── zsh/zshrc               # sibling of pwsh/profile.ps1 — change both
│   ├── pwsh/profile.ps1
│   └── git/gitconfig.example   # the ONLY template (user-specific: name/email)
├── generated/              # your rendered gitconfig (git-ignored, per-machine)
└── docs/
    └── README.md           # one-page guide: tools, shortcuts, troubleshooting
```

---

## Design notes

- **Idempotent.** Every step checks before it installs; re-running is safe and
  fast. Already-installed packages are skipped, not reinstalled.
- **Independent copies, not symlinks.** Configs are **copied** to their
  destinations as real files, so `setup-macos-terminal` is only an installer —
  delete it afterwards and everything keeps working. Existing files are moved to
  `*.backup.<timestamp>` first (an old symlink from a previous install is
  replaced by a copy).
- **Icons follow the terminal, not the shell.** `~/.zshrc` is machine-wide, but
  Nerd-Font glyphs live in the *font* of whichever terminal is running. So `ls` /
  `ll` enable eza icons only for terminals known to carry a Nerd Font (WezTerm,
  iTerm2, Ghostty, kitty, Alacritty) and only on a TTY; anything else gets plain
  output instead of tofu boxes. Override per machine in `~/.zshrc.local`:
  `EZA_ICONS=always` (e.g. Terminal.app once you set `CaskaydiaCove Nerd Font
  Mono` in its profile) or `EZA_ICONS=never`. Note that eza's own
  `--icons=auto` — and therefore a bare `--icons` — renders **nothing** as of
  0.23.x, so the config always passes an explicit `always`/`never`.
- **Modular.** Run one step or all. Each `scripts/*.sh` works standalone.
- **Dry-run + non-interactive.** `--dry-run` previews every package and file the
  run would touch (the step scripts still execute — they just print instead of
  acting); `--yes` automates; `--status` reports without changing anything.
- **Your edits stay yours.** Re-running `link` replaces the managed configs with
  this repo's copies (backing yours up first). Machine-specific tweaks belong in
  `~/.zshrc.local` / `~/.config/powershell/profile.local.ps1`, which are sourced
  last and never touched.
- **Linted, by hand.** `./tools/lint.sh` runs `bash -n`, `shellcheck` and a
  Brewfile sanity check. Run it before committing — there is deliberately no CI
  workflow; a repo this size doesn't need one.
- **Local-first agents.** Claude Code is installed natively to `~/.local/bin`
  with its runtimes; nothing depends on a remote box.

See the one-page [`docs/README.md`](./docs/README.md) for tools, keyboard
shortcuts, and troubleshooting.
