#!/usr/bin/env bash
# 10-terminal.sh — install WezTerm, the Nerd Fonts that make it look sharp,
# and GUI apps (Microsoft Edge, JetBrains Toolbox).
# The list itself lives in the Brewfile under `#: group terminal`.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos; require_brew

install_brewfile_group terminal

ok "Terminal, fonts, Edge + JetBrains Toolbox installed."
info "Config gets copied by the 'link' step → ~/.config/wezterm/wezterm.lua"
