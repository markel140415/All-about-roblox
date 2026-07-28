--[[
	A small Roblox API mock: enough of the DataModel, Instance, Enum, UDim2,
	Color3 and Plugin surface to boot the real plugin bundle outside Studio.

	This exists so the UI layer (UI/App, Main) is executed in tests instead of
	only being eyeballed. It catches typos, nil indexing, bad Enum names and
	broken event wiring that pure-logic tests cannot see.

	Returns a factory: mock.install() -> environment table
]]

local M = {}

----------------------------------------------------------------------
-- Enum
----------------------------------------------------------------------

local function makeEnum(name, items)
	local enum = { __enumName = name }
	for _, item in ipairs(items) do
		enum[item] = { Name = item, Value = item, EnumType = name }
	end
	return enum
end

local Enum = {
	InitialDockState = makeEnum("InitialDockState", { "Float", "Right", "Left", "Top", "Bottom" }),
	FillDirection = makeEnum("FillDirection", { "Horizontal", "Vertical" }),
	SortOrder = makeEnum("SortOrder", { "LayoutOrder", "Name" }),
	AutomaticSize = makeEnum("AutomaticSize", { "None", "X", "Y", "XY" }),
	ScrollingDirection = makeEnum("ScrollingDirection", { "X", "Y", "XY" }),
	TextXAlignment = makeEnum("TextXAlignment", { "Left", "Center", "Right" }),
	TextYAlignment = makeEnum("TextYAlignment", { "Top", "Center", "Bottom" }),
	Font = makeEnum("Font", { "Gotham", "GothamMedium", "GothamBold", "Code", "SourceSans" }),
	ZIndexBehavior = makeEnum("ZIndexBehavior", { "Global", "Sibling" }),
	FinishRecordingOperation = makeEnum("FinishRecordingOperation", { "Commit", "Cancel", "Append" }),
	AnimationPriority = makeEnum("AnimationPriority", {
		"Core", "Idle", "Movement", "Action", "Action2", "Action3", "Action4",
	}),
	IKControlType = makeEnum("IKControlType", { "Position", "Rotation", "LookAt", "Transform" }),
	KeyCode = makeEnum("KeyCode", { "E", "Q", "R", "F" }),
	StudioStyleGuideColor = makeEnum("StudioStyleGuideColor", {
		"MainBackground", "ViewPortBackground", "Tab", "Border", "MainText",
		"SubText", "LinkText", "ErrorText", "ScriptBackground",
	}),
	StudioStyleGuideModifier = makeEnum("StudioStyleGuideModifier", {
		"Default", "Selected", "Pressed", "Disabled", "Hover",
	}),
}

----------------------------------------------------------------------
-- value types
----------------------------------------------------------------------

local UDim = {}
UDim.new = function(scale, offset)
	return { Scale = scale or 0, Offset = offset or 0 }
end

local UDim2 = {}
UDim2.new = function(xs, xo, ys, yo)
	return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }
end

local Color3 = {}
Color3.new = function(r, g, b)
	return { R = r or 0, G = g or 0, B = b or 0 }
end
Color3.fromRGB = function(r, g, b)
	return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 }
end

----------------------------------------------------------------------
-- signals
----------------------------------------------------------------------

local function makeSignal()
	local handlers = {}
	local signal = {}
	function signal:Connect(fn)
		handlers[#handlers + 1] = fn
		return {
			Disconnect = function()
				for i, h in ipairs(handlers) do
					if h == fn then
						table.remove(handlers, i)
						break
					end
				end
			end,
		}
	end
	function signal:Fire(...)
		for _, fn in ipairs(handlers) do
			fn(...)
		end
	end
	function signal:HandlerCount()
		return #handlers
	end
	return signal
end

M.makeSignal = makeSignal

----------------------------------------------------------------------
-- Instance
----------------------------------------------------------------------

-- Minimal class hierarchy for IsA().
local INHERITS = {
	Instance = {},
	Folder = { "Instance" },
	Model = { "Instance" },
	Part = { "BasePart", "Instance" },
	BasePart = { "Instance" },
	Motor6D = { "JointInstance", "Instance" },
	JointInstance = { "Instance" },
	Script = { "LuaSourceContainer", "Instance" },
	LocalScript = { "LuaSourceContainer", "Instance" },
	ModuleScript = { "LuaSourceContainer", "Instance" },
	LuaSourceContainer = { "Instance" },
	Frame = { "GuiObject", "Instance" },
	ScrollingFrame = { "GuiObject", "Instance" },
	TextLabel = { "GuiObject", "Instance" },
	TextButton = { "GuiObject", "Instance" },
	TextBox = { "GuiObject", "Instance" },
	GuiObject = { "Instance" },
	UICorner = { "Instance" },
	UIPadding = { "Instance" },
	UIListLayout = { "Instance" },
}

local Instance = {}

local function newInstance(className)
	local children = {}
	local propertySignals = {}

	local self
	local proxy
	self = {
		ClassName = className,
		Name = className,
		Parent = nil,
		_children = children,
		_destroyed = false,
	}

	-- GUI-ish defaults so property writes never fail.
	self.Text = ""
	self.Source = nil
	self.Visible = true
	self.Enabled = false

	-- GUI event surface the plugin connects to.
	if className == "TextButton" then
		self.MouseButton1Click = makeSignal()
		self.Activated = makeSignal()
	elseif className == "TextBox" then
		self.FocusLost = makeSignal()
		self.Focused = makeSignal()
	end

	function self:GetChildren()
		local out = {}
		for i, child in ipairs(children) do
			out[i] = child
		end
		return out
	end

	function self:GetDescendants()
		local out = {}
		local function walk(node)
			for _, child in ipairs(node._children or {}) do
				out[#out + 1] = child
				walk(child)
			end
		end
		walk(self)
		return out
	end

	function self:FindFirstChild(name)
		for _, child in ipairs(children) do
			if child.Name == name then
				return child
			end
		end
		return nil
	end

	function self:FindFirstChildOfClass(className2)
		for _, child in ipairs(children) do
			if child.ClassName == className2 then
				return child
			end
		end
		return nil
	end

	function self:IsA(query)
		if self.ClassName == query then
			return true
		end
		for _, ancestor in ipairs(INHERITS[self.ClassName] or {}) do
			if ancestor == query then
				return true
			end
		end
		return false
	end

	function self:Destroy()
		self._destroyed = true
		if self.Parent then
			local siblings = self.Parent._children
			for i, child in ipairs(siblings) do
				if child == proxy then
					table.remove(siblings, i)
					break
				end
			end
		end
		self.Parent = nil
	end

	function self:GetPropertyChangedSignal(property)
		propertySignals[property] = propertySignals[property] or makeSignal()
		return propertySignals[property]
	end

	function self:SetActive() end
	function self:WaitForChild(name)
		return self:FindFirstChild(name)
	end

	self._propertySignals = propertySignals

	-- Proxy intercepts Parent assignment to maintain the tree, and fires
	-- property changed signals like the real engine does.
	proxy = setmetatable({}, {
		__index = self,
		__newindex = function(_, key, value)
			if key == "Parent" then
				local old = self.Parent
				if old then
					for i, child in ipairs(old._children) do
						if child == proxy then
							table.remove(old._children, i)
							break
						end
					end
				end
				self.Parent = value
				if value then
					table.insert(value._children, proxy)
				end
			else
				self[key] = value
			end
			local signal = propertySignals[key]
			if signal then
				signal:Fire()
			end
		end,
		__tostring = function()
			return self.Name
		end,
	})

	return proxy
end

Instance.new = function(className)
	return newInstance(className)
end

M.newInstance = newInstance

----------------------------------------------------------------------
-- environment
----------------------------------------------------------------------

--[[
	Builds the globals a plugin expects. Returns a table with the globals plus
	handles the tests can poke at (widget, button, services, settings store).
]]
function M.install(options)
	options = options or {}

	local services = {}
	local function service(name, className)
		local inst = newInstance(className or name)
		inst.Name = name
		services[name] = inst
		return inst
	end

	service("Workspace")
	service("ServerScriptService")
	service("ReplicatedStorage")
	service("StarterPack")
	local starterPlayer = service("StarterPlayer")

	local sps = newInstance("Folder")
	sps.Name = "StarterPlayerScripts"
	sps.Parent = starterPlayer
	local scs = newInstance("Folder")
	scs.Name = "StarterCharacterScripts"
	scs.Parent = starterPlayer

	local selected = {}
	services.Selection = {
		Set = function(_, list)
			selected = list
		end,
		Get = function()
			return selected
		end,
	}

	local recordings = {}
	services.ChangeHistoryService = {
		TryBeginRecording = function(_, name)
			recordings[#recordings + 1] = name
			return "recording-" .. #recordings
		end,
		FinishRecording = function() end,
	}

	local themeChanged = makeSignal()
	local studioTheme = {
		GetColor = function(_, styleGuideColor)
			-- Return a deterministic colour so Theme.palette works.
			return Color3.fromRGB(40, 40, 40)
		end,
	}
	local studio = {
		Theme = studioTheme,
		ThemeChanged = themeChanged,
	}

	local settingsStore = {}
	local widget = nil
	local button = nil

	local pluginObject = {
		CreateToolbar = function(_, name)
			return {
				_name = name,
				CreateButton = function(_, title, tooltip, icon)
					button = {
						Title = title,
						Tooltip = tooltip,
						Icon = icon,
						ClickableWhenViewportHidden = false,
						Click = makeSignal(),
						SetActive = function() end,
					}
					return button
				end,
			}
		end,
		CreateDockWidgetPluginGui = function(_, id, info)
			widget = newInstance("DockWidgetPluginGui")
			widget.Name = id
			widget.Title = ""
			widget.Enabled = options.widgetEnabled or false
			widget._info = info
			return widget
		end,
		GetSetting = function(_, key)
			return settingsStore[key]
		end,
		SetSetting = function(_, key, value)
			settingsStore[key] = value
		end,
	}

	local game = {
		GetService = function(_, name)
			local found = services[name]
			if not found then
				error("mock: unknown service " .. tostring(name), 2)
			end
			return found
		end,
	}

	local globals = {
		Instance = Instance,
		Enum = Enum,
		UDim = UDim,
		UDim2 = UDim2,
		Color3 = Color3,
		game = game,
		plugin = pluginObject,
		settings = function()
			return {
				GetService = function()
					return studio
				end,
			}
		end,
		DockWidgetPluginGuiInfo = {
			new = function(...)
				return { ... }
			end,
		},
	}

	return {
		globals = globals,
		services = services,
		settingsStore = settingsStore,
		themeChanged = themeChanged,
		getWidget = function()
			return widget
		end,
		getButton = function()
			return button
		end,
		getSelection = function()
			return selected
		end,
		starterPlayerScripts = sps,
		starterCharacterScripts = scs,
		newInstance = newInstance,
	}
end

return M
