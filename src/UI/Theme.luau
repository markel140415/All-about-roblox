--[[
	UI/Theme
	Colors and metrics. Reads Studio's own theme so the plugin looks native
	in both Dark and Light, and falls back to sane values outside Studio.
]]

local Theme = {}

Theme.metrics = {
	padding = 12,
	gap = 8,
	cornerRadius = 6,
	headerHeight = 40,
	tabHeight = 30,
	buttonHeight = 30,
	lineHeight = 18,
	titleSize = 16,
	bodySize = 14,
	smallSize = 12,
	codeSize = 13,
}

local FALLBACK = {
	background = Color3.fromRGB(46, 46, 46),
	panel = Color3.fromRGB(37, 37, 37),
	panelAlt = Color3.fromRGB(53, 53, 53),
	border = Color3.fromRGB(26, 26, 26),
	text = Color3.fromRGB(226, 226, 226),
	subText = Color3.fromRGB(160, 160, 160),
	accent = Color3.fromRGB(0, 162, 255),
	accentText = Color3.fromRGB(255, 255, 255),
	success = Color3.fromRGB(87, 187, 106),
	warning = Color3.fromRGB(226, 168, 62),
	error = Color3.fromRGB(226, 88, 88),
	codeBackground = Color3.fromRGB(30, 30, 30),
}

--[[
	Builds a palette from Studio's active theme.
	`studio` is settings():GetService("Studio"); nil outside Studio.
]]
function Theme.palette(studio)
	if not studio then
		return FALLBACK
	end

	local ok, theme = pcall(function()
		return studio.Theme
	end)
	if not ok or not theme then
		return FALLBACK
	end

	local function color(styleGuideColor, modifier)
		local success, value = pcall(function()
			if modifier then
				return theme:GetColor(styleGuideColor, modifier)
			end
			return theme:GetColor(styleGuideColor)
		end)
		return success and value or nil
	end

	local guide = Enum.StudioStyleGuideColor
	local modifier = Enum.StudioStyleGuideModifier

	return {
		background = color(guide.MainBackground) or FALLBACK.background,
		panel = color(guide.ViewPortBackground) or FALLBACK.panel,
		panelAlt = color(guide.Tab) or FALLBACK.panelAlt,
		border = color(guide.Border) or FALLBACK.border,
		text = color(guide.MainText) or FALLBACK.text,
		subText = color(guide.SubText) or FALLBACK.subText,
		accent = color(guide.LinkText) or FALLBACK.accent,
		accentText = color(guide.MainText, modifier.Selected) or FALLBACK.accentText,
		success = FALLBACK.success,
		warning = FALLBACK.warning,
		error = color(guide.ErrorText) or FALLBACK.error,
		codeBackground = color(guide.ScriptBackground) or FALLBACK.codeBackground,
	}
end

Theme.fallback = FALLBACK

return Theme
