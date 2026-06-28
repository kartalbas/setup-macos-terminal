# Shortcuts — WezTerm tuned to feel like Windows Terminal

These are configured in [`config/wezterm/wezterm.lua`](../config/wezterm/wezterm.lua).
The modifier scheme mirrors Windows Terminal (`Ctrl` / `Ctrl+Shift`).

## Clipboard
| Keys | Action |
|------|--------|
| `Ctrl+C` | Copy **if text is selected**, otherwise send a normal interrupt (SIGINT) — exactly like Windows Terminal |
| `Ctrl+V` | Paste |
| `Ctrl+Shift+C` / `Ctrl+Shift+V` | Explicit copy / paste |
| Select text with mouse | Selection ready to copy |
| **Right-click** | Paste — or copy if text is selected (Windows Terminal behavior) |
| `Ctrl+Click` | Open link under cursor |

## Tabs
| Keys | Action |
|------|--------|
| `Ctrl+Shift+T` | New tab |
| `Ctrl+Shift+W` | Close tab |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Next / previous tab |
| `Ctrl+Shift+1..4` | Jump to tab 1–4 |

## Panes (splits)
| Keys | Action |
|------|--------|
| `Ctrl+Shift+D` | Split right (horizontal split) |
| `Ctrl+Shift+E` | Split down (vertical split) |
| `Ctrl+Shift+←/→/↑/↓` | Move focus between panes |
| `Ctrl+Shift+Z` | Zoom / un-zoom current pane |

## Search, zoom, palette
| Keys | Action |
|------|--------|
| `Ctrl+Shift+F` | Find in scrollback |
| `Ctrl+=` / `Ctrl+-` / `Ctrl+0` | Zoom in / out / reset font |
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+Shift+R` | Reload WezTerm config |

## Shell power-keys (from zsh + fzf)
| Keys | Action |
|------|--------|
| `Ctrl+R` | Fuzzy search command history |
| `Ctrl+T` | Fuzzy-pick a file into the command line |
| `Alt+C` | Fuzzy `cd` into a subdirectory |
| `→` (right arrow) | Accept the grey autosuggestion |
| `z <partial>` | Jump to a frequently-used directory (zoxide) |

> Want different keys? Edit `wezterm.lua` and hit `Ctrl+Shift+R` to reload —
> no restart needed.
