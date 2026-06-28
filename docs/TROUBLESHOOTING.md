# Troubleshooting

### Icons show as boxes / `?` in the prompt
The terminal font isn't a Nerd Font. WezTerm is preconfigured for
`CaskaydiaCove Nerd Font`; make sure the cask installed:
```bash
brew install --cask font-caskaydia-cove-nerd-font
```
Then fully quit and reopen WezTerm.

### `Ctrl+C` won't interrupt a running command
By design it copies **only when text is selected**. With no selection it sends
a normal SIGINT. If you have a stray selection, press `Esc` first, or use the
mouse to click once (clearing the selection), then `Ctrl+C`.

### `brew: command not found` after install
Open a new shell, or run:
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```
The managed `.zshrc` already does this on every launch.

### `vault` or `terraform` won't install
They live in the HashiCorp tap (removed from homebrew-core after the license
change). The devops step taps it automatically; to do it manually:
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/vault hashicorp/tap/terraform
```

### Docker commands fail
OrbStack provides the Docker engine. Launch the **OrbStack** app once so the
engine starts; enable Kubernetes from its settings if you want a local cluster.

### `claude: command not found`
The native installer puts it in `~/.local/bin`, which the managed `.zshrc`
adds to `PATH`. Reload the shell (`exec zsh`) or:
```bash
export PATH="$HOME/.local/bin:$PATH"
```
Reinstall/update with:
```bash
curl -fsSL https://claude.ai/install.sh | bash
claude update
```

### Change your git name/email later
This is the only personal data. Re-run the wizard, or edit the saved answers
and re-link:
```bash
./install.sh configure          # re-answer name & email
# — or —
$EDITOR generated/answers.env    # tweak values directly
./install.sh link                # re-renders generated/gitconfig, then symlinks
```
`config/git/gitconfig.example` is the only template — don't put personal values
in it; it feeds the wizard, which renders the git-ignored `generated/gitconfig`.

### Change a tooling config (font, color scheme, prompt, aliases…)
WezTerm, Starship and zsh are standard configs committed in `config/`. Edit them
directly (e.g. `config/wezterm/wezterm.lua`) — they're symlinked, so changes take
effect on the next new window / `exec zsh`. No wizard, no rendering.

### I want my old config back
The `link` step backed up your originals next to the new symlinks:
```bash
ls -la ~/.zshrc.backup.* ~/.gitconfig.backup.*
```
Remove the symlink and move a backup back into place to restore.

### Restore-from-scratch / re-run a single step
Everything is idempotent:
```bash
./install.sh shell        # just re-run one step
./install.sh --dry-run all # preview without changing anything
```

### Starship prompt looks plain / no colors
Confirm it's initialized: `command -v starship` and that the `.zshrc` symlink
points into this repo (`ls -la ~/.zshrc`). Reload with `exec zsh`.
