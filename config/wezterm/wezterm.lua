-- WezTerm config tuned to feel like Windows Terminal on macOS:
-- chosen font + color scheme, Windows-style shortcuts, smart copy/paste.

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- ─────────────────────────── Appearance ───────────────────────────
config.color_scheme = "Campbell (Gogh)"            -- Campbell (Gogh) = Windows Terminal palette
config.font = wezterm.font_with_fallback({
  "CaskaydiaCove Nerd Font",
  "JetBrainsMono Nerd Font",
  "Menlo",
})
config.font_size = 13.0
config.line_height = 1.05
config.cell_width = 1.0
config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"     -- crisp text like Windows Terminal

config.window_background_opacity = 1.0
config.macos_window_background_blur = 0
config.window_decorations = "RESIZE"
config.window_padding = { left = 10, right = 10, top = 8, bottom = 6 }
config.initial_cols = 120
config.initial_rows = 34
config.scrollback_lines = 20000
config.audible_bell = "Disabled"

-- Tab bar styled like Windows Terminal (tabs on top, new-tab "+" button)
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = true
config.tab_max_width = 28

-- ─────────────────────── Behaviour / shell ────────────────────────
config.default_cwd = wezterm.home_dir
config.window_close_confirmation = "NeverPrompt"
config.adjust_window_size_when_changing_font_size = false
config.warn_about_missing_glyphs = false

-- Right-click pastes (like Windows Terminal); selecting text copies it.
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = wezterm.action_callback(function(window, pane)
      local has_sel = window:get_selection_text_for_pane(pane) ~= ""
      if has_sel then
        window:perform_action(act.CopyTo("ClipboardAndPrimarySelection"), pane)
        window:perform_action(act.ClearSelection, pane)
      else
        window:perform_action(act.PasteFrom("Clipboard"), pane)
      end
    end),
  },
  -- Ctrl+Click opens hyperlinks
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = act.OpenLinkAtMouseCursor,
  },
}

-- ─────────────────────────── Keybindings ──────────────────────────
-- Windows Terminal style: Ctrl/Ctrl+Shift driven. macOS Cmd shortcuts kept too.

-- Smart Ctrl+C: copy if there's a selection, otherwise send a real SIGINT.
local smart_ctrl_c = wezterm.action_callback(function(window, pane)
  local sel = window:get_selection_text_for_pane(pane)
  if sel and sel ~= "" then
    window:perform_action(act.CopyTo("ClipboardAndPrimarySelection"), pane)
    window:perform_action(act.ClearSelection, pane)
  else
    window:perform_action(act.SendKey({ key = "c", mods = "CTRL" }), pane)
  end
end)

config.keys = {
  -- Clipboard (Windows Terminal feel) -------------------------------------
  { key = "c", mods = "CTRL", action = smart_ctrl_c },
  { key = "v", mods = "CTRL", action = act.PasteFrom("Clipboard") },
  { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
  { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },

  -- Tabs ------------------------------------------------------------------
  { key = "t", mods = "CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "w", mods = "CTRL|SHIFT", action = act.CloseCurrentTab({ confirm = false }) },
  { key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
  { key = "Tab", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
  { key = "1", mods = "CTRL|SHIFT", action = act.ActivateTab(0) },
  { key = "2", mods = "CTRL|SHIFT", action = act.ActivateTab(1) },
  { key = "3", mods = "CTRL|SHIFT", action = act.ActivateTab(2) },
  { key = "4", mods = "CTRL|SHIFT", action = act.ActivateTab(3) },

  -- Panes (Windows Terminal uses Alt+Shift +/- ; mirror that) -------------
  { key = "d", mods = "CTRL|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "e", mods = "CTRL|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "LeftArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Left") },
  { key = "RightArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Right") },
  { key = "UpArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Up") },
  { key = "DownArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Down") },
  { key = "z", mods = "CTRL|SHIFT", action = act.TogglePaneZoomState },

  -- Find / search ---------------------------------------------------------
  { key = "f", mods = "CTRL|SHIFT", action = act.Search({ CaseInSensitiveString = "" }) },

  -- Font zoom -------------------------------------------------------------
  { key = "=", mods = "CTRL", action = act.IncreaseFontSize },
  { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
  { key = "0", mods = "CTRL", action = act.ResetFontSize },

  -- Command palette + config reload --------------------------------------
  { key = "p", mods = "CTRL|SHIFT", action = act.ActivateCommandPalette },
  { key = "r", mods = "CTRL|SHIFT", action = act.ReloadConfiguration },
}

return config
