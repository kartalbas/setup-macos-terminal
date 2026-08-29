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
-- Native macOS title bar: keeps the traffic lights (close / minimise / zoom) and
-- the standard window menu. "RESIZE" alone drops the title bar and with it every
-- macOS window control, leaving only a drag border.
config.window_decorations = "TITLE | RESIZE"
config.window_padding = { left = 10, right = 10, top = 8, bottom = 6 }
config.initial_cols = 120
config.initial_rows = 34
config.scrollback_lines = 20000
config.audible_bell = "Disabled"

-- ───────────────────────────── Tab bar ─────────────────────────────
-- Retro tab bar, deliberately NOT the fancy one. The fancy bar draws a close
-- "x" on every tab that is far too easy to hit by accident, and this WezTerm
-- (20240203) has no option to hide it — `show_close_tab_button_in_tabs` only
-- exists in later builds. The retro bar renders each tab purely from whatever
-- format-tab-title returns, so there is no close button at all, and it lets us
-- give every tab its own colour.
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = true
config.tab_max_width = 32

-- One colour per tab, keyed on the tab's id rather than its index so a tab keeps
-- its colour when its neighbours are closed. Dim variants are spelled out rather
-- than computed, so no colour-maths API has to exist for this to work.
local TAB_COLORS = {
  { on = "#2f6fd0", off = "#1b3f76" },  -- blue
  { on = "#1f8a3b", off = "#124f22" },  -- green
  { on = "#a3721a", off = "#5d410f" },  -- amber
  { on = "#b3202f", off = "#66121b" },  -- red
  { on = "#7a1f8f", off = "#461252" },  -- purple
  { on = "#17708a", off = "#0d404f" },  -- teal
  { on = "#a3336f", off = "#5d1d3f" },  -- magenta
  { on = "#4b5563", off = "#2b3138" },  -- slate
}

wezterm.on("format-tab-title", function(tab, _tabs, _panes, _cfg, _hover, max_width)
  local colors = TAB_COLORS[(tab.tab_id % #TAB_COLORS) + 1]
  -- A name set with Ctrl+Shift+I wins; otherwise fall back to what the running
  -- program reports, which is what the fancy bar showed before.
  local title = tab.tab_title
  if title == nil or title == "" then
    title = tab.active_pane.title
  end
  local label = " " .. tostring(tab.tab_index + 1) .. ": " .. title .. " "
  if #label > max_width then
    label = wezterm.truncate_right(label, math.max(max_width - 2, 1)) .. "… "
  end
  return {
    { Background = { Color = tab.is_active and colors.on or colors.off } },
    { Foreground = { Color = tab.is_active and "#ffffff" or "#b9c0cb" } },
    { Attribute = { Intensity = tab.is_active and "Bold" or "Normal" } },
    { Text = label },
  }
end)

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
  -- Rename the active tab. Ctrl+Shift+I is free in both WezTerm's defaults and
  -- this config; it is also reachable from the command palette (Ctrl+Shift+P).
  {
    key = "i",
    mods = "CTRL|SHIFT",
    action = act.PromptInputLine({
      description = "Enter a new name for this tab:",
      action = wezterm.action_callback(function(window, _pane, line)
        -- line is nil when the prompt is cancelled, "" when submitted empty —
        -- treat empty as "go back to the program-reported title".
        if line ~= nil then
          window:active_tab():set_title(line)
        end
      end),
    }),
  },
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
