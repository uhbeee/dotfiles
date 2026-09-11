local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "rose-pine-moon"
config.font = wezterm.font("Hack Nerd Font")
config.font_size = 15.0
config.window_background_opacity = 0.8
config.macos_window_background_blur = 50
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

-- Dim unfocused windows so the focused one is obvious at a glance.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.25, brightness = 0.45 }
local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = 0.62

-- get_config_overrides() hands back a copy, so the current value is never the
-- same table we last stored; compare the fields instead of the identity.
local function same_text_hsb(actual, expected)
	if actual == nil or expected == nil then
		return actual == expected
	end
	return actual.hue == expected.hue
		and actual.saturation == expected.saturation
		and actual.brightness == expected.brightness
end

wezterm.on("window-focus-changed", function(window)
	local overrides = window:get_config_overrides() or {}
	local text_hsb, opacity
	if not window:is_focused() then
		text_hsb = UNFOCUSED_FOREGROUND_TEXT_HSB
		opacity = UNFOCUSED_WINDOW_BACKGROUND_OPACITY
	end

	-- Only write when one of the two values we own actually changes; a redundant
	-- set_config_overrides() call would trigger another config reload.
	if same_text_hsb(overrides.foreground_text_hsb, text_hsb) and overrides.window_background_opacity == opacity then
		return
	end

	overrides.foreground_text_hsb = text_hsb
	overrides.window_background_opacity = opacity
	window:set_config_overrides(overrides)
end)

-- Machine-local tweaks live outside everything the library manages and
-- survive every update. The file receives the config table to mutate.
-- Absent file, silent skip; a broken file must not take the terminal down.
local local_cfg = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config"))
	.. "/dotfiles-local/wezterm.lua"
local f = io.open(local_cfg, "r")
if f then
	f:close()
	local ok, localfn = pcall(dofile, local_cfg)
	if ok and type(localfn) == "function" then
		local applied, err = pcall(localfn, config)
		if not applied then
			wezterm.log_error("dotfiles-local/wezterm.lua failed: " .. tostring(err))
		end
	elseif not ok then
		wezterm.log_error("dotfiles-local/wezterm.lua failed to load: " .. tostring(localfn))
	end
end

return config
