--[[
	End-to-end test: boots the REAL plugin bundle inside a Roblox API mock and
	drives the UI the way a user would (open widget, switch tabs, open a
	lesson, answer a quiz, insert code, run a check, switch language).

	This is what proves the plugin actually runs rather than merely compiles.
]]

local H = (function()
	local f = io.open(ROOT_DIR .. "/tests/helpers.lua", "r")
	local src = f:read("*a")
	f:close()
	return load(src, "@helpers.lua")()
end)()

local Mock = (function()
	local f = io.open(ROOT_DIR .. "/tests/roblox_mock.lua", "r")
	local src = f:read("*a")
	f:close()
	return load(src, "@roblox_mock.lua")()
end)()

----------------------------------------------------------------------
-- boot the bundle
----------------------------------------------------------------------

local function loadBundle(env)
	local f = io.open(ROOT_DIR .. "/build/AnimTeacher.luau", "r")
	if not f then
		error("build/AnimTeacher.luau missing - run tools/build.py first")
	end
	local src = f:read("*a")
	f:close()

	-- Sandbox: plugin globals first, then the standard library.
	local sandbox = setmetatable({}, { __index = function(_, key)
		local value = env.globals[key]
		if value ~= nil then
			return value
		end
		return _G[key]
	end })

	local chunk, err = load(src, "@AnimTeacher.luau", "t", sandbox)
	if not chunk then
		error("bundle failed to compile: " .. tostring(err))
	end
	return chunk
end

H.section("Plugin boots without errors")
local env = Mock.install({ widgetEnabled = false })
local chunk = loadBundle(env)
local bootOk, bootErr = pcall(chunk)
H.ok(bootOk, "bundle executes: " .. (bootOk and "ok" or tostring(bootErr)))

local widget = env.getWidget()
local button = env.getButton()
H.ok(widget ~= nil, "dock widget created")
H.ok(button ~= nil, "toolbar button created")
H.ok(button and button.ClickableWhenViewportHidden == true, "button clickable when viewport hidden")

H.section("Widget starts hidden and toggles on click")
H.equal(widget.Enabled, false, "hidden on first run")
button.Click:Fire()
H.equal(widget.Enabled, true, "click enables the widget")

-- Enabling fires the property signal which builds the UI.
local function uiRoot()
	for _, child in ipairs(widget:GetChildren()) do
		if child.Name == "AnimTeacher" then
			return child
		end
	end
	return nil
end

H.ok(uiRoot() ~= nil, "UI built when the widget is shown")

----------------------------------------------------------------------
-- walk the widget tree
----------------------------------------------------------------------

local function descendantsOf(node)
	return node:GetDescendants()
end

local function findButtons(node)
	local out = {}
	for _, d in ipairs(descendantsOf(node)) do
		if d.ClassName == "TextButton" then
			out[#out + 1] = d
		end
	end
	return out
end

local function findByText(node, text)
	for _, d in ipairs(descendantsOf(node)) do
		local value = rawget(d, "Text") or d.Text
		if type(value) == "string" and string.find(value, text, 1, true) then
			return d
		end
	end
	return nil
end

--[[ Same search but restricted to clickable buttons. ]]
local function findButtonByText(node, text)
	for _, d in ipairs(descendantsOf(node)) do
		if d.ClassName == "TextButton" then
			local value = d.Text
			if type(value) == "string" and string.find(value, text, 1, true) then
				return d
			end
		end
	end
	return nil
end

local function labelTexts(node)
	local out = {}
	for _, d in ipairs(descendantsOf(node)) do
		if d.ClassName == "TextLabel" then
			out[#out + 1] = d.Text
		end
	end
	return out
end

H.section("Home screen renders course content")
local root = uiRoot()
H.ok(#findButtons(root) >= 4, "home has navigation buttons (" .. #findButtons(root) .. ")")
H.ok(findByText(root, "Модуль 1") ~= nil, "module 1 listed (Russian by default)")
H.ok(findByText(root, "Модуль 4") ~= nil, "module 4 listed")

H.section("Language toggle switches the whole UI")
local toggle = findButtonByText(root, "English")
H.ok(toggle ~= nil, "language button present")
toggle.MouseButton1Click:Fire()
root = uiRoot()
H.ok(findByText(root, "Module 1") ~= nil, "UI switched to English")
H.ok(env.settingsStore["AnimTeacher_language"] == "en", "language persisted to settings")
-- switch back
findButtonByText(root, "Русский").MouseButton1Click:Fire()
root = uiRoot()
H.ok(findByText(root, "Модуль 1") ~= nil, "switched back to Russian")

H.section("Opening a lesson renders theory, steps and a quiz")
root = uiRoot()
local continueButton = findButtonByText(root, "Начать курс") or findButtonByText(root, "Продолжить обучение")
H.ok(continueButton ~= nil, "continue/start button present")
continueButton.MouseButton1Click:Fire()
root = uiRoot()
H.ok(findByText(root, "Теория") ~= nil, "theory section rendered")
H.ok(findByText(root, "Что делать в Studio") ~= nil, "steps section rendered")
H.ok(findByText(root, "Проверь себя") ~= nil, "quiz section rendered")
H.ok(#labelTexts(root) > 8, "lesson has substantial content")

H.section("Answering the quiz gives feedback and is recorded")
-- The first lesson's correct answer is option 2.
local quizButtons = {}
for _, b in ipairs(findButtons(root)) do
	if string.sub(b.Text, 1, 2) == "  " then
		quizButtons[#quizButtons + 1] = b
	end
end
H.equal(#quizButtons, 4, "four quiz options rendered")
quizButtons[2].MouseButton1Click:Fire()
root = uiRoot()
H.ok(findByText(root, "Верно!") ~= nil, "correct answer acknowledged")
H.ok(env.settingsStore["AnimTeacher_quiz"] ~= nil, "quiz result persisted")

H.section("Marking a lesson complete persists progress")
local markButton = findButtonByText(root, "Отметить пройденным")
H.ok(markButton ~= nil, "mark-as-done button present")
markButton.MouseButton1Click:Fire()
root = uiRoot()
local completed = env.settingsStore["AnimTeacher_completed"]
H.ok(completed ~= nil and completed["1-1-what-is-animation"] == true, "completion persisted")

H.section("'Check my work' inspects the real place")
root = uiRoot()
local checkButton = findButtonByText(root, "Проверить мою работу")
H.ok(checkButton ~= nil, "check button present on lesson 1")
checkButton.MouseButton1Click:Fire()
root = uiRoot()
H.ok(findByText(root, "нет модели с Motor6D")
	or findByText(root, "Вставьте риг") ~= nil, "reports the missing rig")

-- Now add a rig to the mock Workspace and re-check.
local workspaceService = env.services.Workspace
local rig = env.newInstance("Model")
rig.Name = "Dummy"
rig.Parent = workspaceService
local torso = env.newInstance("Part")
torso.Name = "UpperTorso"
torso.Parent = rig
local motor = env.newInstance("Motor6D")
motor.Name = "Neck"
motor.Parent = torso

findButtonByText(uiRoot(), "Проверить мою работу").MouseButton1Click:Fire()
root = uiRoot()
H.ok(findByText(root, "Нашёл риг") ~= nil, "detects the rig once it exists")

H.section("Inserting a code sample creates a real script")
-- Navigate to lesson 2-1 which carries a snippet.
findButtonByText(uiRoot(), "Назад").MouseButton1Click:Fire()
root = uiRoot()
local lessonButton = findButtonByText(root, "Animator и AnimationTrack")
H.ok(lessonButton ~= nil, "lesson list shows lesson 2-1")
lessonButton.MouseButton1Click:Fire()
root = uiRoot()

local insertButton = findButtonByText(root, "Вставить код")
H.ok(insertButton ~= nil, "insert button present")
insertButton.MouseButton1Click:Fire()

local inserted = nil
for _, d in ipairs(env.starterPlayerScripts:GetDescendants()) do
	if d.ClassName == "LocalScript" then
		inserted = d
	end
end
H.ok(inserted ~= nil, "LocalScript inserted into StarterPlayerScripts")
H.ok(inserted and string.find(inserted.Source, "animator:LoadAnimation", 1, true) ~= nil,
	"inserted code uses the modern API")
H.ok(#env.getSelection() == 1, "inserted script is selected for the user")

H.section("Ask tab answers a free-form question")
root = uiRoot()
local askTab = findButtonByText(root, "Вопрос")
H.ok(askTab ~= nil, "Ask tab present")
askTab.MouseButton1Click:Fire()
root = uiRoot()

local box = nil
for _, d in ipairs(descendantsOf(root)) do
	if d.ClassName == "TextBox" then
		box = d
	end
end
H.ok(box ~= nil, "question box rendered")
box.Text = "Почему моя анимация не работает?"
box.FocusLost:Fire(true)
root = uiRoot()
H.ok(findByText(root, "не проигрывается") ~= nil or findByText(root, "диагностика") ~= nil,
	"tutor answered the troubleshooting question")

H.section("Progress tab reflects completed work")
findButtonByText(uiRoot(), "Прогресс").MouseButton1Click:Fire()
root = uiRoot()
H.ok(findByText(root, "Пройдено уроков") ~= nil, "progress tab rendered")
H.ok(findByText(root, "Сбросить прогресс") ~= nil, "reset button present")

H.section("Progress survives a plugin restart")
local env2 = Mock.install({ widgetEnabled = true })
-- carry the previous settings over, as Studio would
for key, value in pairs(env.settingsStore) do
	env2.settingsStore[key] = value
end
local chunk2 = loadBundle(env2)
local ok2 = pcall(chunk2)
H.ok(ok2, "second boot succeeds with existing settings")
local root2 = nil
for _, child in ipairs(env2.getWidget():GetChildren()) do
	if child.Name == "AnimTeacher" then
		root2 = child
	end
end
H.ok(root2 ~= nil, "UI built immediately when the widget starts enabled")
H.ok(findByText(root2, "Продолжить обучение") ~= nil, "resumes with 'continue learning'")

return H.summary()
