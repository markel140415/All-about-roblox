--[[
	UI/Components
	Small factory helpers for the Instance-based UI.
	Keeping creation in one place keeps the view files readable and makes
	restyling a one-line change.
]]

local Theme = require(script.Parent.Theme)

local Components = {}

local M = Theme.metrics

function Components.corner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or M.cornerRadius)
	corner.Parent = parent
	return corner
end

function Components.padding(parent, amount)
	local pad = Instance.new("UIPadding")
	local value = UDim.new(0, amount or M.padding)
	pad.PaddingTop = value
	pad.PaddingBottom = value
	pad.PaddingLeft = value
	pad.PaddingRight = value
	pad.Parent = parent
	return pad
end

function Components.listLayout(parent, gap, direction)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction or Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap or M.gap)
	layout.Parent = parent
	return layout
end

function Components.frame(props)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = props.color or Color3.new(0, 0, 0)
	frame.BackgroundTransparency = props.transparent and 1 or 0
	frame.BorderSizePixel = 0
	frame.Size = props.size or UDim2.new(1, 0, 0, 0)
	frame.Position = props.position or UDim2.new(0, 0, 0, 0)
	frame.LayoutOrder = props.order or 0
	frame.AutomaticSize = props.automaticSize or Enum.AutomaticSize.None
	frame.Name = props.name or "Frame"
	frame.Parent = props.parent
	return frame
end

function Components.scroll(props)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundColor3 = props.color or Color3.new(0, 0, 0)
	scroll.BackgroundTransparency = props.transparent and 1 or 0
	scroll.BorderSizePixel = 0
	scroll.Size = props.size or UDim2.new(1, 0, 1, 0)
	scroll.Position = props.position or UDim2.new(0, 0, 0, 0)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Name = props.name or "Scroll"
	scroll.Parent = props.parent
	return scroll
end

--[[ A wrapping, auto-height text label. ]]
function Components.label(props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = props.size or UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = props.automaticSize or Enum.AutomaticSize.Y
	label.Font = props.font or Enum.Font.Gotham
	label.TextSize = props.textSize or M.bodySize
	label.TextColor3 = props.color or Color3.new(1, 1, 1)
	label.TextXAlignment = props.align or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = props.wrapped ~= false
	label.RichText = props.richText or false
	label.Text = props.text or ""
	label.LayoutOrder = props.order or 0
	label.Name = props.name or "Label"
	label.Parent = props.parent
	return label
end

function Components.button(props)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = props.color or Color3.fromRGB(0, 162, 255)
	button.BackgroundTransparency = props.transparent and 1 or 0
	button.BorderSizePixel = 0
	button.Size = props.size or UDim2.new(1, 0, 0, M.buttonHeight)
	button.Position = props.position or UDim2.new(0, 0, 0, 0)
	button.Font = props.font or Enum.Font.GothamMedium
	button.TextSize = props.textSize or M.bodySize
	button.TextColor3 = props.textColor or Color3.new(1, 1, 1)
	button.Text = props.text or ""
	button.TextWrapped = props.wrapped or false
	button.AutoButtonColor = true
	button.LayoutOrder = props.order or 0
	button.AutomaticSize = props.automaticSize or Enum.AutomaticSize.None
	button.Name = props.name or "Button"
	button.Parent = props.parent
	if props.rounded ~= false then
		Components.corner(button, props.radius)
	end
	if props.onClick then
		button.MouseButton1Click:Connect(props.onClick)
	end
	return button
end

--[[ Read-only code block with a monospaced font. ]]
function Components.codeBlock(props)
	local container = Components.frame({
		parent = props.parent,
		color = props.background,
		size = UDim2.new(1, 0, 0, 0),
		automaticSize = Enum.AutomaticSize.Y,
		order = props.order or 0,
		name = "CodeBlock",
	})
	Components.corner(container, 4)
	Components.padding(container, 10)

	Components.label({
		parent = container,
		text = props.text or "",
		font = Enum.Font.Code,
		textSize = M.codeSize,
		color = props.color,
		wrapped = false,
	})

	return container
end

function Components.textBox(props)
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = props.color or Color3.fromRGB(30, 30, 30)
	box.BorderSizePixel = 0
	box.Size = props.size or UDim2.new(1, 0, 0, M.buttonHeight)
	box.Font = Enum.Font.Gotham
	box.TextSize = props.textSize or M.bodySize
	box.TextColor3 = props.textColor or Color3.new(1, 1, 1)
	box.PlaceholderText = props.placeholder or ""
	box.PlaceholderColor3 = props.placeholderColor or Color3.fromRGB(140, 140, 140)
	box.Text = ""
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = false
	box.LayoutOrder = props.order or 0
	box.Name = props.name or "TextBox"
	box.Parent = props.parent
	Components.corner(box, 4)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = box

	return box
end

--[[ Thin horizontal rule. ]]
function Components.divider(parent, color, order)
	local line = Components.frame({
		parent = parent,
		color = color,
		size = UDim2.new(1, 0, 0, 1),
		order = order or 0,
		name = "Divider",
	})
	return line
end

--[[ A simple progress bar; `fraction` is 0..1. ]]
function Components.progressBar(props)
	local track = Components.frame({
		parent = props.parent,
		color = props.trackColor,
		size = UDim2.new(1, 0, 0, 8),
		order = props.order or 0,
		name = "ProgressTrack",
	})
	Components.corner(track, 4)

	local fill = Components.frame({
		parent = track,
		color = props.fillColor,
		size = UDim2.new(math.max(0, math.min(1, props.fraction or 0)), 0, 1, 0),
		name = "ProgressFill",
	})
	Components.corner(fill, 4)

	return track, fill
end

return Components
