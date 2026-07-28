--[[
	AnimTeacher — AI Animation Teacher for Roblox Studio
	Entry point: creates the toolbar button and the dock widget, wires Studio
	services into the app, and persists progress through plugin settings.

	This is the only file that talks to the Plugin object.
]]

local Progress = require(script.Parent.Core.Progress)
local Strings = require(script.Parent.Data.Strings)
local App = require(script.Parent.UI.App)

-- `plugin` is injected by Studio. When the module is required from somewhere
-- else (tests, bundling) we simply do nothing.
local pluginObject = plugin
if not pluginObject then
	return {}
end

----------------------------------------------------------------------
-- services
----------------------------------------------------------------------

local function safeService(name)
	local ok, service = pcall(function()
		return game:GetService(name)
	end)
	return ok and service or nil
end

local StarterPlayer = safeService("StarterPlayer")

local services = {
	workspace = safeService("Workspace"),
	serverScriptService = safeService("ServerScriptService"),
	replicatedStorage = safeService("ReplicatedStorage"),
	starterPack = safeService("StarterPack"),
	selection = safeService("Selection"),
	changeHistory = safeService("ChangeHistoryService"),
	starterPlayerScripts = StarterPlayer and StarterPlayer:FindFirstChild("StarterPlayerScripts") or nil,
	starterCharacterScripts = StarterPlayer and StarterPlayer:FindFirstChild("StarterCharacterScripts") or nil,
}

local ok, studio = pcall(function()
	return settings():GetService("Studio")
end)
services.studio = ok and studio or nil

----------------------------------------------------------------------
-- persistence
----------------------------------------------------------------------

local store = {
	get = function(key)
		local success, value = pcall(function()
			return pluginObject:GetSetting(key)
		end)
		return success and value or nil
	end,
	set = function(key, value)
		pcall(function()
			pluginObject:SetSetting(key, value)
		end)
	end,
}

local progress = Progress.new(store)
local strings = Strings.get(progress:getLanguage())

----------------------------------------------------------------------
-- toolbar + widget
----------------------------------------------------------------------

local toolbar = pluginObject:CreateToolbar(strings.toolbarName)
local button = toolbar:CreateButton(
	strings.buttonTitle,
	strings.buttonTooltip,
	"rbxasset://textures/AnimationEditor/button_control_play.png"
)
button.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false, -- not enabled on first run
	false, -- do not override the saved state
	360, -- default width
	560, -- default height
	300, -- minimum width
	300 -- minimum height
)

local widget = pluginObject:CreateDockWidgetPluginGui("AnimTeacherWidget", widgetInfo)
widget.Title = strings.pluginTitle
widget.Name = "AnimTeacherWidget"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

----------------------------------------------------------------------
-- app
----------------------------------------------------------------------

local app = nil

local function ensureApp()
	if not app then
		app = App.new(widget, progress, services)
	end
	return app
end

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	button:SetActive(widget.Enabled)
	if widget.Enabled then
		ensureApp()
	end
end)

-- Rebuild on Studio theme change so colors stay native.
if services.studio then
	services.studio.ThemeChanged:Connect(function()
		if app then
			for _, child in ipairs(widget:GetChildren()) do
				child:Destroy()
			end
			app = nil
			if widget.Enabled then
				ensureApp()
			end
		end
	end)
end

if widget.Enabled then
	ensureApp()
end

return {}
