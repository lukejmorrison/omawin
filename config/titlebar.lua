-- omawin titlebar: Windows 7-style hyprbars (glass min/max, red close).
-- Focused chrome is opaque; unfocused chrome is transparent, like the Omarchy bar.
-- Browsers and other CSD apps keep their own header; hyprbars is disabled there
-- so two title bars do not stack (hyprbars:no_bar).

local function env_or(name, fallback)
  local value = os.getenv(name)
  if value == nil or value == "" then
    return fallback
  end
  return value
end

local home = os.getenv("HOME") or ""
local config_home = env_or("XDG_CONFIG_HOME", home .. "/.config")
local state_home = env_or("XDG_STATE_HOME", home .. "/.local/state")
local minimize_bin = home .. "/.local/bin/omawin-minimize"

local function is_theme_color(value)
  if type(value) ~= "string" then
    return false
  end
  local hex = value:match("^#([%x]+)$")
  if hex ~= nil then
    return #hex == 6 or #hex == 8
  end
  local kind, body = value:match("^(rgba?)%(([^)]+)%)$")
  if kind == nil then
    return false
  end
  if body:match("^%x+$") then
    return (kind == "rgb" and #body == 6) or (kind == "rgba" and #body == 8)
  end
  return body:match("^%s*%d+%s*,%s*%d+%s*,%s*%d+%s*,?%s*[%d%.]*%s*$") ~= nil
end

local function load_generated_colors()
  local chunk = loadfile(config_home .. "/hypr/titlebar-colors.lua")
  if chunk == nil then
    return nil
  end
  local ok, colors = pcall(chunk)
  if ok and type(colors) == "table" then
    return colors
  end
  return nil
end

local function load_toml_colors()
  local palette = {}
  local colors = io.open(state_home .. "/omarchy/current/theme/colors.toml", "r")
  if colors == nil then
    return palette
  end
  for line in colors:lines() do
    local key, value = line:match("^%s*([%w_%-]+)%s*=%s*[\"']([^\"']+)[\"']")
    if key ~= nil then
      palette[key] = value
    end
  end
  colors:close()
  return palette
end

local function first_color(palette, keys)
  for _, key in ipairs(keys) do
    local value = palette[key]
    if is_theme_color(value) then
      return value
    end
    if type(value) == "string" and is_theme_color(palette[value]) then
      return palette[value]
    end
  end
  return nil
end

local generated = load_generated_colors() or {}
local palette = load_toml_colors()
local theme = {
  background = generated.background
    or first_color(palette, { "background", "bg", "color0" })
    or "#222222",
  foreground = generated.foreground
    or first_color(palette, { "foreground", "fg", "color7", "light_foreground" })
    or "#eeeeee",
  accent = generated.accent
    or first_color(palette, { "hyprland_active_border", "accent", "blue", "color4" })
    or generated.foreground
    or first_color(palette, { "foreground", "fg" })
    or "#eeeeee",
}

-- Light (opaque Omarchy bar) vs dark (transparent Omarchy bar) caption chrome.
-- Title text matches the bar: dark on light glass, light on dark glass.
local chrome_light = {
  bar_active = "rgba(e4eaf3ee)",
  bar_inactive = "rgba(c8c8c888)",
  title_active = "rgb(1a1a1a)",
  title_inactive = "rgb(666666)",
  border_active = "rgba(a8c4e0ff)",
  border_inactive = "rgba(9a9a9a66)",
}
local chrome_dark = {
  bar_active = "rgba(1b1b1bee)",
  bar_inactive = "rgba(12121299)",
  title_active = "rgb(ececec)",
  title_inactive = "rgb(9a9a9a)",
  border_active = "rgba(3b84c3ff)",
  border_inactive = "rgba(5a5a5a88)",
}

local aero = {
  bar_active = generated.bar_active or chrome_light.bar_active,
  bar_inactive = generated.bar_inactive or chrome_light.bar_inactive,
  title_active = generated.title_active or chrome_light.title_active,
  title_inactive = generated.title_inactive or chrome_light.title_inactive,
  border_active = generated.border_active or chrome_light.border_active,
  border_inactive = generated.border_inactive or chrome_light.border_inactive,
  close_bg = "rgb(c75033)",
  close_fg = "rgb(ffffff)",
  caption_bg = "rgba(f4f4f4cc)",
  caption_fg = "rgb(3b3b3b)",
}

local function omarchy_bar_is_dark()
  local file = io.open(config_home .. "/omarchy/shell.json", "r")
  if file == nil then
    return false
  end
  local raw = file:read("*a") or ""
  file:close()
  return raw:find('"transparent"%s*:%s*true') ~= nil
end

local maximize_toggle =
  [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']]
local close_window = [[hyprctl dispatch 'hl.dsp.window.close()']]
-- Super+Alt+S. hyprbars focuses this window, then execs the action via spawn().
-- A raw helper path does not run reliably from hyprbars; close/maximize already
-- use hyprctl dispatch.
local scratchpad_send =
  [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:scratchpad", follow = false })']]

hl.permission({
  binary = "/usr/(bin|local/bin)/hyprpm",
  type = "plugin",
  mode = "allow",
})

hl.config({
  general = {
    resize_on_border = true,
    extend_border_grab_area = 12,
    border_size = 4,
  },
  decoration = {
    rounding = 6,
  },
})

-- Plugin keys error until hyprbars is loaded. Autostart runs hyprpm reload then hyprctl reload.
local chrome_rules = nil
if hl.plugin.hyprbars ~= nil then
  hl.config({
    plugin = {
      hyprbars = {
        enabled = true,
        -- 28*1.25=35 physical px on LVDS-1. 30 was 37.5 and the title
        -- glyphs were bilinear-filtered in both opaque and transparent chrome.
        bar_height = 28,
        bar_title_enabled = true,
        -- 12*1.25=15 physical px (integer). Do not use 13/14 at this scale.
        bar_text_size = 12,
        bar_text_font = "JetBrainsMono Nerd Font",
        bar_text_align = "left",
        bar_buttons_alignment = "right",
        bar_part_of_window = true,
        bar_precedence_over_border = true,
        -- Match the vertical gap: (bar_height 28 - button 20) / 2 = 4,
        -- so the close circle is the same distance from the top border
        -- and the right border. 20*1.25=25, 4*1.25=5.
        bar_padding = 4,
        bar_button_padding = 0,
        icon_on_hover = false,
        bar_color = aero.bar_active,
        ["col.text"] = aero.title_active,
        inactive_button_color = "rgba(f4f4f466)",
        on_double_click = maximize_toggle,
      },
    },
  })

  -- Buttons are defined right-to-left, so the bar shows: minimize, maximize, close.
  -- Windows 7: glass min/max, red close.
  hl.plugin.hyprbars.add_button({
    bg_color = aero.close_bg,
    fg_color = aero.close_fg,
    size = 20,
    icon = "×",
    action = close_window,
  })
  hl.plugin.hyprbars.add_button({
    bg_color = aero.caption_bg,
    fg_color = aero.caption_fg,
    size = 20,
    icon = "□",
    action = maximize_toggle,
  })
  hl.plugin.hyprbars.add_button({
    bg_color = aero.caption_bg,
    fg_color = aero.caption_fg,
    size = 20,
    icon = "–",
    action = scratchpad_send,
  })

  chrome_rules = {
    light_focus = hl.window_rule({
      name = "omawin-chrome-light-focus",
      match = { focus = true },
      ["hyprbars:bar_color"] = chrome_light.bar_active,
      ["hyprbars:title_color"] = chrome_light.title_active,
      border_color = chrome_light.border_active,
      border_size = 4,
    }),
    light_blur = hl.window_rule({
      name = "omawin-chrome-light-blur",
      match = { focus = false },
      ["hyprbars:bar_color"] = chrome_light.bar_inactive,
      ["hyprbars:title_color"] = chrome_light.title_inactive,
      border_color = chrome_light.border_inactive,
      border_size = 4,
    }),
    dark_focus = hl.window_rule({
      name = "omawin-chrome-dark-focus",
      match = { focus = true },
      ["hyprbars:bar_color"] = chrome_dark.bar_active,
      ["hyprbars:title_color"] = chrome_dark.title_active,
      border_color = chrome_dark.border_active,
      border_size = 4,
    }),
    dark_blur = hl.window_rule({
      name = "omawin-chrome-dark-blur",
      match = { focus = false },
      ["hyprbars:bar_color"] = chrome_dark.bar_inactive,
      ["hyprbars:title_color"] = chrome_dark.title_inactive,
      border_color = chrome_dark.border_inactive,
      border_size = 4,
    }),
  }

  -- CSD apps already draw a caption. hyprbars on top of that is a second bar
  -- that sits as an overlay on the toolkit header (obvious with two windows).
  -- Plugin effect is hyprbars:no_bar; value must be a truthy string.
  o.window({ tag = "chromium-based-browser" }, { ["hyprbars:no_bar"] = "1" })
  o.window({ tag = "firefox-based-browser" }, { ["hyprbars:no_bar"] = "1" })
  o.window(
    "^(chromium|google-chrome.*|[Bb]rave-browser|microsoft-edge|Vivaldi-stable|helium|chrome-.+)$",
    { ["hyprbars:no_bar"] = "1" }
  )
  o.window("([fF]irefox|zen|librewolf)", { ["hyprbars:no_bar"] = "1" })
  o.window("^(org\\.gnome\\.)?[Nn]autilus$", { ["hyprbars:no_bar"] = "1" })
  o.window(
    "^(signal|Signal|discord|Discord|slack|Slack|telegram-desktop|org\\.telegram\\.desktop)$",
    { ["hyprbars:no_bar"] = "1" }
  )
end

-- hyprland-plugins#543: a dummy tag change forces hyprbars to re-run rules.
local function poke_hyprbars(w)
  if w == nil then
    return
  end
  hl.dispatch(hl.dsp.window.tag({ tag = "+omawin-poke", window = w }))
  hl.dispatch(hl.dsp.window.tag({ tag = "-omawin-poke", window = w }))
end

-- Keep the title bar inside the monitor workarea (below the Omarchy bar).
local function reserved_ltrb(monitor)
  local r = monitor and monitor.reserved
  if type(r) == "table" then
    if r.left ~= nil or r.top ~= nil then
      return r.left or 0, r.top or 0, r.right or 0, r.bottom or 0
    end
    if r[1] ~= nil then
      return r[1] or 0, r[2] or 0, r[3] or 0, r[4] or 0
    end
  end
  return 0, 26, 0, 0
end

local function place_float(w)
  local m = (w ~= nil and w.monitor) or hl.get_active_monitor()
  if m == nil then
    return
  end
  local scale = m.scale
  if scale == nil or scale < 0.1 then
    scale = 1
  end
  local left, top, right, bottom = reserved_ltrb(m)
  local gap = 16
  local work_w = m.width / scale - left - right - gap * 2
  local work_h = m.height / scale - top - bottom - gap * 2
  if work_w < 200 then
    work_w = 200
  end
  if work_h < 160 then
    work_h = 160
  end
  local fw = math.floor(work_w * 0.55)
  local fh = math.floor(work_h * 0.60)
  hl.dispatch(hl.dsp.window.resize({ x = fw, y = fh, relative = false, window = w }))
  hl.dispatch(hl.dsp.window.center({ window = w }))
end

hl.on("window.open", function(w)
  if w == nil then
    return
  end
  if w.floating then
    place_float(w)
  end
  poke_hyprbars(w)
end)

hl.on("window.fullscreen", function(w)
  poke_hyprbars(w)
end)

hl.on("window.active", function()
  for _, win in ipairs(hl.get_windows() or {}) do
    poke_hyprbars(win)
  end
end)

local function apply_chrome_mode(dark)
  if hl.plugin.hyprbars == nil or chrome_rules == nil then
    return
  end
  local palette = dark and chrome_dark or chrome_light
  hl.config({
    plugin = {
      hyprbars = {
        bar_color = palette.bar_active,
        ["col.text"] = palette.title_active,
      },
    },
  })
  pcall(function()
    chrome_rules.light_focus:set_enabled(not dark)
    chrome_rules.light_blur:set_enabled(not dark)
    chrome_rules.dark_focus:set_enabled(dark)
    chrome_rules.dark_blur:set_enabled(dark)
  end)
  for _, win in ipairs(hl.get_windows() or {}) do
    poke_hyprbars(win)
  end
end

local last_bar_dark = nil
local function sync_chrome_to_omarchy_bar()
  local dark = omarchy_bar_is_dark()
  if dark == last_bar_dark then
    return
  end
  last_bar_dark = dark
  apply_chrome_mode(dark)
end

sync_chrome_to_omarchy_bar()
hl.timer(sync_chrome_to_omarchy_bar, { timeout = 400, type = "repeat" })

-- Show bars on windows that were tagged hidden by the old tiled-only rule.
for _, w in ipairs(hl.get_windows() or {}) do
  hl.dispatch(hl.dsp.window.tag({ tag = "-omawin-nobar", window = w }))
  poke_hyprbars(w)
end

-- Super+T stays float/tile. Maximize (□) is separate: workarea fill / restore.
hl.unbind("SUPER + T")
o.bind("SUPER + T", "Toggle window floating/tiling", function()
  local w = hl.get_active_window()
  if w == nil then
    return
  end
  local becoming_float = not w.floating
  hl.dispatch(hl.dsp.window.float({ action = "toggle", window = w }))
  if becoming_float then
    place_float(w)
  end
  poke_hyprbars(w)
end)

-- Super+F stays Omarchy true fullscreen; poke so the title bar redraws.
hl.unbind("SUPER + F")
o.bind("SUPER + F", "Full screen", function()
  local w = hl.get_active_window()
  hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle", window = w }))
  poke_hyprbars(w)
end)

-- SUPER + M was unbound. The title-bar – and Super+M send the window to
-- Omarchy's scratchpad (same destination as Super+Alt+S). Super+S / the bar S
-- toggles it back into view.
o.bind("SUPER + M", "Send window to scratchpad", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- SUPER + SHIFT + M was Omarchy Music (Spotify).
hl.unbind("SUPER + SHIFT + M")
o.bind("SUPER + SHIFT + M", "Restore last scratchpad window", minimize_bin .. " restore")
