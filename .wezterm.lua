local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Appearance
config.color_scheme = 'GitHub Dark'
config.window_background_opacity = 0.9
config.text_background_opacity = 1
config.font = wezterm.font_with_fallback({
--   'JetBrains Mono',
--   'Symbols Nerd Font Mono',
  'FiraCode Nerd Font Mono',
})
config.macos_window_background_blur = 10
config.initial_cols = 120
config.initial_rows = 28

-- Leader
config.leader = { key = 'b', mods = 'CTRL', timeout_milliseconds = 2000 }

-- Catppuccin Mocha palette
local C = {
  crust    = '#11111b',
  base     = '#1e1e2e',
  surface0 = '#313244',
  green    = '#a6e3a1',
  yellow   = '#f9e2af',
  peach    = '#fab387',
  mauve    = '#cba6f7',
  sapphire = '#74c7ec',
  red      = '#f38ba8',
  text     = '#cdd6f4',
}

-- Powerline helpers
local function left_segments(segs, tab_bg)
  local elements = {}
  for i, s in ipairs(segs) do
    local bg, fg, text = s[1], s[2], s[3]
    table.insert(elements, { Background = { Color = bg } })
    table.insert(elements, { Foreground = { Color = fg } })
    table.insert(elements, { Text = text })
    local next_bg = (i < #segs) and segs[i + 1][1] or tab_bg
    table.insert(elements, { Background = { Color = next_bg } })
    table.insert(elements, { Foreground = { Color = bg } })
    table.insert(elements, { Text = '' })
  end
  return elements
end

local function right_segments(segs, tab_bg)
  local elements = {}
  for i, s in ipairs(segs) do
    local bg, fg, text = s[1], s[2], s[3]
    local prev_bg = (i == 1) and tab_bg or segs[i - 1][1]
    table.insert(elements, { Background = { Color = prev_bg } })
    table.insert(elements, { Foreground = { Color = bg } })
    table.insert(elements, { Text = '' })
    table.insert(elements, { Background = { Color = bg } })
    table.insert(elements, { Foreground = { Color = fg } })
    table.insert(elements, { Text = text })
  end
  return elements
end

-- Git info with 5s TTL cache
local function get_git_info(cwd)
  if not cwd or cwd == '' then return nil, false end
  local now = os.time()
  wezterm.GLOBAL.git_cache = wezterm.GLOBAL.git_cache or {}
  local cached = wezterm.GLOBAL.git_cache[cwd]
  if cached and (now - cached.time) < 5 then
    return cached.branch, cached.dirty
  end
  local ok, stdout = wezterm.run_child_process({ 'git', '-C', cwd, 'rev-parse', '--abbrev-ref', 'HEAD' })
  if not ok or not stdout or stdout == '' then
    wezterm.GLOBAL.git_cache[cwd] = { time = now, branch = nil, dirty = false }
    return nil, false
  end
  local branch = stdout:gsub('%s+$', '')
  local _, status_out = wezterm.run_child_process({ 'git', '-C', cwd, 'status', '--porcelain', '-uno' })
  local dirty = status_out and status_out ~= ''
  wezterm.GLOBAL.git_cache[cwd] = { time = now, branch = branch, dirty = dirty }
  return branch, dirty
end

-- Mode detection
local function get_mode(window)
  if window:leader_is_active() then return 'LEADER', C.mauve end
  local kt = window:active_key_table()
  if kt == 'copy_mode' then return 'COPY', C.yellow end
  return 'NORMAL', C.green
end

-- ── Keybindings ──────────────────────────────────────────────

config.keys = {
  -- Panes: splitting
  { key = '%', mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '%', mods = 'LEADER',       action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '"', mods = 'LEADER|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = '"', mods = 'LEADER',       action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  -- Panes: directional split (Alt+Arrows)
  { key = 'LeftArrow',  mods = 'LEADER|ALT', action = act.SplitPane { direction = 'Left' } },
  { key = 'RightArrow', mods = 'LEADER|ALT', action = act.SplitPane { direction = 'Right' } },
  { key = 'UpArrow',    mods = 'LEADER|ALT', action = act.SplitPane { direction = 'Up' } },
  { key = 'DownArrow',  mods = 'LEADER|ALT', action = act.SplitPane { direction = 'Down' } },
  -- Panes: navigation
  { key = 'LeftArrow',  mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow',    mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow',  mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
  -- Panes: resize
  { key = 'LeftArrow',  mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Left', 5 } },
  { key = 'RightArrow', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Right', 5 } },
  { key = 'UpArrow',    mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Up', 5 } },
  { key = 'DownArrow',  mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Down', 5 } },
  -- Panes: zoom, close, cycle, swap
  { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
  { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },
  { key = 'o', mods = 'LEADER', action = act.ActivatePaneDirection 'Next' },
  { key = 's', mods = 'LEADER', action = act.PaneSelect { mode = 'SwapWithActive' } },

  -- Tabs
  { key = 'c', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'n', mods = 'LEADER', action = act.ActivateTabRelative(1) },
  { key = 'p', mods = 'LEADER', action = act.ActivateTabRelative(-1) },
  { key = '1', mods = 'LEADER', action = act.ActivateTab(0) },
  { key = '2', mods = 'LEADER', action = act.ActivateTab(1) },
  { key = '3', mods = 'LEADER', action = act.ActivateTab(2) },
  { key = '4', mods = 'LEADER', action = act.ActivateTab(3) },
  { key = '5', mods = 'LEADER', action = act.ActivateTab(4) },
  { key = '6', mods = 'LEADER', action = act.ActivateTab(5) },
  { key = '7', mods = 'LEADER', action = act.ActivateTab(6) },
  { key = '8', mods = 'LEADER', action = act.ActivateTab(7) },
  { key = '9', mods = 'LEADER', action = act.ActivateTab(8) },
  { key = ',', mods = 'LEADER', action = act.PromptInputLine {
      description = 'Tab name:',
      action = wezterm.action_callback(function(window, pane, line)
        if line then window:active_tab():set_title(line) end
      end),
    },
  },
  { key = '&', mods = 'LEADER|SHIFT', action = act.CloseCurrentTab { confirm = true } },
  { key = '&', mods = 'LEADER',       action = act.CloseCurrentTab { confirm = true } },
  { key = 'w', mods = 'LEADER', action = act.ShowTabNavigator },

  -- Utilities
  { key = '[', mods = 'LEADER', action = act.ActivateCopyMode },
  { key = '/', mods = 'LEADER', action = act.Search 'CurrentSelectionOrEmptyString' },
  { key = ' ', mods = 'LEADER', action = act.QuickSelect },
  { key = ':', mods = 'LEADER|SHIFT', action = act.ActivateCommandPalette },
  { key = ':', mods = 'LEADER',       action = act.ActivateCommandPalette },
  { key = 'S', mods = 'LEADER|SHIFT', action = act.ShowLauncherArgs { flags = 'WORKSPACES' } },
  { key = 'S', mods = 'LEADER',       action = act.ShowLauncherArgs { flags = 'WORKSPACES' } },

  -- Help pane
  { key = '?', mods = 'LEADER|SHIFT', action = wezterm.action_callback(function(window, pane)
      window:perform_action(act.SplitPane {
        direction = 'Down',
        size = { Percent = 50 },
        command = { args = { 'sh', '-c', [[cat << 'HELP'
╭──────────────────────────────────────────────────────╮
│           WezTerm Shortcuts (Leader = Ctrl+b)        │
├───────────┬──────────────────────────────────────────┤
│ PANES     │  %    Split horizontal                   │
│           │  "    Split vertical                     │
│           │  ⌥+←→↑↓ Split in direction               │
│           │  ←→↑↓ Navigate panes                     │
│           │  ⇧+←→↑↓ Resize panes                     │
│           │  z    Toggle zoom                        │
│           │  x    Close pane                         │
│           │  o    Cycle to next pane                 │
│           │  s    Swap pane (select target)          │
├───────────┼──────────────────────────────────────────┤
│ TABS      │  c    New tab                            │
│           │  n/p  Next / Previous tab                │
│           │  1-9  Jump to tab by number              │
│           │  ,    Rename tab                         │
│           │  &    Close tab                          │
│           │  w    Tab navigator                      │
├───────────┼──────────────────────────────────────────┤
│ TOOLS     │  [    Copy / scroll mode                 │
│           │  /    Search                             │
│           │  Space Quick select (URLs, hashes)       │
│           │  :    Command palette                    │
│           │  S    Switch workspace                   │
│           │  ?    This help                          │
╰───────────┴──────────────────────────────────────────╯
HELP
read -n1 -s -r -p $'\nPress any key to close...']] } },
      }, pane)
    end),
  },
  { key = '?', mods = 'LEADER', action = wezterm.action_callback(function(window, pane)
      window:perform_action(act.SplitPane {
        direction = 'Down',
        size = { Percent = 50 },
        command = { args = { 'sh', '-c', [[cat << 'HELP'
╭──────────────────────────────────────────────────────╮
│           WezTerm Shortcuts (Leader = Ctrl+b)        │
├───────────┬──────────────────────────────────────────┤
│ PANES     │  %    Split horizontal                   │
│           │  "    Split vertical                     │
│           │  ⌥+←→↑↓ Split in direction               │
│           │  ←→↑↓ Navigate panes                     │
│           │  ⇧+←→↑↓ Resize panes                     │
│           │  z    Toggle zoom                        │
│           │  x    Close pane                         │
│           │  o    Cycle to next pane                 │
│           │  s    Swap pane (select target)          │
├───────────┼──────────────────────────────────────────┤
│ TABS      │  c    New tab                            │
│           │  n/p  Next / Previous tab                │
│           │  1-9  Jump to tab by number              │
│           │  ,    Rename tab                         │
│           │  &    Close tab                          │
│           │  w    Tab navigator                      │
├───────────┼──────────────────────────────────────────┤
│ TOOLS     │  [    Copy / scroll mode                 │
│           │  /    Search                             │
│           │  Space Quick select (URLs, hashes)       │
│           │  :    Command palette                    │
│           │  S    Switch workspace                   │
│           │  ?    This help                          │
╰───────────┴──────────────────────────────────────────╯
HELP
read -n1 -s -r -p $'\nPress any key to close...']] } },
      }, pane)
    end),
  },

  -- Shift+Enter: send plain newline (fixes CSI u-protocol issue with Claude Code)
  { key = 'Enter', mods = 'SHIFT', action = act.SendString '\n' },

  -- macOS word/line jumping
  { key = 'LeftArrow',  mods = 'OPT', action = act.SendKey { mods = 'ALT', key = 'b' } },
  { key = 'RightArrow', mods = 'OPT', action = act.SendKey { mods = 'ALT', key = 'f' } },
  { key = 'LeftArrow',  mods = 'CMD', action = act.SendKey { mods = 'CTRL', key = 'a' } },
  { key = 'RightArrow', mods = 'CMD', action = act.SendKey { mods = 'CTRL', key = 'e' } },
  { key = 'Backspace',  mods = 'CMD', action = act.SendKey { mods = 'CTRL', key = 'u' } },
}

-- ── Status bar ───────────────────────────────────────────────

wezterm.on('update-status', function(window, pane)
  local tab_bg = C.crust

  -- Left: mode indicator
  local mode, mode_color = get_mode(window)
  local mode_icon = (mode == 'LEADER') and ' \u{1f6a8} ' or '  '
  window:set_left_status(wezterm.format(
    left_segments({{ mode_color, C.crust, mode_icon .. mode .. ' ' }}, tab_bg)
  ))

  -- Right: contextual
  if window:leader_is_active() then
    local hints = ' % " Split \u{2502} \u{2325}+Arrows Split Dir \u{2502} Arrows Nav \u{2502} s Swap \u{2502} z Zoom \u{2502} c Tab \u{2502} ? Help '
    window:set_right_status(wezterm.format(
      right_segments({{ C.mauve, C.crust, hints }}, tab_bg)
    ))
    return
  end

  local segs = {}

  -- Git
  local cwd_uri = pane:get_current_working_dir()
  if cwd_uri then
    local cwd_path = cwd_uri.file_path or ''
    local home = wezterm.home_dir
    if home then cwd_path = cwd_path:gsub('^' .. home:gsub('([%(%)%.%%%+%-%*%?%[%^%$])', '%%%1'), '~') end
    local real_path = cwd_path:gsub('^~', wezterm.home_dir or '')
    local branch, dirty = get_git_info(real_path)
    if branch then
      local git_text = '  ' .. branch .. (dirty and ' *' or '') .. ' '
      table.insert(segs, { C.yellow, C.crust, git_text })
    end
  end

  window:set_right_status(wezterm.format(right_segments(segs, tab_bg)))
end)

-- ── Tab bar & window ─────────────────────────────────────────

config.tab_bar_at_bottom = false
config.enable_tab_bar = true
config.show_new_tab_button_in_tab_bar = true
-- config.window_decorations = 'RESIZE'

config.window_frame = {
  active_titlebar_bg = C.crust,
  inactive_titlebar_bg = C.crust,
}

config.colors = {
  tab_bar = {
    background = C.crust,
    active_tab = {
      bg_color = C.surface0,
      fg_color = C.text,
      intensity = 'Bold',
    },
    inactive_tab = {
      bg_color = C.crust,
      fg_color = C.text,
    },
    inactive_tab_hover = {
      bg_color = C.surface0,
      fg_color = C.text,
      italic = true,
    },
    new_tab = {
      bg_color = C.crust,
      fg_color = C.text,
    },
    new_tab_hover = {
      bg_color = C.surface0,
      fg_color = C.text,
    },
  },
}

return config
