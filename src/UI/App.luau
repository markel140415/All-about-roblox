--[[
	UI/App
	The whole plugin interface: three tabs (Course / Ask / Progress), lesson
	rendering, quizzes, code insertion and "check my work".

	Everything Roblox-specific that the logic modules need is gathered here and
	passed down, so Brain/* and Core/* stay testable.
]]

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Lessons = require(script.Parent.Parent.Data.Lessons)
local Snippets = require(script.Parent.Parent.Data.Snippets)
local Strings = require(script.Parent.Parent.Data.Strings)
local Answer = require(script.Parent.Parent.Brain.Answer)
local Checks = require(script.Parent.Parent.Brain.Checks)

local App = {}
App.__index = App

local M = Theme.metrics

----------------------------------------------------------------------
-- construction
----------------------------------------------------------------------

--[[
	services: {
		workspace, starterPlayerScripts, serverScriptService,
		starterCharacterScripts, replicatedStorage, starterPack,
		selection, studio, changeHistory,
	}
]]
function App.new(root, progress, services)
	local self = setmetatable({}, App)
	self.root = root
	self.progress = progress
	self.services = services or {}
	self.palette = Theme.palette(services and services.studio)
	self.language = progress:getLanguage()
	self.strings = Strings.get(self.language)
	self.tab = "course"
	self.view = { name = "home" }
	self._resetArmed = false
	self:_build()
	self:render()
	return self
end

function App:_build()
	local palette = self.palette

	self.container = Components.frame({
		parent = self.root,
		color = palette.background,
		size = UDim2.new(1, 0, 1, 0),
		name = "AnimTeacher",
	})

	-- Header: title + language toggle
	self.header = Components.frame({
		parent = self.container,
		color = palette.panel,
		size = UDim2.new(1, 0, 0, M.headerHeight),
		name = "Header",
	})

	self.headerLabel = Components.label({
		parent = self.header,
		text = "",
		font = Enum.Font.GothamBold,
		textSize = M.titleSize,
		color = palette.text,
		size = UDim2.new(1, -110, 1, 0),
		position = UDim2.new(0, M.padding, 0, 0),
		automaticSize = Enum.AutomaticSize.None,
	})
	self.headerLabel.TextYAlignment = Enum.TextYAlignment.Center

	self.languageButton = Components.button({
		parent = self.header,
		text = "",
		color = palette.panelAlt,
		textColor = palette.text,
		textSize = M.smallSize,
		size = UDim2.new(0, 90, 0, 24),
		position = UDim2.new(1, -98, 0, 8),
		onClick = function()
			self:toggleLanguage()
		end,
	})

	-- Tab bar
	self.tabBar = Components.frame({
		parent = self.container,
		color = palette.panel,
		size = UDim2.new(1, 0, 0, M.tabHeight),
		position = UDim2.new(0, 0, 0, M.headerHeight),
		name = "TabBar",
	})
	Components.listLayout(self.tabBar, 0, Enum.FillDirection.Horizontal)

	self.tabButtons = {}
	for _, info in ipairs({
		{ id = "course", key = "tabCourse" },
		{ id = "chat", key = "tabChat" },
		{ id = "progress", key = "tabProgress" },
	}) do
		local button = Components.button({
			parent = self.tabBar,
			text = "",
			color = palette.panel,
			textColor = palette.subText,
			size = UDim2.new(1 / 3, 0, 1, 0),
			rounded = false,
			onClick = function()
				self:setTab(info.id)
			end,
		})
		self.tabButtons[info.id] = { button = button, key = info.key }
	end

	-- Content area
	self.content = Components.scroll({
		parent = self.container,
		transparent = true,
		size = UDim2.new(1, 0, 1, -(M.headerHeight + M.tabHeight)),
		position = UDim2.new(0, 0, 0, M.headerHeight + M.tabHeight),
		name = "Content",
	})
	Components.padding(self.content, M.padding)
	Components.listLayout(self.content, M.gap)
end

----------------------------------------------------------------------
-- state
----------------------------------------------------------------------

function App:toggleLanguage()
	self.language = Strings.other(self.language)
	self.strings = Strings.get(self.language)
	self.progress:setLanguage(self.language)
	self:render()
end

function App:setTab(tab)
	self.tab = tab
	if tab == "course" then
		self.view = { name = "home" }
	end
	self:render()
end

function App:openLesson(lessonId)
	self.tab = "course"
	self.view = { name = "lesson", lessonId = lessonId, quizChoice = nil, feedback = nil }
	self.progress:setCurrentLesson(lessonId)
	self:render()
end

function App:_clearContent()
	for _, child in ipairs(self.content:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	self._order = 0
end

function App:_nextOrder()
	self._order = (self._order or 0) + 1
	return self._order
end

----------------------------------------------------------------------
-- rendering
----------------------------------------------------------------------

function App:render()
	local palette = self.palette
	local strings = self.strings

	self.headerLabel.Text = strings.pluginTitle
	self.languageButton.Text = strings.languageToggle

	for id, info in pairs(self.tabButtons) do
		info.button.Text = strings[info.key]
		local active = (id == self.tab)
		info.button.BackgroundColor3 = active and palette.panelAlt or palette.panel
		info.button.TextColor3 = active and palette.text or palette.subText
	end

	self:_clearContent()

	if self.tab == "course" then
		if self.view.name == "lesson" then
			self:_renderLesson()
		elseif self.view.name == "list" then
			self:_renderLessonList()
		else
			self:_renderHome()
		end
	elseif self.tab == "chat" then
		self:_renderChat()
	else
		self:_renderProgress()
	end
end

function App:_title(text)
	return Components.label({
		parent = self.content,
		text = text,
		font = Enum.Font.GothamBold,
		textSize = M.titleSize,
		color = self.palette.text,
		order = self:_nextOrder(),
	})
end

function App:_body(text, color)
	return Components.label({
		parent = self.content,
		text = text,
		textSize = M.bodySize,
		color = color or self.palette.text,
		order = self:_nextOrder(),
	})
end

function App:_muted(text)
	return Components.label({
		parent = self.content,
		text = text,
		textSize = M.smallSize,
		color = self.palette.subText,
		order = self:_nextOrder(),
	})
end

function App:_primaryButton(text, onClick)
	return Components.button({
		parent = self.content,
		text = text,
		color = self.palette.accent,
		textColor = Color3.new(1, 1, 1),
		order = self:_nextOrder(),
		onClick = onClick,
	})
end

function App:_secondaryButton(text, onClick)
	return Components.button({
		parent = self.content,
		text = text,
		color = self.palette.panelAlt,
		textColor = self.palette.text,
		order = self:_nextOrder(),
		onClick = onClick,
	})
end

----------------------------------------------------------------------
-- home
----------------------------------------------------------------------

function App:_renderHome()
	local strings = self.strings

	self:_title(strings.greetingTitle)
	self:_body(strings.greetingBody, self.palette.subText)

	local percent = self.progress:overallPercent()
	Components.progressBar({
		parent = self.content,
		fraction = percent / 100,
		trackColor = self.palette.panelAlt,
		fillColor = self.palette.accent,
		order = self:_nextOrder(),
	})
	self:_muted(string.format(
		"%s: %d / %d  (%d%%)",
		strings.progressLessons,
		self.progress:completedCount(),
		Lessons.count(),
		percent
	))

	local nextLesson = self.progress:nextLesson()
	local label = self.progress:completedCount() > 0 and strings.continueLearning or strings.startCourse
	self:_primaryButton(label .. "  ·  " .. (nextLesson.title[self.language] or nextLesson.title.en), function()
		self:openLesson(nextLesson.id)
	end)

	self:_secondaryButton(strings.lessonList, function()
		self.view = { name = "list" }
		self:render()
	end)

	Components.divider(self.content, self.palette.border, self:_nextOrder())

	-- Module overview
	for _, moduleInfo in ipairs(Lessons.modules) do
		local status = self.progress:moduleStatus(moduleInfo.id)
		local row = Components.frame({
			parent = self.content,
			color = self.palette.panel,
			size = UDim2.new(1, 0, 0, 0),
			automaticSize = Enum.AutomaticSize.Y,
			order = self:_nextOrder(),
		})
		Components.corner(row, 4)
		Components.padding(row, 10)
		Components.listLayout(row, 4)

		Components.label({
			parent = row,
			text = moduleInfo.title[self.language] or moduleInfo.title.en,
			font = Enum.Font.GothamMedium,
			textSize = M.bodySize,
			color = self.palette.text,
			order = 1,
		})
		Components.label({
			parent = row,
			text = moduleInfo.summary[self.language] or moduleInfo.summary.en,
			textSize = M.smallSize,
			color = self.palette.subText,
			order = 2,
		})
		Components.label({
			parent = row,
			text = string.format("%d / %d · %s", status.done, status.total, self.strings[status.state]),
			textSize = M.smallSize,
			color = status.state == "completed" and self.palette.success or self.palette.subText,
			order = 3,
		})
	end
end

----------------------------------------------------------------------
-- lesson list
----------------------------------------------------------------------

function App:_renderLessonList()
	self:_secondaryButton("← " .. self.strings.back, function()
		self.view = { name = "home" }
		self:render()
	end)

	local currentModule = nil
	for _, lesson in ipairs(Lessons.list) do
		if lesson.module ~= currentModule then
			currentModule = lesson.module
			local moduleInfo = Lessons.modules[currentModule]
			self:_muted(moduleInfo.title[self.language] or moduleInfo.title.en)
		end

		local done = self.progress:isCompleted(lesson.id)
		local mark = done and "✓  " or "•  "
		Components.button({
			parent = self.content,
			text = mark .. (lesson.title[self.language] or lesson.title.en)
				.. "   (" .. lesson.minutes .. " " .. self.strings.minutes .. ")",
			color = self.palette.panel,
			textColor = done and self.palette.success or self.palette.text,
			textSize = M.bodySize,
			size = UDim2.new(1, 0, 0, 32),
			order = self:_nextOrder(),
			onClick = function()
				self:openLesson(lesson.id)
			end,
		})
	end
end

----------------------------------------------------------------------
-- lesson
----------------------------------------------------------------------

function App:_renderLesson()
	local lesson = Lessons.get(self.view.lessonId)
	if not lesson then
		self.view = { name = "home" }
		return self:render()
	end

	local strings = self.strings
	local language = self.language

	self:_secondaryButton("← " .. strings.back, function()
		self.view = { name = "list" }
		self:render()
	end)

	self:_muted(string.format(
		"%s %d %s %d · %d %s",
		strings.lesson, lesson.index, strings.of, Lessons.count(), lesson.minutes, strings.minutes
	))
	self:_title(lesson.title[language] or lesson.title.en)

	-- Goal
	self:_muted(strings.sectionGoal)
	self:_body(lesson.goal[language] or lesson.goal.en)

	-- Theory
	self:_muted(strings.sectionTheory)
	for _, paragraph in ipairs(lesson.theory[language] or lesson.theory.en) do
		self:_body(paragraph)
	end

	-- Steps
	self:_muted(strings.sectionSteps)
	local steps = lesson.steps[language] or lesson.steps.en
	for index, step in ipairs(steps) do
		self:_body(index .. ".  " .. step)
	end

	-- Code sample
	if lesson.snippet then
		local snippet = Snippets.get(lesson.snippet)
		if snippet then
			self:_muted(strings.sectionCode .. " · " .. (snippet.placement[language] or snippet.placement.en))
			Components.codeBlock({
				parent = self.content,
				text = snippet.code,
				background = self.palette.codeBackground,
				color = self.palette.text,
				order = self:_nextOrder(),
			})
			self:_secondaryButton(strings.insertCode, function()
				self:insertSnippet(snippet)
			end)
		end
	end

	-- Practice
	self:_muted(strings.sectionPractice)
	self:_body(lesson.practice[language] or lesson.practice.en)

	-- Check my work
	if lesson.check and Checks.exists(lesson.check) then
		self:_secondaryButton(strings.checkWork, function()
			self:runCheck(lesson.check)
		end)
		if self.view.checkMessage then
			self:_body(self.view.checkMessage, self.view.checkPassed and self.palette.success or self.palette.warning)
		end
	end

	-- Quiz
	self:_renderQuiz(lesson)

	-- Completion + navigation
	Components.divider(self.content, self.palette.border, self:_nextOrder())

	local isDone = self.progress:isCompleted(lesson.id)
	self:_primaryButton(isDone and strings.markedDone .. " ✓" or strings.markDone, function()
		self.progress:setCompleted(lesson.id, not isDone)
		self:render()
	end)

	local nextLesson = Lessons.next(lesson.id)
	if nextLesson then
		self:_secondaryButton(strings.nextLesson .. " →", function()
			self:openLesson(nextLesson.id)
		end)
	end
end

function App:_renderQuiz(lesson)
	local quiz = lesson.quiz
	if not quiz then
		return
	end

	local strings = self.strings
	local language = self.language

	self:_muted(strings.sectionQuiz)
	self:_body(quiz.question[language] or quiz.question.en)

	for index, option in ipairs(quiz.options) do
		local chosen = self.view.quizChoice == index
		local isCorrect = index == quiz.answer
		local color = self.palette.panel
		if chosen then
			color = isCorrect and self.palette.success or self.palette.error
		end
		Components.button({
			parent = self.content,
			text = "  " .. (option[language] or option.en),
			color = color,
			textColor = self.palette.text,
			textSize = M.bodySize,
			size = UDim2.new(1, 0, 0, 30),
			order = self:_nextOrder(),
			onClick = function()
				self.view.quizChoice = index
				self.progress:setQuizResult(lesson.id, isCorrect)
				self:render()
			end,
		})
	end

	if self.view.quizChoice then
		local correct = self.view.quizChoice == quiz.answer
		self:_body(
			(correct and strings.quizCorrect or strings.quizWrong) .. " "
				.. (quiz.explain[language] or quiz.explain.en),
			correct and self.palette.success or self.palette.warning
		)
	end
end

----------------------------------------------------------------------
-- chat
----------------------------------------------------------------------

function App:_renderChat()
	local strings = self.strings

	self:_title(strings.tabChat)

	local box = Components.textBox({
		parent = self.content,
		placeholder = strings.askPlaceholder,
		color = self.palette.panel,
		textColor = self.palette.text,
		placeholderColor = self.palette.subText,
		order = self:_nextOrder(),
	})
	if self.view.lastQuestion then
		box.Text = self.view.lastQuestion
	end

	local function submit()
		local question = box.Text
		if not question or #question == 0 then
			return
		end
		self.view.lastQuestion = question
		self.view.answer = Answer.ask(question, self.language)
		self:render()
	end

	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)

	self:_primaryButton(strings.askButton, submit)

	local result = self.view.answer
	if not result then
		return
	end

	Components.divider(self.content, self.palette.border, self:_nextOrder())

	local lines = Answer.render(result, strings)
	for _, line in ipairs(lines) do
		if line.kind == "title" then
			self:_title(line.text)
		else
			self:_body(line.text)
		end
	end

	-- Offer the matching code sample.
	if result.snippet then
		local snippet = Snippets.get(result.snippet)
		if snippet then
			Components.codeBlock({
				parent = self.content,
				text = snippet.code,
				background = self.palette.codeBackground,
				color = self.palette.text,
				order = self:_nextOrder(),
			})
			self:_secondaryButton(strings.insertCode, function()
				self:insertSnippet(snippet)
			end)
		end
	end

	-- Offer the related lesson.
	if result.lesson then
		self:_secondaryButton(
			strings.relatedLesson .. (result.lesson.title[self.language] or result.lesson.title.en),
			function()
				self:openLesson(result.lesson.id)
			end
		)
	end

	if result.suggestions and #result.suggestions > 0 then
		self:_muted(strings.alsoSee)
		for _, suggestion in ipairs(result.suggestions) do
			self:_muted("•  " .. suggestion.title)
		end
	end
end

----------------------------------------------------------------------
-- progress
----------------------------------------------------------------------

function App:_renderProgress()
	local strings = self.strings

	self:_title(strings.progressTitle)

	local percent = self.progress:overallPercent()
	Components.progressBar({
		parent = self.content,
		fraction = percent / 100,
		trackColor = self.palette.panelAlt,
		fillColor = self.palette.accent,
		order = self:_nextOrder(),
	})
	self:_body(string.format(
		"%s: %d / %d  (%d%%)",
		strings.progressLessons, self.progress:completedCount(), Lessons.count(), percent
	))
	self:_body(string.format("%s: %d", strings.progressQuiz, self.progress:correctQuizCount()))

	Components.divider(self.content, self.palette.border, self:_nextOrder())

	for _, moduleInfo in ipairs(Lessons.modules) do
		local status = self.progress:moduleStatus(moduleInfo.id)
		self:_body(string.format(
			"%s  —  %d / %d  ·  %s",
			moduleInfo.title[self.language] or moduleInfo.title.en,
			status.done, status.total, strings[status.state]
		))
	end

	Components.divider(self.content, self.palette.border, self:_nextOrder())

	self:_secondaryButton(
		self._resetArmed and strings.resetConfirm or strings.resetProgress,
		function()
			if self._resetArmed then
				self.progress:reset()
				self._resetArmed = false
			else
				self._resetArmed = true
			end
			self:render()
		end
	)
end

----------------------------------------------------------------------
-- actions that touch the place
----------------------------------------------------------------------

--[[ Picks a sensible parent for an inserted sample. ]]
function App:_parentForSnippet(snippet)
	local services = self.services
	local map = {
		StarterPlayerScripts = services.starterPlayerScripts,
		StarterCharacterScripts = services.starterCharacterScripts,
		ServerScriptService = services.serverScriptService,
		Workspace = services.workspace,
		Tool = services.workspace,
	}
	return map[snippet.parent] or services.serverScriptService or services.workspace
end

function App:insertSnippet(snippet)
	local parent = self:_parentForSnippet(snippet)
	if not parent then
		return
	end

	local recording
	local changeHistory = self.services.changeHistory
	if changeHistory then
		-- Wrap in a waypoint so Ctrl+Z undoes the insertion cleanly.
		local ok, id = pcall(function()
			return changeHistory:TryBeginRecording("AnimTeacherInsert", "Insert animation sample")
		end)
		recording = ok and id or nil
	end

	local created = Instance.new(snippet.className)
	created.Name = "AnimTeacher_" .. snippet.id:gsub("-", "_")
	created.Source = snippet.code
	created.Parent = parent

	if self.services.selection then
		pcall(function()
			self.services.selection:Set({ created })
		end)
	end

	if changeHistory and recording then
		pcall(function()
			changeHistory:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end)
	end

	self.view.checkMessage = self.strings.copyHint .. created.Name .. " → " .. tostring(parent)
	self.view.checkPassed = true
	self:render()
end

function App:runCheck(checkId)
	local result = Checks.run(checkId, {
		workspace = self.services.workspace,
		starterPlayerScripts = self.services.starterPlayerScripts,
		starterCharacterScripts = self.services.starterCharacterScripts,
		serverScriptService = self.services.serverScriptService,
		replicatedStorage = self.services.replicatedStorage,
		starterPack = self.services.starterPack,
	})

	if not result then
		return
	end

	local strings = self.strings
	local message = (result.passed and strings.checkPass or strings.checkFail)
		.. (strings[result.messageKey] or "")
	if result.extraKey and strings[result.extraKey] then
		message = message .. "  " .. strings[result.extraKey]
	end

	self.view.checkMessage = message
	self.view.checkPassed = result.passed
	self:render()
end

return App
