--[[
	AnimTeacher — AI Animation Teacher for Roblox Studio
	Учитель анимации для Roblox Studio

	GENERATED FILE — do not edit by hand.
	Source lives in src/; rebuild with:  python3 tools/build.py

	Install:
	  1. In Studio, insert a Script into ServerStorage.
	  2. Paste this entire file into it.
	  3. Right-click the script -> "Save as Local Plugin".
	  4. Delete the original script from ServerStorage.
	  5. The plugin appears on the Plugins tab as "Animation Teacher".

	Built: 2026-07-28 10:12 UTC
	Modules: 12
]]

local __modules = {}
local __cache = {}

local function __require(name)
	local cached = __cache[name]
	if cached ~= nil then
		return cached
	end
	local factory = __modules[name]
	if factory == nil then
		error("AnimTeacher: module not found: " .. tostring(name), 2)
	end
	-- Mark before running so a cyclic require fails loudly instead of hanging.
	__cache[name] = false
	local result = factory()
	if result == nil then
		result = true
	end
	__cache[name] = result
	return result
end

__modules["Main"] = function()
	--[[
		AnimTeacher — AI Animation Teacher for Roblox Studio
		Entry point: creates the toolbar button and the dock widget, wires Studio
		services into the app, and persists progress through plugin settings.

		This is the only file that talks to the Plugin object.
	]]

	local Progress = __require("Core.Progress")
	local Strings = __require("Data.Strings")
	local App = __require("UI.App")

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
end

__modules["Brain.Answer"] = function()
	--[[
		Brain/Answer
		The offline "reasoning" layer.

		Scoring pipeline for a learner question:
		  1. Analyse the text once (Brain/Text) -> tokens, stems, concepts.
		  2. Score every Knowledge entry:
		       + concept overlap (the strongest signal, works across languages)
		       + literal pattern hits (phrases like "не работает")
		       + keyword stem overlap
		       - reject the entry if it declares `must` concepts and none are present
		  3. Score lessons too, so a question can be answered with "study this".
		  4. Pick a winner if it clears the confidence floor, otherwise return a
		     graceful fallback with suggestions instead of a wrong answer.

		Pure Lua, no Roblox API: unit tested in tests/.
	]]

	local Text = __require("Brain.Text")
	local Knowledge = __require("Data.Knowledge")
	local Lessons = __require("Data.Lessons")

	local Answer = {}

	-- Tuned against tests/test_answer.lua.
	local WEIGHT_CONCEPT = 10
	local WEIGHT_MUST_CONCEPT = 6
	local WEIGHT_PATTERN = 14
	local WEIGHT_KEYWORD = 4
	local WEIGHT_TITLE = 3
	local MIN_CONFIDENT_SCORE = 12

	local function toSet(list)
		local set = {}
		for _, value in ipairs(list or {}) do
			set[value] = true
		end
		return set
	end

	--[[ Scores one knowledge entry against the analysed question. ]]
	local function scoreEntry(entry, analysis, conceptSet, stemSet)
		-- Hard gate: entries can demand a concept before they are eligible.
		if entry.must then
			local satisfied = false
			for _, concept in ipairs(entry.must) do
				if conceptSet[concept] then
					satisfied = true
					break
				end
			end
			if not satisfied then
				return 0
			end
		end

		local score = 0

		for _, concept in ipairs(entry.concepts or {}) do
			if conceptSet[concept] then
				score = score + WEIGHT_CONCEPT
			end
		end

		-- A `must` concept that is present is extra evidence.
		for _, concept in ipairs(entry.must or {}) do
			if conceptSet[concept] then
				score = score + WEIGHT_MUST_CONCEPT
			end
		end

		-- Literal phrases are a very strong signal of intent.
		for _, pattern in ipairs(entry.patterns or {}) do
			if string.find(analysis.raw, pattern, 1, true) then
				score = score + WEIGHT_PATTERN
			end
		end

		for _, keyword in ipairs(entry.keywords or {}) do
			if stemSet[Text.stem(Text.lower(keyword))] then
				score = score + WEIGHT_KEYWORD
			end
		end

		return score
	end

	local function scoreLesson(lesson, analysis, conceptSet, stemSet, language)
		local score = 0

		for _, keyword in ipairs(lesson.keywords or {}) do
			local keyStems = Text.analyze(keyword).stems
			for _, stem in ipairs(keyStems) do
				if stemSet[stem] then
					score = score + WEIGHT_KEYWORD
				end
			end
			for _, concept in ipairs(Text.concepts(Text.tokenize(keyword))) do
				if conceptSet[concept] then
					score = score + WEIGHT_KEYWORD
				end
			end
		end

		-- Title overlap is a weak but useful hint.
		local title = lesson.title[language] or lesson.title.en
		for _, stem in ipairs(Text.analyze(title).stems) do
			if stemSet[stem] then
				score = score + WEIGHT_TITLE
			end
		end

		return score
	end

	--[[
		Answers a free-form question.

		Returns a table:
		  kind        "knowledge" | "lesson" | "fallback"
		  entry       the matched knowledge entry (kind == "knowledge")
		  lesson      a related/suggested lesson (may be nil)
		  suggestions array of { id, title } for the fallback / further reading
		  score       the winning score (useful for tests and debugging)
		  language    the language the answer should be rendered in
	]]
	function Answer.ask(question, language)
		language = language or Text.detectLanguage(question) or "en"

		local analysis = Text.analyze(question)
		local conceptSet = toSet(analysis.concepts)
		local stemSet = toSet(analysis.stems)

		-- ---- knowledge entries ----
		local ranked = {}
		for _, entry in ipairs(Knowledge.entries) do
			local score = scoreEntry(entry, analysis, conceptSet, stemSet)
			if score > 0 then
				ranked[#ranked + 1] = { id = entry.id, entry = entry, score = score }
			end
		end
		table.sort(ranked, function(a, b)
			if a.score == b.score then
				return a.id < b.id
			end
			return a.score > b.score
		end)

		-- ---- lessons ----
		local rankedLessons = {}
		for _, lesson in ipairs(Lessons.list) do
			local score = scoreLesson(lesson, analysis, conceptSet, stemSet, language)
			if score > 0 then
				rankedLessons[#rankedLessons + 1] = { id = lesson.id, lesson = lesson, score = score }
			end
		end
		table.sort(rankedLessons, function(a, b)
			if a.score == b.score then
				return a.id < b.id
			end
			return a.score > b.score
		end)

		local best = ranked[1]

		if best and best.score >= MIN_CONFIDENT_SCORE then
			local relatedLesson = nil
			if best.entry.lesson then
				relatedLesson = Lessons.get(best.entry.lesson)
			elseif rankedLessons[1] then
				relatedLesson = rankedLessons[1].lesson
			end

			local suggestions = {}
			for i = 2, math.min(3, #ranked) do
				suggestions[#suggestions + 1] = {
					id = ranked[i].entry.id,
					title = ranked[i].entry.title[language] or ranked[i].entry.title.en,
				}
			end

			return {
				kind = "knowledge",
				entry = best.entry,
				lesson = relatedLesson,
				snippet = best.entry.snippet,
				suggestions = suggestions,
				score = best.score,
				language = language,
			}
		end

		-- A lesson can still be a good answer even when no KB entry matched well.
		if rankedLessons[1] and rankedLessons[1].score >= MIN_CONFIDENT_SCORE then
			local suggestions = {}
			for i = 2, math.min(3, #rankedLessons) do
				suggestions[#suggestions + 1] = {
					id = rankedLessons[i].lesson.id,
					title = rankedLessons[i].lesson.title[language] or rankedLessons[i].lesson.title.en,
				}
			end
			return {
				kind = "lesson",
				lesson = rankedLessons[1].lesson,
				snippet = rankedLessons[1].lesson.snippet,
				suggestions = suggestions,
				score = rankedLessons[1].score,
				language = language,
			}
		end

		-- ---- fallback ----
		local suggestions = {}
		for i = 1, math.min(3, #ranked) do
			suggestions[#suggestions + 1] = {
				id = ranked[i].entry.id,
				title = ranked[i].entry.title[language] or ranked[i].entry.title.en,
			}
		end
		if #suggestions == 0 then
			for i = 1, math.min(3, #rankedLessons) do
				suggestions[#suggestions + 1] = {
					id = rankedLessons[i].lesson.id,
					title = rankedLessons[i].lesson.title[language] or rankedLessons[i].lesson.title.en,
				}
			end
		end

		return {
			kind = "fallback",
			suggestions = suggestions,
			score = best and best.score or 0,
			language = language,
		}
	end

	--[[ Renders an answer result into plain paragraphs for the chat view. ]]
	function Answer.render(result, strings)
		local language = result.language
		local lines = {}

		if result.kind == "knowledge" then
			lines[#lines + 1] = { kind = "title", text = result.entry.title[language] or result.entry.title.en }
			local body = result.entry.answer[language] or result.entry.answer.en
			for _, paragraph in ipairs(body) do
				lines[#lines + 1] = { kind = "text", text = paragraph }
			end
		elseif result.kind == "lesson" then
			lines[#lines + 1] = { kind = "title", text = result.lesson.title[language] or result.lesson.title.en }
			lines[#lines + 1] = { kind = "text", text = result.lesson.goal[language] or result.lesson.goal.en }
			local theory = result.lesson.theory[language] or result.lesson.theory.en
			for i = 1, math.min(3, #theory) do
				lines[#lines + 1] = { kind = "text", text = theory[i] }
			end
		else
			lines[#lines + 1] = { kind = "title", text = strings.fallbackTitle }
			lines[#lines + 1] = { kind = "text", text = strings.fallbackBody }
		end

		return lines
	end

	Answer.MIN_CONFIDENT_SCORE = MIN_CONFIDENT_SCORE

	return Answer
end

__modules["Brain.Checks"] = function()
	--[[
		Brain/Checks
		"Check my work": inspects the learner's actual place and gives feedback.

		This is what makes the tutor a teacher rather than a text viewer — it
		looks at the real Workspace and scripts and tells you what is missing.

		The Roblox services are injected (`env`) so the rules can be unit tested
		against a fake game tree. In Studio, Plugin/Main passes the real services.

		env = {
			workspace   = <Instance-like>,
			starterPlayerScripts = <Instance-like> or nil,
			serverScriptService  = <Instance-like> or nil,
			starterCharacterScripts = <Instance-like> or nil,
		}

		Every Instance-like object needs: ClassName, Name, GetDescendants(),
		IsA(className), and for scripts a readable Source.
	]]

	local Checks = {}

	----------------------------------------------------------------------
	-- helpers
	----------------------------------------------------------------------

	local function descendantsOf(container)
		if not container then
			return {}
		end
		local ok, result = pcall(function()
			return container:GetDescendants()
		end)
		if ok and type(result) == "table" then
			return result
		end
		return {}
	end

	local function isA(instance, className)
		local ok, result = pcall(function()
			return instance:IsA(className)
		end)
		return ok and result == true
	end

	--[[ Reads .Source defensively: it is unreadable for some script types. ]]
	local function sourceOf(instance)
		local ok, source = pcall(function()
			return instance.Source
		end)
		if ok and type(source) == "string" then
			return source
		end
		return nil
	end

	local function collectScriptSources(env)
		local sources = {}
		local containers = {
			env.starterPlayerScripts,
			env.starterCharacterScripts,
			env.serverScriptService,
			env.workspace,
			env.replicatedStorage,
			env.starterPack,
		}
		for _, container in ipairs(containers) do
			for _, descendant in ipairs(descendantsOf(container)) do
				if isA(descendant, "LuaSourceContainer") then
					local source = sourceOf(descendant)
					if source then
						sources[#sources + 1] = { name = descendant.Name, source = source }
					end
				end
			end
		end
		return sources
	end

	----------------------------------------------------------------------
	-- individual checks
	----------------------------------------------------------------------

	--[[
		Each check returns:
		  { passed = boolean, messageKey = string, extraKey = string? }
		The caller turns the keys into localized text via Data/Strings.
	]]

	local function checkRigInWorkspace(env)
		local motorCount = 0
		local rigNames = {}
		for _, descendant in ipairs(descendantsOf(env.workspace)) do
			if isA(descendant, "Motor6D") then
				motorCount = motorCount + 1
				local ok, parentName = pcall(function()
					return descendant.Parent and descendant.Parent.Parent and descendant.Parent.Parent.Name
				end)
				if ok and parentName and not rigNames[parentName] then
					rigNames[parentName] = true
				end
			end
		end

		if motorCount > 0 then
			return { passed = true, messageKey = "checkRigFound", count = motorCount }
		end
		return { passed = false, messageKey = "checkRigMissing" }
	end

	local function checkLocalScriptWithAnimator(env)
		local found = false
		local deprecated = false

		for _, entry in ipairs(collectScriptSources(env)) do
			local source = entry.source
			if string.find(source, "LoadAnimation", 1, true) then
				-- Animator:LoadAnimation is the modern form.
				if string.find(source, "animator:LoadAnimation", 1, true)
					or string.find(source, "Animator:LoadAnimation", 1, true)
				then
					found = true
				end
				-- Humanoid:LoadAnimation is deprecated; flag it even if the
				-- modern call is present elsewhere in the place.
				if string.find(source, "humanoid:LoadAnimation", 1, true)
					or string.find(source, "Humanoid:LoadAnimation", 1, true)
				then
					deprecated = true
				end
			end
		end

		if found then
			return {
				passed = true,
				messageKey = "checkScriptFound",
				extraKey = deprecated and "checkDeprecated" or nil,
			}
		end
		return {
			passed = false,
			messageKey = "checkScriptMissing",
			extraKey = deprecated and "checkDeprecated" or nil,
		}
	end

	----------------------------------------------------------------------
	-- registry
	----------------------------------------------------------------------

	Checks.registry = {
		["rig-in-workspace"] = checkRigInWorkspace,
		["localscript-with-animator"] = checkLocalScriptWithAnimator,
	}

	--[[ Runs a named check. Unknown ids return nil so the UI can hide the button. ]]
	function Checks.run(checkId, env)
		local fn = Checks.registry[checkId]
		if not fn then
			return nil
		end
		local ok, result = pcall(fn, env)
		if not ok then
			return { passed = false, messageKey = "checkFail", error = tostring(result) }
		end
		return result
	end

	function Checks.exists(checkId)
		return Checks.registry[checkId] ~= nil
	end

	return Checks
end

__modules["Brain.Text"] = function()
	--[[
		Brain/Text
		Bilingual (Russian + English) text processing for the offline tutor.

		Roblox's `string.lower` is byte based and does not touch Cyrillic, and there
		is no stemmer available in Luau, so everything here is implemented from
		scratch on top of raw UTF-8 bytes:

		  * `lower`     - ASCII + Cyrillic (including Ё) case folding
		  * `tokenize`  - UTF-8 aware word splitting
		  * `stem`      - light suffix stripping for RU and EN
		  * `concepts`  - maps surface forms in either language onto shared
		                  "concept" ids, so a Russian question can match an English
		                  knowledge entry and vice versa.

		Pure Lua, no Roblox API: unit tested in tests/.
	]]

	local Text = {}

	----------------------------------------------------------------------
	-- Case folding
	----------------------------------------------------------------------

	--[[
		Cyrillic in UTF-8:
		  А..П = D0 90 .. D0 9F      -> а..п = D0 B0 .. D0 BF   (+0x20)
		  Р..Я = D0 A0 .. D0 AF      -> р..я = D1 80 .. D1 8F   (lead byte changes)
		  Ё    = D0 81               -> ё    = D1 91
	]]
	function Text.lower(s)
		local out = {}
		local i = 1
		local n = #s
		while i <= n do
			local b = string.byte(s, i)
			if b == 0xD0 and i < n then
				local b2 = string.byte(s, i + 1)
				if b2 >= 0x90 and b2 <= 0x9F then
					out[#out + 1] = string.char(0xD0, b2 + 0x20)
				elseif b2 >= 0xA0 and b2 <= 0xAF then
					out[#out + 1] = string.char(0xD1, b2 - 0x20)
				elseif b2 == 0x81 then -- Ё
					out[#out + 1] = string.char(0xD1, 0x91)
				else
					out[#out + 1] = string.char(b, b2)
				end
				i = i + 2
			elseif b >= 0xC0 then
				-- Any other multi-byte sequence: copy verbatim.
				local len = 2
				if b >= 0xF0 then
					len = 4
				elseif b >= 0xE0 then
					len = 3
				end
				out[#out + 1] = string.sub(s, i, i + len - 1)
				i = i + len
			else
				if b >= 65 and b <= 90 then
					out[#out + 1] = string.char(b + 32)
				else
					out[#out + 1] = string.char(b)
				end
				i = i + 1
			end
		end
		return table.concat(out)
	end

	----------------------------------------------------------------------
	-- Tokenizer
	----------------------------------------------------------------------

	--[[
		Splits text into lowercase word tokens. ASCII letters/digits and any
		multi-byte (Cyrillic) sequence count as word characters; everything else is
		a separator. Underscore and `:` are separators so `Animator:LoadAnimation`
		becomes two useful tokens.
	]]
	function Text.tokenize(s)
		if type(s) ~= "string" then
			return {}
		end
		local lowered = Text.lower(s)
		local tokens = {}
		local buffer = {}

		local function flush()
			if #buffer > 0 then
				tokens[#tokens + 1] = table.concat(buffer)
				buffer = {}
			end
		end

		local i = 1
		local n = #lowered
		while i <= n do
			local b = string.byte(lowered, i)
			if b >= 0x80 then
				local len = 2
				if b >= 0xF0 then
					len = 4
				elseif b >= 0xE0 then
					len = 3
				end
				buffer[#buffer + 1] = string.sub(lowered, i, i + len - 1)
				i = i + len
			elseif (b >= 97 and b <= 122) or (b >= 48 and b <= 57) then
				buffer[#buffer + 1] = string.char(b)
				i = i + 1
			else
				flush()
				i = i + 1
			end
		end
		flush()
		return tokens
	end

	----------------------------------------------------------------------
	-- Stemming
	----------------------------------------------------------------------

	-- Longest-first so that "ациями" is stripped before "ми".
	local RU_SUFFIXES = {
		"иваниями", "ованиями", "ированием",
		"ированию", "ированный", "ирование", "ированы",
		"ациями", "ациям", "ациях", "ации", "ацию", "ация",
		"ениями", "ениям", "ениях", "ения", "ением", "ению", "ение",
		"остями", "остям", "остях", "ости", "остью", "ость",
		"ыми", "ими", "ого", "его", "ому", "ему", "ых", "их",
		"ами", "ями", "ов", "ев", "ей", "ий", "ая", "яя", "ое", "ее",
		"ые", "ие", "ой", "ей", "ым", "им", "ом", "ем", "ах", "ях",
		"ешь", "ете", "ели", "ила", "ило", "или", "ать", "ять", "ить",
		"ся", "сь", "ла", "ло", "ли", "ет", "ут", "ют", "ит", "ат", "ят",
		"у", "ю", "а", "я", "ы", "и", "е", "о", "ь", "й",
	}

	local EN_SUFFIXES = {
		"izations", "ization", "ational", "iveness", "fulness",
		"ations", "ation", "ings", "ing", "ers", "er",
		"ed", "ly", "s",
	}

	local function utf8Length(s)
		local n = 0
		for i = 1, #s do
			local b = string.byte(s, i)
			if b < 0x80 or b >= 0xC0 then
				n = n + 1
			end
		end
		return n
	end

	Text.utf8Length = utf8Length

	local function isCyrillic(token)
		local b = string.byte(token, 1)
		return b ~= nil and b >= 0x80
	end

	--[[
		Light stemmer. The goal is recall (matching "анимации" with "анимация"),
		not linguistic correctness, so it deliberately keeps stems >= 3 characters.
	]]
	function Text.stem(token)
		if #token == 0 then
			return token
		end
		local suffixes = isCyrillic(token) and RU_SUFFIXES or EN_SUFFIXES
		local minLength = isCyrillic(token) and 4 or 3

		-- English "-ies" -> "-y" so that "properties" and "property" converge.
		if not isCyrillic(token) and #token > 4 and string.sub(token, -3) == "ies" then
			return string.sub(token, 1, #token - 3) .. "y"
		end

		for _, suffix in ipairs(suffixes) do
			local sLen = #suffix
			if #token > sLen and string.sub(token, -sLen) == suffix then
				local candidate = string.sub(token, 1, #token - sLen)
				if utf8Length(candidate) >= minLength then
					return candidate
				end
			end
		end
		return token
	end

	----------------------------------------------------------------------
	-- Stop words
	----------------------------------------------------------------------

	local STOP_WORDS = {}
	for _, w in ipairs({
		-- Russian
		"и", "в", "во", "не", "что", "он", "на", "я", "с", "со", "как", "а", "то",
		"все", "она", "так", "его", "но", "да", "ты", "к", "у", "же", "вы", "за",
		"бы", "по", "ее", "мне", "было", "вот", "от", "меня", "еще", "нет",
		"о", "из", "ему", "теперь", "когда", "даже", "ну", "вдруг", "ли", "если",
		"уже", "или", "быть", "был", "него", "до", "вас", "нибудь", "опять", "уж",
		"вам", "ведь", "там", "потом", "себя", "ничего", "ей", "может", "они",
		"тут", "где", "есть", "надо", "ней", "для", "мы", "тебя", "их", "чем",
		"была", "сам", "чтоб", "без", "будто", "чего", "раз", "тоже", "себе",
		"под", "будет", "ж", "тогда", "кто", "этот", "того", "потому", "этого",
		"какой", "совсем", "ним", "здесь", "этом", "один", "почти", "мой", "тем",
		"чтобы", "нее", "были", "куда", "зачем", "всех", "никогда", "можно",
		"при", "наконец", "два", "об", "другой", "хоть", "после", "над", "больше",
		"тот", "через", "эти", "нас", "про", "всего", "них", "какая", "много",
		"разве", "три", "эту", "моя", "впрочем", "хорошо", "свою", "этой", "перед",
		"иногда", "лучше", "чуть", "том", "нельзя", "такой", "им", "более",
		"всегда", "конечно", "всю", "между", "пожалуйста", "привет", "спасибо",
		-- English
		"the", "a", "an", "and", "or", "but", "if", "then", "than", "so", "of",
		"to", "in", "on", "at", "by", "for", "with", "about", "into", "from",
		"is", "are", "was", "were", "be", "been", "being", "am", "do", "does",
		"did", "doing", "have", "has", "had", "having", "i", "you", "he", "she",
		"it", "we", "they", "me", "him", "her", "us", "them", "my", "your", "his",
		"its", "our", "their", "this", "that", "these", "those", "there", "here",
		"what", "which", "who", "whom", "when", "where", "why", "how", "all",
		"any", "both", "each", "few", "more", "most", "other", "some", "such",
		"no", "nor", "not", "only", "own", "same", "too", "very", "can", "will",
		"just", "should", "now", "please", "hello", "hi", "thanks",
	}) do
		STOP_WORDS[w] = true
	end

	function Text.isStopWord(token)
		return STOP_WORDS[token] == true
	end

	----------------------------------------------------------------------
	-- Concept mapping (cross-language bridge)
	----------------------------------------------------------------------

	--[[
		Each entry is { concept, prefix1, prefix2, ... }.
		A token maps to a concept when it starts with one of the listed prefixes.
		Prefixes are matched against the lowercased *raw* token (before stemming),
		which handles Russian inflection robustly ("анимации", "анимацию", ...).
	]]
	local CONCEPT_RULES = {
		{ "animation", "анимац", "анимир", "анимк", "animat", "anim" },
		{ "rig", "риг", "скелет", "rig", "skeleton", "armature" },
		{ "r6", "r6", "р6" },
		{ "r15", "r15", "р15" },
		{ "keyframe", "ключев", "кадр", "keyfram", "frame", "поза", "поз" },
		{ "editor", "редактор", "editor", "аниматор редактор" },
		{ "curve", "кривая", "кривых", "кривые", "curve", "график", "graph", "easing", "изинг",
		  "плавн", "робот", "robot", "механич", "mechanic", "деревян", "stiff", "естествен",
		  "натурал", "natural", "живо", "смотрится", "выглядит" },
		{ "motor6d", "motor6d", "мотор", "joint", "сустав", "сочленен", "шарнир" },
		{ "animator", "animator", "аниматор" },
		{ "animationcontroller", "animationcontroller", "контроллер", "дверь", "двер", "door",
		  "машин", "ship", "корабл", "платформ", "turret", "турел" },
		{ "track", "animationtrack", "трек", "track", "дорожк" },
		{ "priority", "приоритет", "priorit" },
		{ "weight", "вес", "весов", "weight", "блендинг", "blend", "смеш", "микш" },
		{ "speed", "скорост", "speed", "быстр", "медлен", "темп", "ускор", "замедл", "slow", "fast" },
		{ "looped", "цикл", "loop", "зациклен", "повтор" },
		{ "fade", "fadetime", "фейд", "затухан", "переход", "transition" },
		{ "event", "событ", "event", "маркер", "marker", "getmarkerreachedsignal", "footstep",
		  "шаг", "звук", "sound", "урон", "damage", "момент", "синхрон", "sync", "попадан", "hit" },
		{ "export", "экспорт", "export", "публик", "опубл", "publish", "upload", "загруз",
		  "сохран", "save" },
		{ "assetid", "assetid", "айди", "rbxassetid", "ассет" },
		{ "script", "скрипт", "script", "код", "code", "localscript" },
		-- "=word" means an exact token match, so "players" does not become "play".
		{ "play", "играт", "проигр", "воспроизв", "запуст", "запуск", "старт", "start",
		  "=play", "=plays", "=playing", "=played" },
		{ "stop", "останов", "стоп", "stop", "выключ", "пауз", "pause", "прерв", "cancel", "отмен" },
		-- Only unambiguous failure words here; negated phrases are handled by
		-- PHRASE_RULES below so that "как работает X" is not read as "X is broken".
		{ "notworking", "ошибк", "error", "broken", "fail", "сломал", "глюч",
		  "проблем", "issue", "problem", "баг", "bug", "неправильно", "wrong" },
		{ "replication", "реплик", "replicat", "сервер", "server", "клиент", "client", "видят", "видно",
		  "остальны", "другие игроки", "мультиплеер", "multiplayer" },
		{ "tool", "tool", "инструмент", "оруж", "weapon", "предмет", "меч", "sword", "gun" },
		{ "ik", "ik", "ikcontrol", "инверсн", "кинематик", "inverse" },
		{ "skinning", "скин", "skin", "bone", "кост", "меш", "mesh", "деформац" },
		{ "npc", "npc", "нпс", "моб", "враг", "enemy", "монстр" },
		{ "idle", "idle", "айдл", "стоян", "покой", "дыхан" },
		{ "walk", "ходьб", "walk", "шаг", "походк", "run", "бег" },
		{ "jump", "прыж", "jump", "падени", "fall" },
		{ "attack", "атак", "удар", "attack", "combat", "combo", "комбо", "punch" },
		{ "optimization", "оптимиз", "optimiz", "performance", "производител", "лаг", "lag", "fps",
		  "тормоз", "memory", "памят", "preload", "предзагруз" },
		{ "procedural", "процедурн", "procedural", "runservice", "transform", "динамическ" },
		{ "capture", "capture", "захват", "камер", "webcam", "video", "видео", "mocap", "мокап" },
		{ "default", "стандартн", "дефолт", "default", "встроен", "замен", "replace", "animate" },
		{ "learn", "учит", "учеб", "обуч", "урок", "lesson", "изуч", "начат", "learn", "teach", "start",
		  "курс", "course", "tutorial", "туториал" },
		{ "progress", "прогресс", "progress", "статус", "status", "достижен", "результат" },
		{ "help", "помог", "помощ", "help", "подскаж", "объясн", "explain", "расскаж", "покажи", "show" },
		{ "example", "пример", "example", "sample", "шаблон", "snippet", "сниппет" },
		{ "install", "установ", "install", "плагин", "plugin", "setup", "настро" },
		{ "moonanimator", "moon", "мун" },
		{ "blender", "blender", "блендер", "fbx", "фбх", "import", "импорт" },
		{ "loadanimation", "loadanimation" },
		{ "humanoid", "humanoid", "гуманоид", "персонаж", "character", "чар" },
		{ "layered", "layered", "слой", "слоя", "layer" },
		{ "deprecated", "deprecated", "устарел", "депрекейт" },
	}

	--[[
		Phrase rules run against the whole lowercased string rather than single
		tokens. They exist for negations and multi-word intents, where the meaning
		lives in the combination and not in any one word.
	]]
	local PHRASE_RULES = {
		{ "notworking", "не работает", "не работают", "не заработал", "не пашет",
			"не играет", "не проигрывается", "не воспроизводится", "не запускается",
			"не двигается", "не видно", "не показывает", "ничего не происходит",
			"not working", "doesn't work", "does not work", "not playing",
			"doesn't play", "does not play", "won't play", "will not play",
			"nothing happens", "not animating", "isn't playing", "is not playing",
			"не анимир", "не оживает", "не реагирует", "перестала работать",
			"не могу заставить", "can't get it to", "cannot get it to" },
		{ "replication", "не видят", "не видит", "другие игроки", "остальные игроки",
			"видно только мне", "вижу только я", "только я вижу",
			"other players", "cannot see", "can't see", "only i can see",
			"nobody else", "everyone else" },
		{ "weight", "смешать анимац", "смешивание анимац", "плавный переход",
			"blend animation", "blending animation", "smooth transition" },
	}

	--[[ Returns an array of concept ids triggered by the given raw tokens. ]]
	function Text.concepts(tokens, raw)
		local found = {}
		local order = {}

		local function add(concept)
			if not found[concept] then
				found[concept] = true
				order[#order + 1] = concept
			end
		end

		for _, token in ipairs(tokens) do
			for _, rule in ipairs(CONCEPT_RULES) do
				local concept = rule[1]
				if not found[concept] then
					for i = 2, #rule do
						local pattern = rule[i]
						if string.sub(pattern, 1, 1) == "=" then
							-- Exact token match.
							if token == string.sub(pattern, 2) then
								add(concept)
								break
							end
						elseif #token >= #pattern and string.sub(token, 1, #pattern) == pattern then
							add(concept)
							break
						end
					end
				end
			end
		end

		if raw then
			for _, rule in ipairs(PHRASE_RULES) do
				local concept = rule[1]
				for i = 2, #rule do
					if string.find(raw, rule[i], 1, true) then
						add(concept)
						break
					end
				end
			end
		end

		return order
	end

	----------------------------------------------------------------------
	-- Public analysis entry point
	----------------------------------------------------------------------

	--[[
		Analyses a piece of text once and returns everything downstream code needs.
		  raw      - lowercase original string
		  tokens   - raw word tokens
		  stems    - stemmed, stop-word filtered tokens
		  concepts - cross-language concept ids
	]]
	function Text.analyze(input)
		local raw = Text.lower(input or "")
		local tokens = Text.tokenize(raw)
		local stems = {}
		for _, token in ipairs(tokens) do
			if not Text.isStopWord(token) and utf8Length(token) > 1 then
				stems[#stems + 1] = Text.stem(token)
			end
		end
		return {
			raw = raw,
			tokens = tokens,
			stems = stems,
			concepts = Text.concepts(tokens, raw),
		}
	end

	--[[ Detects the dominant language of a string: "ru" or "en". ]]
	function Text.detectLanguage(input)
		local cyrillic, latin = 0, 0
		local i = 1
		local n = #input
		while i <= n do
			local b = string.byte(input, i)
			if b == 0xD0 or b == 0xD1 then
				cyrillic = cyrillic + 1
				i = i + 2
			elseif (b >= 65 and b <= 90) or (b >= 97 and b <= 122) then
				latin = latin + 1
				i = i + 1
			else
				i = i + 1
			end
		end
		if cyrillic > latin then
			return "ru"
		elseif latin > 0 then
			return "en"
		end
		return nil
	end

	return Text
end

__modules["Core.Progress"] = function()
	--[[
		Core/Progress
		Tracks which lessons are finished and which quizzes were answered.

		Persistence goes through plugin:SetSetting/GetSetting, but the module never
		touches the Plugin object directly: it receives a tiny `store` interface
		({ get = function(key), set = function(key, value) }). That keeps the logic
		unit testable and makes the Studio dependency explicit.
	]]

	local Lessons = __require("Data.Lessons")

	local Progress = {}
	Progress.__index = Progress

	local KEY_COMPLETED = "AnimTeacher_completed"
	local KEY_QUIZ = "AnimTeacher_quiz"
	local KEY_LANGUAGE = "AnimTeacher_language"
	local KEY_CURRENT = "AnimTeacher_current"

	--[[ store: { get(key) -> value, set(key, value) } ]]
	function Progress.new(store)
		local self = setmetatable({}, Progress)
		self._store = store or { get = function() return nil end, set = function() end }

		self._completed = self._store.get(KEY_COMPLETED) or {}
		self._quiz = self._store.get(KEY_QUIZ) or {}
		self._language = self._store.get(KEY_LANGUAGE) or "ru"
		self._current = self._store.get(KEY_CURRENT)

		-- Settings come back as plain tables; make sure they are the right shape.
		if type(self._completed) ~= "table" then
			self._completed = {}
		end
		if type(self._quiz) ~= "table" then
			self._quiz = {}
		end

		return self
	end

	----------------------------------------------------------------------
	-- Lessons
	----------------------------------------------------------------------

	function Progress:isCompleted(lessonId)
		return self._completed[lessonId] == true
	end

	function Progress:setCompleted(lessonId, done)
		if done == false then
			self._completed[lessonId] = nil
		else
			self._completed[lessonId] = true
		end
		self._store.set(KEY_COMPLETED, self._completed)
	end

	function Progress:completedCount()
		local n = 0
		for _, done in pairs(self._completed) do
			if done then
				n = n + 1
			end
		end
		return n
	end

	----------------------------------------------------------------------
	-- Quizzes
	----------------------------------------------------------------------

	function Progress:quizResult(lessonId)
		return self._quiz[lessonId]
	end

	function Progress:setQuizResult(lessonId, correct)
		self._quiz[lessonId] = correct and "correct" or "wrong"
		self._store.set(KEY_QUIZ, self._quiz)
	end

	function Progress:correctQuizCount()
		local n = 0
		for _, value in pairs(self._quiz) do
			if value == "correct" then
				n = n + 1
			end
		end
		return n
	end

	----------------------------------------------------------------------
	-- Navigation state
	----------------------------------------------------------------------

	function Progress:getLanguage()
		return self._language
	end

	function Progress:setLanguage(language)
		self._language = language
		self._store.set(KEY_LANGUAGE, language)
	end

	function Progress:getCurrentLesson()
		return self._current
	end

	function Progress:setCurrentLesson(lessonId)
		self._current = lessonId
		self._store.set(KEY_CURRENT, lessonId)
	end

	--[[
		The lesson the learner should open next:
		the current one if unfinished, otherwise the first incomplete lesson,
		otherwise the very first lesson (course finished -> allow a re-read).
	]]
	function Progress:nextLesson()
		if self._current and not self:isCompleted(self._current) and Lessons.get(self._current) then
			return Lessons.get(self._current)
		end
		for _, lesson in ipairs(Lessons.list) do
			if not self:isCompleted(lesson.id) then
				return lesson
			end
		end
		return Lessons.list[1]
	end

	----------------------------------------------------------------------
	-- Reporting
	----------------------------------------------------------------------

	function Progress:moduleStatus(moduleId)
		local lessons = Lessons.inModule(moduleId)
		local done = 0
		for _, lesson in ipairs(lessons) do
			if self:isCompleted(lesson.id) then
				done = done + 1
			end
		end
		local state = "notStarted"
		if done == #lessons and #lessons > 0 then
			state = "completed"
		elseif done > 0 then
			state = "inProgress"
		end
		return { done = done, total = #lessons, state = state }
	end

	function Progress:overallPercent()
		local total = Lessons.count()
		if total == 0 then
			return 0
		end
		return math.floor((self:completedCount() / total) * 100 + 0.5)
	end

	function Progress:reset()
		self._completed = {}
		self._quiz = {}
		self._current = nil
		self._store.set(KEY_COMPLETED, self._completed)
		self._store.set(KEY_QUIZ, self._quiz)
		self._store.set(KEY_CURRENT, nil)
	end

	return Progress
end

__modules["Data.Knowledge"] = function()
	--[[
		Data/Knowledge
		The offline Q&A base. Each entry answers one real question a learner asks.

		Matching is done by Brain/Answer against:
		  concepts  - concept ids from Brain/Text (cross-language)
		  must      - optional: at least one of these concepts must be present
		  patterns  - literal substrings (either language) worth a strong boost
		  keywords  - extra plain words, stemmed at match time

		`answer` is bilingual and written as plain paragraphs. `snippet` and
		`lesson` let the tutor offer a follow-up action.
	]]

	local Knowledge = {}

	Knowledge.entries = {

		{
			id = "kb-not-playing",
			concepts = { "notworking", "animation", "play" },
			must = { "notworking" },
			patterns = { "не работает", "не играет", "не проигрывается", "ничего не происходит",
				"not working", "not playing", "doesn't play", "does not play", "nothing happens" },
			title = { ru = "Анимация не проигрывается — полная диагностика", en = "Animation does not play — full diagnosis" },
			answer = {
				ru = {
					"Проверяйте по порядку, это закрывает почти все случаи:",
					"1. Выведите print(track.Length) сразу после LoadAnimation. Если 0 — ассет не загрузился. Причина почти всегда одна: анимация опубликована не от того владельца. Если игра принадлежит группе, анимация тоже должна быть опубликована от группы.",
					"2. Проверьте формат ID: должно быть \"rbxassetid://123456\", а не просто число и не ссылка на страницу каталога.",
					"3. Если Length нормальная, а движения нет — дело в приоритете. Поставьте track.Priority = Enum.AnimationPriority.Action: стандартные ходьба и idle работают на Movement/Idle и перекрывают вашу анимацию.",
					"4. Убедитесь, что вы используете animator:LoadAnimation(), а не устаревший humanoid:LoadAnimation().",
					"5. Если анимация замерла на первом кадре — где-то Play() вызывается в цикле и перезапускает трек каждый кадр.",
					"6. Если перестала играть после смерти персонажа — после респавна создаётся новый Animator, трек нужно загрузить заново в CharacterAdded.",
					"7. Совпадает ли тип рига? Анимация для R15 не будет работать на R6.",
				},
				en = {
					"Work through these in order; they cover nearly every case:",
					"1. print(track.Length) right after LoadAnimation. If it is 0 the asset never loaded. The cause is almost always ownership: if the experience belongs to a group, the animation must be published under that group too.",
					"2. Check the ID format: it must be \"rbxassetid://123456\", not a bare number and not a catalog page URL.",
					"3. If Length looks right but nothing moves, it is priority. Set track.Priority = Enum.AnimationPriority.Action — the default walk and idle run at Movement/Idle and override yours.",
					"4. Make sure you call animator:LoadAnimation(), not the deprecated humanoid:LoadAnimation().",
					"5. If it is frozen on the first frame, Play() is being called in a loop and restarting the track every frame.",
					"6. If it stopped after dying, respawning creates a new Animator — reload the track inside CharacterAdded.",
					"7. Do the rig types match? An R15 animation will not run on R6.",
				},
			},
			snippet = "debug-checklist",
			lesson = "4-3-optimization",
		},

		{
			id = "kb-how-to-play",
			concepts = { "animation", "play", "script" },
			must = { "play" },
			patterns = { "как проиграть", "как запустить анимацию", "как воспроизвести", "how to play", "how do i play" },
			title = { ru = "Как проиграть анимацию из скрипта", en = "How to play an animation from a script" },
			answer = {
				ru = {
					"Цепочка всегда одинаковая: Animation → Animator:LoadAnimation() → AnimationTrack → :Play().",
					"Animator лежит внутри Humanoid, поэтому его надо дождаться: local animator = humanoid:WaitForChild(\"Animator\").",
					"Загружайте трек ОДИН раз при инициализации, а не при каждом нажатии — иначе треки накапливаются и игра начинает лагать.",
					"Для действий игрока используйте LocalScript: так отклик мгновенный, и Roblox сам покажет анимацию остальным игрокам.",
					"Не забудьте выставить приоритет: track.Priority = Enum.AnimationPriority.Action.",
				},
				en = {
					"The chain is always the same: Animation → Animator:LoadAnimation() → AnimationTrack → :Play().",
					"The Animator lives inside the Humanoid, so wait for it: local animator = humanoid:WaitForChild(\"Animator\").",
					"Load the track ONCE during initialization, not on every press — otherwise tracks pile up and the game starts to lag.",
					"For player actions use a LocalScript: the response is instant and Roblox replicates it to everyone else for you.",
					"Remember the priority: track.Priority = Enum.AnimationPriority.Action.",
				},
			},
			snippet = "play-basic",
			lesson = "2-1-animator-track",
		},

		{
			id = "kb-priority",
			concepts = { "priority" },
			patterns = { "приоритет", "priority", "перекрывает", "overrides" },
			title = { ru = "Приоритеты анимаций", en = "Animation priorities" },
			answer = {
				ru = {
					"Шкала от низшего к высшему: Core → Idle → Movement → Action → Action2 → Action3 → Action4.",
					"Когда два трека двигают один и тот же сустав, побеждает тот, у кого приоритет выше. Это перекрытие, а не смешивание.",
					"Стандартные ходьба и бег работают на Movement, стандартный idle — на Idle. Поэтому любое ваше действие (удар, эмоция) ставьте минимум на Action, иначе его не будет видно при движении.",
					"Задать можно в редакторе анимаций (сохранится в ассете) или в коде: track.Priority = Enum.AnimationPriority.Action. Код имеет приоритет над настройкой ассета.",
					"Если нужно, чтобы два трека СМЕШИВАЛИСЬ, а не перекрывали друг друга, дайте им одинаковый приоритет и управляйте весами через AdjustWeight.",
				},
				en = {
					"The scale from lowest to highest: Core → Idle → Movement → Action → Action2 → Action3 → Action4.",
					"When two tracks drive the same joint, the higher priority wins. That is overriding, not blending.",
					"The default walk and run sit at Movement and the default idle at Idle. So any action of yours (a hit, an emote) needs at least Action or it will be invisible while moving.",
					"Set it in the Animation Editor (baked into the asset) or in code: track.Priority = Enum.AnimationPriority.Action. Code wins over the asset setting.",
					"If you want two tracks to BLEND instead of override, give them the same priority and drive AdjustWeight.",
				},
			},
			lesson = "2-2-priority-looped",
		},

		{
			id = "kb-replication",
			concepts = { "replication" },
			patterns = { "не видят", "другие игроки", "видно только мне", "other players", "only i can see", "replicate" },
			title = { ru = "Другие игроки не видят анимацию", en = "Other players cannot see the animation" },
			answer = {
				ru = {
					"Главное правило: если клиент проигрывает анимацию через Animator СВОЕГО персонажа, Roblox реплицирует её всем автоматически. Пересылать через RemoteEvent ничего не надо.",
					"Если видно только вам — скорее всего, вы играете анимацию на Animator объекта, который существует только на клиенте, или на чужой модели.",
					"Для NPC всё наоборот: их персонажем владеет сервер, поэтому анимации NPC надо запускать серверным Script, иначе их увидит только один клиент.",
					"Про безопасность: никогда не принимайте AnimationId от клиента через RemoteEvent. Эксплойтер пришлёт что угодно. Сервер должен сам знать список разрешённых анимаций.",
					"Правильная схема боя: клиент играет анимацию локально (мгновенный отклик) и сообщает серверу факт действия; сервер проверяет кулдаун и наносит урон.",
				},
				en = {
					"The core rule: when a client plays an animation through ITS OWN character's Animator, Roblox replicates it to everyone automatically. There is nothing to forward over a RemoteEvent.",
					"If only you can see it, you are probably playing on the Animator of an object that exists only on the client, or on someone else's model.",
					"For NPCs it is reversed: the server owns their characters, so NPC animations must be started from a server Script or only one client will see them.",
					"On security: never accept an AnimationId from the client over a RemoteEvent. An exploiter will send anything. The server must own the list of allowed animations.",
					"The correct combat pattern: the client plays locally (instant feedback) and reports the action; the server validates the cooldown and applies damage.",
				},
			},
			snippet = "replicated-attack",
			lesson = "3-3-replication",
		},

		{
			id = "kb-r6-r15",
			concepts = { "r6", "r15", "rig" },
			patterns = { "r6 или r15", "разница между r6", "r6 vs r15", "какой риг" },
			title = { ru = "R6 или R15: что выбрать", en = "R6 or R15: which to choose" },
			answer = {
				ru = {
					"R6 — 6 частей и 5 суставов (Neck, два Shoulder, два Hip). Простой, стилизованный, дешёвый по производительности, анимировать быстро. Нет локтей и коленей, поэтому движения угловатые.",
					"R15 — 15 частей и 14 суставов: есть локти, колени, кисти, стопы и разделённый торс (UpperTorso / LowerTorso). Движения гораздо естественнее, работает IK, поддерживаются слоистые одежда и аксессуары.",
					"Анимации между ригами НЕ переносятся: имена суставов разные. Определитесь до начала работы.",
					"Тип рига задаётся в настройках игры: Game Settings → Avatar → Avatar Type (R6 / R15 / Player Choice).",
					"Практический совет: для новых проектов берите R15 — это стандарт платформы, под него больше готовых ассетов и он поддерживает современные фичи вроде IKControl и skinned mesh.",
				},
				en = {
					"R6 — 6 parts and 5 joints (Neck, two Shoulders, two Hips). Simple, stylized, cheap to run, fast to animate. No elbows or knees, so motion is blocky.",
					"R15 — 15 parts and 14 joints: elbows, knees, hands, feet and a split torso (UpperTorso / LowerTorso). Motion is far more natural, IK works, and layered clothing and accessories are supported.",
					"Animations do NOT transfer between rigs: the joint names differ. Decide before you start.",
					"The rig type is a place setting: Game Settings → Avatar → Avatar Type (R6 / R15 / Player Choice).",
					"Practical advice: use R15 for new projects — it is the platform standard, has more ready-made assets and supports modern features like IKControl and skinned meshes.",
				},
			},
			lesson = "1-1-what-is-animation",
		},

		{
			id = "kb-export",
			concepts = { "export", "assetid" },
			patterns = { "как экспортировать", "как опубликовать", "получить id", "how to export", "how to publish", "get the id" },
			title = { ru = "Экспорт анимации и получение ID", en = "Exporting an animation and getting its ID" },
			answer = {
				ru = {
					"В редакторе анимаций нажмите меню «...» (три точки) → Publish to Roblox. Укажите имя и описание.",
					"Ключевой момент — поле Creator в диалоге публикации. Владелец анимации должен совпадать с владельцем игры. Игра в группе → публикуйте анимацию от группы.",
					"После публикации ID берётся из того же меню (Copy Asset ID) или в Creator Dashboard → Development Items → Animations.",
					"В коде используйте полный формат: animation.AnimationId = \"rbxassetid://123456789\".",
					"Если вы переделали анимацию — публикуйте её ПОВЕРХ существующего ассета (Overwrite). Тогда ID не изменится и скрипты трогать не придётся.",
				},
				en = {
					"In the Animation Editor open the \"...\" menu → Publish to Roblox. Give it a name and description.",
					"The critical field is Creator in the publish dialog. The animation's owner must match the game's owner. Game in a group → publish the animation under that group.",
					"Afterwards grab the ID from the same menu (Copy Asset ID) or from Creator Dashboard → Development Items → Animations.",
					"In code use the full form: animation.AnimationId = \"rbxassetid://123456789\".",
					"If you rework the animation, publish it OVER the existing asset (Overwrite). The ID stays the same and no script changes are needed.",
				},
			},
			lesson = "1-5-export-publish",
		},

		{
			id = "kb-loop",
			concepts = { "looped" },
			patterns = { "зациклить", "цикл", "дёргается", "рывок при повторе", "loop", "looping", "pops" },
			title = { ru = "Зацикливание и рывок при повторе", en = "Looping and the pop at the wrap" },
			answer = {
				ru = {
					"Включить цикл: track.Looped = true в скрипте, либо галочка Loop в редакторе (сохраняется в ассете).",
					"Если в момент повтора виден рывок — первый и последний кадры не совпадают. Скопируйте первый кадр и вставьте его в самый конец таймлайна.",
					"Второй источник рывка — разное значение easing на стыке. Проверьте, что последний ключ не тормозит движение, если цикл должен быть непрерывным (например, у бега).",
					"Для одноразовых действий Looped обязательно должен быть false, иначе трек никогда не завершится и события Ended / Stopped не сработают.",
					"Чтобы дождаться конца одноразовой анимации: track.Stopped:Wait() или подписка на track.Ended.",
				},
				en = {
					"Enable looping with track.Looped = true in a script, or the Loop checkbox in the editor (stored in the asset).",
					"If you see a pop at the wrap, the first and last frames do not match. Copy the first keyframe and paste it at the very end of the timeline.",
					"The second cause is mismatched easing at the seam. Make sure the last key does not decelerate if the cycle must stay continuous (a run, for example).",
					"For one-shot actions Looped must be false, otherwise the track never finishes and the Ended / Stopped events never fire.",
					"To wait for a one-shot animation: track.Stopped:Wait() or connect to track.Ended.",
				},
			},
			lesson = "2-2-priority-looped",
		},

		{
			id = "kb-blend",
			concepts = { "weight", "animation" },
			patterns = { "смешать", "смешива", "плавный переход", "блендинг",
				"blend animation", "smooth transition", "adjustweight" },
			title = { ru = "Смешивание анимаций (веса)", en = "Blending animations (weights)" },
			answer = {
				ru = {
					"Смешивание работает только между треками с ОДИНАКОВЫМ приоритетом. При разном приоритете старший просто перекрывает младшего.",
					"Итоговая поза — взвешенное среднее всех играющих поз. Вес по умолчанию 1.",
					"AdjustWeight(weight, fadeTime) меняет вес плавно за fadeTime секунд: WeightCurrent едет к WeightTarget. Всегда давайте fadeTime хотя бы 0.1.",
					"Классический приём «ходьба → бег»: оба трека на Movement, оба играют, и вы считаете alpha от скорости персонажа. walk:AdjustWeight(1 - alpha), run:AdjustWeight(alpha).",
					"Чтобы ноги не «скользили», синхронизируйте темп: track:AdjustSpeed(humanoid.WalkSpeed / BASE_SPEED), где BASE_SPEED — скорость, под которую рисовалась анимация.",
				},
				en = {
					"Blending only happens between tracks at the SAME priority. With different priorities the higher one simply overrides.",
					"The result is the weighted average of every playing pose. The default weight is 1.",
					"AdjustWeight(weight, fadeTime) ramps the weight over fadeTime seconds: WeightCurrent glides to WeightTarget. Always pass at least 0.1.",
					"The classic walk → run recipe: both tracks on Movement, both playing, and you compute alpha from the character's speed. walk:AdjustWeight(1 - alpha), run:AdjustWeight(alpha).",
					"To stop foot sliding, sync the tempo: track:AdjustSpeed(humanoid.WalkSpeed / BASE_SPEED), where BASE_SPEED is the speed the animation was authored for.",
				},
			},
			snippet = "blend-weights",
			lesson = "2-4-weight-speed",
		},

		{
			id = "kb-events",
			concepts = { "event" },
			patterns = { "маркер", "событие анимации", "getmarkerreachedsignal", "animation event", "marker" },
			title = { ru = "События и маркеры анимации", en = "Animation events and markers" },
			answer = {
				ru = {
					"Маркеры нужны, чтобы привязать код к конкретному кадру: момент касания при ударе, момент шага, вылет снаряда.",
					"Создание: в редакторе включите Show Animation Events (шестерёнка справа от таймлайна), поставьте скраббер на кадр, Edit Animation Events → + Add Event, введите имя.",
					"В коде: track:GetMarkerReachedSignal(\"HitFrame\"):Connect(function(param) ... end). Имя должно совпадать точно, с учётом регистра.",
					"Поле Parameter передаёт произвольную строку в обработчик — удобно для урона (\"20\") или уточнений (\"left,heavy\").",
					"Почему это лучше task.wait(): маркер живёт внутри анимации. Поменяли тайминг — момент срабатывания сдвинулся вместе с ним, код править не нужно.",
					"После добавления или изменения маркеров анимацию нужно опубликовать заново поверх старого ассета.",
				},
				en = {
					"Markers bind code to a specific frame: the contact moment of a punch, a footstep, a projectile release.",
					"To create: enable Show Animation Events in the editor (the gear right of the timeline), place the scrubber, Edit Animation Events → + Add Event, type a name.",
					"In code: track:GetMarkerReachedSignal(\"HitFrame\"):Connect(function(param) ... end). The name must match exactly, case included.",
					"The Parameter field passes an arbitrary string to the handler — handy for damage (\"20\") or details (\"left,heavy\").",
					"Why this beats task.wait(): the marker lives inside the animation. Change the timing and the trigger moves with it — no code edits.",
					"After adding or editing markers you must republish the animation over the existing asset.",
				},
			},
			snippet = "events-markers",
			lesson = "2-3-events",
		},

		{
			id = "kb-non-humanoid",
			concepts = { "animationcontroller", "animation" },
			patterns = { "без humanoid", "без гуманоида", "дверь", "двери", "non-humanoid",
				"without humanoid", "animate a door", "animate a vehicle", "анимировать дверь",
				"анимация двери", "машину", "корабль" },
			title = { ru = "Анимация модели без Humanoid", en = "Animating a model without a Humanoid" },
			answer = {
				ru = {
					"Animator должен где-то жить. Нет Humanoid — создайте AnimationController и положите Animator внутрь него: Model → AnimationController → Animator.",
					"Дальше всё как обычно: animator:LoadAnimation(animation), track:Play().",
					"Уточнение: сам класс AnimationController не устарел, устарел только его метод LoadAnimation. Контроллер создавайте, а грузите через Animator.",
					"Модель обязана быть ригом: части соединены Motor6D, задан PrimaryPart. Без Motor6D редактор анимаций не покажет дорожек.",
					"Якорить нужно ТОЛЬКО корневую часть. Все остальные — Anchored = false, иначе суставы не смогут их двигать. CanCollide у движущихся частей лучше выключить.",
				},
				en = {
					"The Animator needs a home. No Humanoid — create an AnimationController and put the Animator inside it: Model → AnimationController → Animator.",
					"From there it is business as usual: animator:LoadAnimation(animation), track:Play().",
					"To be precise: the AnimationController class is not deprecated, only its LoadAnimation method is. Create the controller but load through the Animator.",
					"The model must be a rig: parts connected by Motor6D with a PrimaryPart set. Without Motor6D the editor shows no tracks.",
					"Anchor ONLY the root part. Everything else must be Anchored = false or the joints cannot move it. Turn CanCollide off on moving parts.",
				},
			},
			snippet = "non-humanoid",
			lesson = "3-1-non-humanoid",
		},

		{
			id = "kb-tool",
			concepts = { "tool" },
			patterns = { "анимация инструмента", "анимация оружия", "меч", "tool animation", "weapon animation" },
			title = { ru = "Анимация инструмента (Tool)", en = "Animating a Tool" },
			answer = {
				ru = {
					"Анимируется не сам Tool, а ПЕРСОНАЖ, который его держит. Трек грузится на Animator персонажа.",
					"Чтобы оружие двигалось с рукой, Handle должен быть присоединён: обычно через RightGrip, который Roblox создаёт автоматически при Equipped, либо через собственный Motor6D для полного контроля.",
					"Жизненный цикл: Equipped → загрузить и запустить idle-трек; Activated → проиграть удар; Unequipped → ОБЯЗАТЕЛЬНО остановить все треки, иначе поза зависнет.",
					"Приоритеты: idle инструмента — Enum.AnimationPriority.Idle, атака — Action. Тогда атака перекрывает удержание.",
					"Скрипт удобнее делать LocalScript внутри Tool: отклик мгновенный, а репликация произойдёт автоматически.",
				},
				en = {
					"You do not animate the Tool — you animate the CHARACTER holding it. The track loads onto the character's Animator.",
					"For the weapon to follow the hand the Handle must be attached: usually via RightGrip, which Roblox creates automatically on Equipped, or via your own Motor6D for full control.",
					"Lifecycle: Equipped → load and start the idle track; Activated → play the swing; Unequipped → you MUST stop every track or the pose sticks.",
					"Priorities: the tool idle on Enum.AnimationPriority.Idle, the attack on Action. The attack then overrides the hold.",
					"A LocalScript inside the Tool is the convenient choice: instant response and automatic replication.",
				},
			},
			snippet = "tool-animation",
			lesson = "3-2-tools-npc",
		},

		{
			id = "kb-ik",
			concepts = { "ik" },
			patterns = { "ikcontrol", "инверсная кинематика", "inverse kinematics", "рука тянется", "reach for" },
			title = { ru = "IKControl: инверсная кинематика", en = "IKControl: inverse kinematics" },
			answer = {
				ru = {
					"IKControl позволяет задать «где должна быть кисть», а движок сам посчитает углы плеча и локтя. Работает поверх обычной анимации.",
					"Кладётся внутрь Humanoid (или AnimationController). Обязательные свойства: Type (Position или Transform), EndEffector (например LeftHand), Target (объект с позицией, чаще Attachment), ChainRoot (например LeftUpperArm).",
					"ChainRoot определяет длину цепочки: LeftUpperArm — плечо и локоть, LeftLowerArm — только предплечье.",
					"Weight (0..1) нужен для плавного включения. Резкое Weight = 1 выглядит как рывок — нарастите его через TweenService.",
					"Чтобы локоть не выгибался в обратную сторону, добавьте HingeConstraint. Условие: аттачменты констрейнта должны стоять на тех же частях и в тех же относительных позициях, что C0/C1 у Motor6D, а констрейнт — лежать в той же модели.",
				},
				en = {
					"IKControl lets you state 'where the hand must be' and the engine solves the shoulder and elbow angles. It works on top of regular animation.",
					"Parent it to the Humanoid (or AnimationController). Required properties: Type (Position or Transform), EndEffector (e.g. LeftHand), Target (any object with a world position, usually an Attachment) and ChainRoot (e.g. LeftUpperArm).",
					"ChainRoot sets the chain length: LeftUpperArm covers shoulder and elbow, LeftLowerArm only the forearm.",
					"Weight (0..1) exists for fading in. Snapping to 1 looks like a jolt — ramp it with TweenService.",
					"To stop the elbow bending backwards, add a HingeConstraint. Requirement: the constraint's attachments must sit on the same parts and at the same relative positions as the Motor6D C0/C1, and the constraint must share the model.",
				},
			},
			snippet = "ik-control",
			lesson = "4-1-ik",
		},

		{
			id = "kb-procedural",
			concepts = { "procedural" },
			patterns = { "процедурная анимация", "поворот головы", "отдача", "procedural", "head look", "recoil" },
			title = { ru = "Процедурная анимация поверх ключевых кадров", en = "Procedural animation over keyframes" },
			answer = {
				ru = {
					"Механизм один: свойство Transform у Motor6D. Аниматор пишет туда позу каждый кадр, а вы добавляете своё смещение поверх.",
					"Ключевое правило — УМНОЖАЙТЕ, а не присваивайте: neck.Transform = myOffset * neck.Transform. Простое присваивание сотрёт анимацию для этого сустава.",
					"Делать это надо в RunService.RenderStepped (на клиенте) или PreSimulation — то есть после расчёта анимации.",
					"Всегда ограничивайте углы через math.clamp и сглаживайте через Lerp: current = current:Lerp(target, 0.2). Так появляется инерция.",
					"У Animator есть EvaluationThrottled: если движок пропустил расчёт для дальнего персонажа, ваш код будет бороться с устаревшей позой. Проверьте флаг и пропустите кадр.",
					"Считайте процедурную анимацию на клиенте: на сервере для каждого игрока это дорого и почти всегда не нужно.",
				},
				en = {
					"There is one mechanism: the Motor6D Transform property. The animator writes a pose there each frame and you add your offset on top.",
					"The key rule is MULTIPLY, do not assign: neck.Transform = myOffset * neck.Transform. A plain assignment erases the animation for that joint.",
					"Do it inside RunService.RenderStepped (on the client) or PreSimulation — that is, after animation evaluation.",
					"Always clamp with math.clamp and smooth with Lerp: current = current:Lerp(target, 0.2). That is where inertia comes from.",
					"The Animator exposes EvaluationThrottled: if the engine skipped evaluation for a distant character your code fights a stale pose. Check the flag and skip the frame.",
					"Compute procedural animation on the client: doing it server-side per player is expensive and rarely necessary.",
				},
			},
			snippet = "procedural-lookat",
			lesson = "4-2-procedural",
		},

		{
			id = "kb-optimization",
			concepts = { "optimization" },
			patterns = { "лагает", "тормозит", "оптимизировать", "рывок при первом", "lag", "stutter", "optimize" },
			title = { ru = "Оптимизация анимаций", en = "Animation optimization" },
			answer = {
				ru = {
					"Утечка треков — причина №1. Каждый LoadAnimation создаёт новый AnimationTrack. Вызов внутри обработчика клика за минуту накопит сотни треков. Загружайте один раз и кэшируйте в таблице.",
					"Рывок при первом проигрывании — ассет ещё не скачан. Создайте объекты Animation заранее, вызовите LoadAnimation при старте и передайте список в ContentProvider:PreloadAsync().",
					"На толпе NPC движок сам снижает частоту расчёта дальних персонажей. Это Animator.PreferLodEnabled (по умолчанию true) и Workspace.ClientAnimatorThrottlingMode. Отключайте LOD только для важных NPC.",
					"Не держите неиспользуемые треки играющими с нулевым весом — они всё равно вычисляются. Останавливайте их через Stop().",
					"Диагностика: animator:GetPlayingAnimationTracks() покажет всё активное, включая затухающие треки. Microprofiler (F6) покажет реальную стоимость расчёта поз.",
				},
				en = {
					"Track leaks are cause number one. Every LoadAnimation creates a new AnimationTrack. Calling it inside a click handler accumulates hundreds within a minute. Load once and cache in a table.",
					"A hitch on first play means the asset is not downloaded. Create the Animation objects up front, call LoadAnimation at startup and pass the list to ContentProvider:PreloadAsync().",
					"With NPC crowds the engine throttles evaluation for distant characters. That is Animator.PreferLodEnabled (true by default) and Workspace.ClientAnimatorThrottlingMode. Disable LOD only for important NPCs.",
					"Do not leave unused tracks playing at zero weight — they are still evaluated. Stop them.",
					"Diagnostics: animator:GetPlayingAnimationTracks() lists everything active including fading tracks. The Microprofiler (F6) shows the real cost of pose evaluation.",
				},
			},
			snippet = "preload",
			lesson = "4-3-optimization",
		},

		{
			id = "kb-deprecated",
			concepts = { "deprecated", "loadanimation" },
			patterns = { "deprecated", "устарел", "humanoid:loadanimation" },
			title = { ru = "Что устарело в API анимаций", en = "What is deprecated in the animation API" },
			answer = {
				ru = {
					"Humanoid:LoadAnimation() — устарел. Замена: animator:LoadAnimation(), где animator = humanoid:WaitForChild(\"Animator\").",
					"AnimationController:LoadAnimation() — тоже устарел. Сам класс AnimationController использовать МОЖНО и нужно (для моделей без Humanoid), но грузить анимацию надо через дочерний Animator.",
					"Функция wait() и spawn() считаются устаревшими в пользу task.wait() и task.spawn().",
					"KeyframeReached — работает, но для событий предпочтительнее GetMarkerReachedSignal(): он срабатывает только на нужный маркер и не требует фильтрации по имени.",
					"Если вы смотрите туториал старше 2021 года, скорее всего там humanoid:LoadAnimation — это главная причина, почему код из видео не работает.",
				},
				en = {
					"Humanoid:LoadAnimation() is deprecated. Use animator:LoadAnimation(), where animator = humanoid:WaitForChild(\"Animator\").",
					"AnimationController:LoadAnimation() is also deprecated. The AnimationController class itself is fine and necessary (for Humanoid-less models), but load through its child Animator.",
					"wait() and spawn() are discouraged in favour of task.wait() and task.spawn().",
					"KeyframeReached still works, but GetMarkerReachedSignal() is preferred: it fires only for the marker you asked for and needs no name filtering.",
					"If you are following a tutorial older than 2021 it almost certainly uses humanoid:LoadAnimation — that is the main reason the video's code fails.",
				},
			},
			lesson = "2-1-animator-track",
		},

		{
			id = "kb-easing",
			concepts = { "curve" },
			patterns = { "easing", "плавность", "кривые", "curve editor", "интерполяц" },
			title = { ru = "Easing и кривые: как сделать движение живым", en = "Easing and curves: making motion feel alive" },
			answer = {
				ru = {
					"Easing — это свойство КЛЮЧЕВОГО КАДРА, а не всей анимации. Оно задаёт форму перехода к следующему ключу.",
					"Easing Style: Linear (механически), Sine (мягко, хороший выбор по умолчанию), Quad/Cubic (сильнее разгон), Back (перелёт), Elastic (пружина), Bounce (отскок), Constant (мгновенный скачок без интерполяции).",
					"Easing Direction: In (медленно в начале), Out (медленно в конце), InOut (медленно с обеих сторон).",
					"Главный приём живой анимации — slow in / slow out: тела не стартуют и не останавливаются мгновенно. Для большинства человеческих движений Sine + InOut уже даёт отличный результат.",
					"Curve Editor нужен, когда пресетов мало: там видно значения как графики и можно двигать касательные руками. Например, резкий удар с долгим затуханием.",
					"Задать easing: правый клик по ключу на таймлайне → Easing Style / Easing Direction.",
				},
				en = {
					"Easing is a property of the KEYFRAME, not of the whole animation. It defines the shape of the transition to the next key.",
					"Easing Style: Linear (mechanical), Sine (soft, a great default), Quad/Cubic (stronger acceleration), Back (overshoot), Elastic (springy), Bounce, Constant (an instant jump, no interpolation).",
					"Easing Direction: In (slow at the start), Out (slow at the end), InOut (slow at both ends).",
					"The core trick of lifelike animation is slow in / slow out: bodies do not start or stop instantly. Sine + InOut already looks great for most human motion.",
					"Use the Curve Editor when presets are not enough: it shows values as graphs and lets you drag tangents by hand — a sharp hit with a long settle, for example.",
					"To set easing: right click a key on the timeline → Easing Style / Easing Direction.",
				},
			},
			lesson = "1-4-easing-curves",
		},

		{
			id = "kb-default-anim",
			concepts = { "default" },
			patterns = { "заменить стандартную", "своя ходьба", "поменять анимацию бега", "replace default", "custom walk" },
			title = { ru = "Заменить стандартные анимации персонажа", en = "Replace the default character animations" },
			answer = {
				ru = {
					"Внутри персонажа Roblox создаёт LocalScript Animate с вложенными Animation-объектами: run, walk, jump, idle, fall, climb, swim, swimidle.",
					"Чтобы поставить свою анимацию, перезапишите AnimationId у нужного объекта. Сам скрипт Animate переписывать не надо.",
					"Делайте это серверным Script в ServerScriptService и подписывайтесь на player.CharacterAppearanceLoaded — к этому моменту скрипт Animate уже точно на месте.",
					"Перед заменой остановите уже играющие треки: for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0) end.",
					"У idle две вариации (Animation1 и Animation2), выбираются случайно. Частота задаётся дочерним объектом Weight: шанс = вес / сумма весов состояния.",
					"Все заменяющие анимации должны быть того же типа рига, что и игра (обычно R15).",
				},
				en = {
					"Inside the character Roblox creates an Animate LocalScript with nested Animation objects: run, walk, jump, idle, fall, climb, swim, swimidle.",
					"To use your own animation, overwrite the AnimationId on the relevant object. There is no need to rewrite the Animate script.",
					"Do it from a server Script in ServerScriptService, hooked to player.CharacterAppearanceLoaded — by then the Animate script definitely exists.",
					"Stop the already playing tracks first: for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0) end.",
					"Idle has two variations (Animation1 and Animation2) chosen at random. A child Weight object sets the odds: chance = weight / the sum for that state.",
					"Every replacement animation must match the game's rig type (usually R15).",
				},
			},
			snippet = "replace-default",
			lesson = "2-5-default-animations",
		},

		{
			id = "kb-blender",
			concepts = { "blender", "skinning" },
			patterns = { "blender", "fbx", "импорт анимации", "skinned mesh", "moon animator" },
			title = { ru = "Внешние инструменты: Blender, Moon Animator, FBX", en = "External tools: Blender, Moon Animator, FBX" },
			answer = {
				ru = {
					"Встроенный редактор закрывает большинство задач. Начинайте с него.",
					"Moon Animator — сторонний плагин, силён в сценах с несколькими персонажами, работе с камерой и графиками. На выходе — обычный ассет анимации с ID.",
					"Blender нужен для skinned mesh: моделей с костями (Bone) и плавной деформацией вместо жёстких частей. Пайплайн: риг и анимация в Blender → экспорт FBX → Studio, вкладка Avatar → 3D Importer / Import Animation.",
					"При импорте FBX проверяйте имена костей и масштаб — единицы Roblox почти всегда требуют ручной коррекции.",
					"Animation Capture (вкладка Avatar) записывает мимику и движения через веб-камеру прямо в Studio. Хорошо для черновика, но ключи почти всегда нужно чистить руками.",
					"Порядок работы: блокинг (грубые позы, Constant) → тайминг (двигаем ключи) → полировка (easing и детали). Полировать до утверждения тайминга — потеря времени.",
				},
				en = {
					"The built-in editor covers most needs. Start there.",
					"Moon Animator is a third-party plugin, strong at multi-character scenes, camera work and graphs. The output is an ordinary animation asset with an ID.",
					"Blender is for skinned meshes: models with Bones and smooth deformation instead of rigid parts. Pipeline: rig and animate in Blender → export FBX → Studio, Avatar tab → 3D Importer / Import Animation.",
					"When importing FBX, verify bone names and scale — Roblox units almost always need a manual fix.",
					"Animation Capture (Avatar tab) records facial and body motion from a webcam inside Studio. Good for blocking, but the keys almost always need cleanup.",
					"Workflow order: blocking (rough poses, Constant) → timing (slide keys) → polish (easing and detail). Polishing before the timing is locked wastes time.",
				},
			},
			lesson = "4-4-pipeline",
		},

		{
			id = "kb-motor6d",
			concepts = { "motor6d" },
			patterns = { "motor6d", "сустав", "как сделать риг", "build a rig", "joint" },
			title = { ru = "Motor6D и устройство рига", en = "Motor6D and how a rig works" },
			answer = {
				ru = {
					"Motor6D соединяет две части: Part0 (родитель, остаётся на месте) и Part1 (потомок, который двигается). Анимация вращает именно сустав, а не часть.",
					"C0 и C1 — CFrame'ы, задающие положение точки вращения относительно каждой части. Ошибка в них — самая частая причина «сломанного» рига, где конечности смещены.",
					"Свойство Transform — это смещение поверх базовой позы. Именно в него пишет аниматор каждый кадр, и именно через него делают процедурную анимацию.",
					"Риг = набор частей, связанных Motor6D. Без них Animation Editor не покажет ни одной дорожки.",
					"Правило якорения: заякорена должна быть только корневая часть. Остальные — Anchored = false, иначе суставы не смогут их двигать.",
					"Для персонажей риг удобнее всего строить через Avatar → Rig Builder, а не руками.",
				},
				en = {
					"Motor6D connects two parts: Part0 (the parent, stays put) and Part1 (the child, which moves). Animation rotates the joint, not the part.",
					"C0 and C1 are CFrames placing the pivot relative to each part. Getting them wrong is the most common cause of a 'broken' rig with offset limbs.",
					"The Transform property is an offset on top of the base pose. That is what the animator writes each frame and what procedural animation hooks into.",
					"A rig is a set of parts joined by Motor6D. Without them the Animation Editor shows no tracks at all.",
					"Anchoring rule: only the root part should be anchored. The rest must be Anchored = false or the joints cannot move them.",
					"For characters, build rigs with Avatar → Rig Builder rather than by hand.",
				},
			},
			snippet = "build-rig-motor6d",
			lesson = "1-1-what-is-animation",
		},

		{
			id = "kb-npc",
			concepts = { "npc", "animation" },
			patterns = { "анимация нпс", "npc animation", "анимация моба", "enemy animation",
				"нпс ходил", "нпс ходит", "чтобы нпс", "моб ходил", "npc walk", "npc idle",
				"make an npc" },
			title = { ru = "Анимации NPC", en = "NPC animations" },
			answer = {
				ru = {
					"NPC с Humanoid анимируется точно так же, как игрок: humanoid → Animator → LoadAnimation → Play.",
					"Важное отличие: NPC принадлежит серверу, поэтому его анимации надо запускать серверным Script. Если запустить на клиенте, увидит только один игрок.",
					"Стройте машину состояний: одно активное состояние (idle / walk / attack) и переход только при смене. Подписывайтесь на humanoid.Running (даёт скорость) и humanoid.StateChanged.",
					"Главная ошибка — вызывать track:Play() каждый кадр в цикле. Трек перезапускается и анимация выглядит замершей на первом кадре. Всегда проверяйте, играет ли уже нужный трек.",
					"При переключении давайте fadeTime: current:Stop(0.2) и next:Play(0.2) — иначе переход будет рывком.",
					"Если NPC много, не отключайте LOD (Animator.PreferLodEnabled) массово — это ударит по производительности.",
				},
				en = {
					"An NPC with a Humanoid animates exactly like a player: humanoid → Animator → LoadAnimation → Play.",
					"The key difference: the NPC belongs to the server, so start its animations from a server Script. Started on a client, only that one player sees it.",
					"Build a state machine: one active state (idle / walk / attack) with transitions only on change. Hook humanoid.Running (gives speed) and humanoid.StateChanged.",
					"The classic mistake is calling track:Play() every frame in a loop. The track restarts and the animation looks frozen on frame one. Always check whether it is already playing.",
					"Give transitions a fade: current:Stop(0.2) and next:Play(0.2), otherwise the switch pops.",
					"With many NPCs, do not disable LOD (Animator.PreferLodEnabled) across the board — it will hurt performance.",
				},
			},
			snippet = "npc-state",
			lesson = "3-2-tools-npc",
		},

		{
			id = "kb-speed",
			concepts = { "speed" },
			patterns = { "скорость анимации", "быстрее", "медленнее", "animation speed", "adjustspeed", "скольз" },
			title = { ru = "Скорость воспроизведения и скольжение ног", en = "Playback speed and foot sliding" },
			answer = {
				ru = {
					"track:AdjustSpeed(speed): 1 — нормально, 2 — вдвое быстрее, 0.5 — вдвое медленнее, 0 — пауза, отрицательное значение — воспроизведение задом наперёд.",
					"Начальную скорость можно задать сразу: track:Play(fadeTime, weight, speed).",
					"track.Length — это длина при скорости 1. Реальная длительность = Length / Speed.",
					"«Скольжение ног» возникает, когда персонаж двигается быстрее или медленнее, чем предполагает анимация. Лечится синхронизацией: track:AdjustSpeed(humanoid.WalkSpeed / BASE_SPEED), где BASE_SPEED — скорость, под которую анимация рисовалась (обычно 16).",
					"Не меняйте скорость слишком резко — это заметно. Если нужен плавный разгон, интерполируйте значение сами.",
				},
				en = {
					"track:AdjustSpeed(speed): 1 is normal, 2 is twice as fast, 0.5 half speed, 0 pauses and a negative value plays backwards.",
					"You can set the initial speed directly: track:Play(fadeTime, weight, speed).",
					"track.Length is the length at speed 1. The real duration is Length / Speed.",
					"Foot sliding happens when the character moves faster or slower than the animation assumes. Fix it by syncing: track:AdjustSpeed(humanoid.WalkSpeed / BASE_SPEED), where BASE_SPEED is the speed the animation was authored for (usually 16).",
					"Do not snap the speed around — it reads badly. Interpolate the value yourself if you need a smooth ramp.",
				},
			},
			lesson = "2-4-weight-speed",
		},

		{
			id = "kb-stop",
			concepts = { "stop", "animation" },
			must = { "stop" },
			patterns = { "остановить анимац", "как остановить", "выключить анимац",
				"stop an animation", "stop the animation", "how to stop", "pause an animation" },
			title = { ru = "Как остановить или поставить анимацию на паузу", en = "Stopping or pausing an animation" },
			answer = {
				ru = {
					"track:Stop(fadeTime) — остановка с плавным затуханием. По умолчанию fadeTime = 0.1 с. Stop(0) обрезает движение мгновенно, это заметно рывком — используйте только когда нужен жёсткий срез.",
					"Пауза — это не Stop. Чтобы заморозить кадр, поставьте скорость в ноль: track:AdjustSpeed(0). Продолжить — track:AdjustSpeed(1).",
					"Остановить всё сразу: for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0.1) end. Это же нужно делать при Unequipped у Tool, иначе поза зависнет.",
					"Проверить состояние можно через track.IsPlaying. Учтите: GetPlayingAnimationTracks возвращает и те треки, которые сейчас затухают.",
					"После Stop трек не уничтожается — его можно проигрывать снова. Заново вызывать LoadAnimation не нужно.",
				},
				en = {
					"track:Stop(fadeTime) stops with a fade out. The default fadeTime is 0.1 s. Stop(0) cuts instantly and reads as a pop — use it only when you want a hard cut.",
					"Pausing is not stopping. To freeze on the current frame set the speed to zero: track:AdjustSpeed(0). Resume with track:AdjustSpeed(1).",
					"To stop everything: for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0.1) end. Do the same in a Tool's Unequipped or the pose sticks.",
					"Check state with track.IsPlaying. Note that GetPlayingAnimationTracks also returns tracks that are currently fading out.",
					"Stopping does not destroy the track — you can play it again. There is no need to call LoadAnimation a second time.",
				},
			},
			snippet = "track-lifecycle",
			lesson = "2-1-animator-track",
		},

		{
			id = "kb-walk-cycle",
			concepts = { "walk", "animation" },
			must = { "walk" },
			patterns = { "анимацию ходьбы", "цикл ходьбы", "анимацию бега", "походк",
				"walk cycle", "run cycle", "walking animation", "running animation" },
			title = { ru = "Как сделать цикл ходьбы или бега", en = "Building a walk or run cycle" },
			answer = {
				ru = {
					"Цикл ходьбы строится на четырёх опорных позах: контакт (нога касается земли), низшая точка, проход (одна нога проходит мимо другой) и высшая точка. Сделайте их первыми, остальное — уточнение.",
					"Обязательное условие цикла: последний кадр должен точно повторять первый, иначе на повторе будет рывок. Скопируйте первый ключ в конец.",
					"Руки двигаются противофазно ногам: левая рука вперёд вместе с правой ногой. Без этого походка выглядит неестественно.",
					"Не забывайте про вертикальное смещение HumanoidRootPart: тело слегка поднимается на проходе и опускается на контакте. Это придаёт вес.",
					"В коде цикл включается через track.Looped = true, а приоритет ставится Enum.AnimationPriority.Movement.",
					"Чтобы ноги не скользили, синхронизируйте темп со скоростью: track:AdjustSpeed(humanoid.WalkSpeed / 16), где 16 — скорость, под которую рисовалась анимация.",
					"Если нужно заменить стандартную ходьбу у всех игроков — это делается через скрипт Animate, см. отдельный вопрос про стандартные анимации.",
				},
				en = {
					"A walk cycle is built from four key poses: contact (foot lands), down, passing (one leg passes the other) and up. Block those first; everything else is refinement.",
					"The loop requirement: the last frame must exactly repeat the first or the wrap will pop. Copy the first key to the end.",
					"Arms swing opposite the legs: left arm forward with the right leg. Without that the walk looks wrong.",
					"Do not forget vertical motion on the HumanoidRootPart: the body rises slightly on the passing pose and drops on contact. That is what gives it weight.",
					"In code, enable the cycle with track.Looped = true and set the priority to Enum.AnimationPriority.Movement.",
					"To stop foot sliding, sync the tempo to the speed: track:AdjustSpeed(humanoid.WalkSpeed / 16), where 16 is the speed the animation was authored for.",
					"If you want to replace the default walk for every player, that goes through the Animate script — see the question about default animations.",
				},
			},
			lesson = "1-3-first-animation",
		},

		{
			id = "kb-speed-change",
			concepts = { "speed", "animation" },
			must = { "speed" },
			patterns = { "ускорить анимац", "замедлить анимац", "скорость анимац",
				"adjustspeed", "animation speed", "speed up the animation", "slow down the animation" },
			title = { ru = "Как изменить скорость анимации", en = "Changing animation speed" },
			answer = {
				ru = {
					"track:AdjustSpeed(speed) меняет темп прямо во время проигрывания: 1 — обычная скорость, 2 — вдвое быстрее, 0.5 — вдвое медленнее, 0 — пауза, отрицательное значение — воспроизведение задом наперёд.",
					"Задать скорость сразу при запуске можно третьим аргументом: track:Play(fadeTime, weight, speed).",
					"track.Length — это длина при скорости 1. Реальная длительность считается как Length / Speed.",
					"Частая задача — убрать «скольжение ног». Синхронизируйте темп с реальной скоростью персонажа: track:AdjustSpeed(humanoid.WalkSpeed / 16), где 16 — скорость, под которую рисовалась анимация.",
					"Резкие скачки скорости заметны. Если нужен плавный разгон, интерполируйте значение сами и вызывайте AdjustSpeed каждый кадр.",
				},
				en = {
					"track:AdjustSpeed(speed) changes the tempo during playback: 1 is normal, 2 twice as fast, 0.5 half speed, 0 pauses and a negative value plays it backwards.",
					"You can also set the speed as the third argument when starting: track:Play(fadeTime, weight, speed).",
					"track.Length is the length at speed 1. The real duration is Length / Speed.",
					"A common need is killing foot sliding. Sync the tempo to the actual character speed: track:AdjustSpeed(humanoid.WalkSpeed / 16), where 16 is the speed the animation was authored for.",
					"Sudden speed jumps are visible. For a smooth ramp, interpolate the value yourself and call AdjustSpeed each frame.",
				},
			},
			lesson = "2-4-weight-speed",
		},

		{
			id = "kb-respawn",
			concepts = { "humanoid", "notworking" },
			patterns = { "после смерти", "после респавна", "after respawn", "after dying", "characteradded" },
			title = { ru = "Анимация пропала после смерти персонажа", en = "The animation is gone after respawn" },
			answer = {
				ru = {
					"При респавне Roblox создаёт НОВУЮ модель персонажа, новый Humanoid и новый Animator. Все треки, загруженные на старый Animator, становятся бесполезными.",
					"Решение — загружать треки в обработчике CharacterAdded, а не один раз при старте скрипта.",
					"Шаблон: функция onCharacterAdded(character) грузит все нужные треки; вызовите её и для уже существующего player.Character, и подпишите на player.CharacterAdded.",
					"Проверьте также StarterPlayerScripts vs StarterCharacterScripts: скрипты из StarterCharacterScripts копируются в каждого нового персонажа заново, из StarterPlayerScripts — запускаются один раз за сессию.",
					"Если у вас таблица треков — не забудьте очищать её при респавне, иначе будете держать ссылки на мёртвые объекты.",
				},
				en = {
					"On respawn Roblox builds a NEW character model, a new Humanoid and a new Animator. Every track loaded on the old Animator is now useless.",
					"The fix is to load tracks inside a CharacterAdded handler rather than once at script start.",
					"Pattern: an onCharacterAdded(character) function that loads every track; call it for the existing player.Character and also connect it to player.CharacterAdded.",
					"Also mind StarterPlayerScripts vs StarterCharacterScripts: scripts in StarterCharacterScripts are copied into every new character, while StarterPlayerScripts runs once per session.",
					"If you keep a table of tracks, clear it on respawn or you will hold references to dead objects.",
				},
			},
			snippet = "reload-on-respawn",
			lesson = "2-1-animator-track",
		},
	}

	Knowledge.byId = {}
	for _, entry in ipairs(Knowledge.entries) do
		Knowledge.byId[entry.id] = entry
	end

	return Knowledge
end

__modules["Data.Lessons"] = function()
	--[[
		Data/Lessons
		The animation curriculum: 4 modules, 14 lessons, zero to advanced.

		Every lesson is bilingual (ru/en) and has the same shape:
		  id        unique string id
		  module    module number (1..4)
		  title     short name
		  goal      one sentence: what the learner can do after this lesson
		  minutes   rough time budget
		  theory    array of paragraphs (the explanation)
		  steps     array of concrete actions to perform in Studio
		  snippet   optional id from Data/Snippets to insert
		  practice  the exercise
		  check     optional id of an automated check (see Brain/Checks)
		  quiz      one multiple-choice question with an explanation
		  keywords  extra search terms for the Q&A engine

		No Roblox API is touched here, so this file is unit tested.
	]]

	local Lessons = {}

	Lessons.modules = {
		{
			id = 1,
			title = { ru = "Модуль 1 · Основы анимации", en = "Module 1 · Animation basics" },
			summary = {
				ru = "Риг, Motor6D, редактор анимаций, ключевые кадры, экспорт.",
				en = "Rigs, Motor6D, the Animation Editor, keyframes, exporting.",
			},
		},
		{
			id = 2,
			title = { ru = "Модуль 2 · Воспроизведение из скриптов", en = "Module 2 · Playback from scripts" },
			summary = {
				ru = "Animator, AnimationTrack, приоритеты, события, веса.",
				en = "Animator, AnimationTrack, priorities, events, weights.",
			},
		},
		{
			id = 3,
			title = { ru = "Модуль 3 · Практика в игре", en = "Module 3 · Real gameplay" },
			summary = {
				ru = "Инструменты, NPC, модели без Humanoid, репликация.",
				en = "Tools, NPCs, non-Humanoid rigs, replication.",
			},
		},
		{
			id = 4,
			title = { ru = "Модуль 4 · Продвинутый уровень", en = "Module 4 · Advanced" },
			summary = {
				ru = "IK, процедурная анимация, оптимизация, отладка.",
				en = "IK, procedural animation, optimization, debugging.",
			},
		},
	}

	Lessons.list = {

		--==================================================================
		-- MODULE 1
		--==================================================================

		{
			id = "1-1-what-is-animation",
			module = 1,
			minutes = 8,
			title = { ru = "Из чего состоит анимация в Roblox", en = "What a Roblox animation is made of" },
			goal = {
				ru = "Понять связку «части → Motor6D → риг → анимация» и разницу R6 / R15.",
				en = "Understand the chain parts → Motor6D → rig → animation, and R6 vs R15.",
			},
			theory = {
				ru = {
					"Анимация в Roblox не двигает части напрямую. Она вращает СУСТАВЫ. Сустав — это объект Motor6D, который соединяет две части: Part0 (родитель, остаётся на месте) и Part1 (потомок, который поворачивается).",
					"Набор частей, связанных Motor6D, называется РИГ (rig). Именно риг вы анимируете. Если в модели нет Motor6D — анимировать нечего, редактор просто не увидит суставов.",
					"У Motor6D есть C0 и C1 — это CFrame'ы, задающие, где именно находится точка вращения относительно каждой части. Анимация меняет свойство Transform у Motor6D: это смещение поверх базовой позы.",
					"Два стандартных рига персонажа: R6 — 6 частей и 5 суставов (Neck, Left/Right Shoulder, Left/Right Hip), стилизованный и дешёвый. R15 — 15 частей и 14 суставов, есть локти, колени, кисти и UpperTorso/LowerTorso; движения гораздо плавнее.",
					"Важное правило: анимация, сделанная для R15, НЕ будет работать на R6 и наоборот. Имена суставов разные. Выбирайте риг до того, как начнёте анимировать.",
				},
				en = {
					"A Roblox animation never moves parts directly. It rotates JOINTS. A joint is a Motor6D object that connects two parts: Part0 (the parent, stays put) and Part1 (the child, which rotates).",
					"A set of parts connected by Motor6D is called a RIG. The rig is what you animate. If a model has no Motor6D, there is nothing to animate and the editor will show no joints.",
					"Motor6D has C0 and C1 — CFrames that define where the pivot sits relative to each part. An animation drives the Motor6D Transform property: an offset applied on top of the base pose.",
					"There are two standard character rigs: R6 — 6 parts and 5 joints (Neck, Left/Right Shoulder, Left/Right Hip), stylized and cheap. R15 — 15 parts and 14 joints, with elbows, knees, wrists and UpperTorso/LowerTorso; much smoother motion.",
					"Key rule: an animation authored for R15 will NOT work on R6 and vice versa. The joint names differ. Pick your rig before you start animating.",
				},
			},
			steps = {
				ru = {
					"Откройте вкладку Avatar → Rig Builder и вставьте R15 Rig в Workspace.",
					"В Explorer раскройте модель и найдите внутри частей объекты Motor6D (например, UpperTorso → Neck, LeftUpperArm → LeftElbow).",
					"Выделите любой Motor6D и посмотрите в Properties на Part0, Part1, C0, C1.",
					"Для сравнения вставьте R6 Rig и посчитайте суставы: их будет всего 5.",
				},
				en = {
					"Open the Avatar tab → Rig Builder and insert an R15 Rig into the Workspace.",
					"In the Explorer, expand the model and find the Motor6D objects inside the parts (for example UpperTorso → Neck, LeftUpperArm → LeftElbow).",
					"Select any Motor6D and inspect Part0, Part1, C0 and C1 in Properties.",
					"For comparison insert an R6 Rig and count its joints: there are only 5.",
				},
			},
			practice = {
				ru = "Вставьте R15-риг в Workspace и найдите в нём минимум 3 объекта Motor6D. Назовите, какие части соединяет сустав LeftElbow.",
				en = "Insert an R15 rig into the Workspace and locate at least 3 Motor6D objects. Say which parts the LeftElbow joint connects.",
			},
			check = "rig-in-workspace",
			quiz = {
				question = {
					ru = "Что именно анимация изменяет, когда персонаж машет рукой?",
					en = "What does an animation actually change when a character waves?",
				},
				options = {
					{ ru = "Свойство Position у части руки", en = "The Position property of the arm part" },
					{ ru = "Свойство Transform у Motor6D сустава", en = "The Transform property of the Motor6D joint" },
					{ ru = "Свойство CFrame у модели целиком", en = "The CFrame of the whole model" },
					{ ru = "Скорость Humanoid", en = "The Humanoid's speed" },
				},
				answer = 2,
				explain = {
					ru = "Анимация вращает суставы: она пишет в Motor6D.Transform. Позиции частей пересчитываются физическим движком уже как следствие.",
					en = "Animations rotate joints by writing to Motor6D.Transform. Part positions are recomputed by the engine as a consequence.",
				},
			},
			keywords = { "motor6d", "rig", "r6", "r15", "joint", "сустав", "риг" },
		},

		{
			id = "1-2-editor-tour",
			module = 1,
			minutes = 10,
			title = { ru = "Редактор анимаций: интерфейс", en = "The Animation Editor: the interface" },
			goal = {
				ru = "Уверенно открывать редактор, двигать таймлайн и ставить первые позы.",
				en = "Confidently open the editor, navigate the timeline and set your first poses.",
			},
			theory = {
				ru = {
					"Animation Editor находится во вкладке Avatar. Порядок всегда один: сначала ВЫДЕЛИТЬ риг в Workspace, потом нажать Animation Editor. Если ничего не выделено, редактор попросит выбрать риг.",
					"При первом открытии он попросит имя анимации. Это внутреннее имя (KeyframeSequence), его потом видно в списке — назовите осмысленно, например Idle_Breathing.",
					"Слева — список дорожек (по одной на сустав). Справа — таймлайн со шкалой времени. Красная вертикальная линия — скраббер (текущее время).",
					"Чтобы поставить ключ: поставьте скраббер на нужное время, поверните часть в 3D-виде инструментом Rotate (R) — ключевой кадр создастся автоматически на всех изменённых суставах.",
					"По умолчанию длина анимации 1 секунда. Её можно растянуть, перетащив конечный маркер, или задать точно через настройки таймлайна.",
					"Кнопка с шестерёнкой справа от таймлайна открывает настройки: там включается показ Animation Events и переключение единиц (секунды / кадры).",
				},
				en = {
					"The Animation Editor lives in the Avatar tab. The order is always the same: first SELECT the rig in the Workspace, then click Animation Editor. With nothing selected it will ask you to pick a rig.",
					"On first open it asks for an animation name. This is the internal name (the KeyframeSequence) shown in the list later — name it meaningfully, e.g. Idle_Breathing.",
					"On the left is the track list (one per joint). On the right is the timeline. The red vertical line is the scrubber (the current time).",
					"To create a key: move the scrubber to the desired time, then rotate a part in the 3D view with the Rotate tool (R) — a keyframe is created automatically on every joint you changed.",
					"The default animation length is 1 second. Drag the end marker to extend it, or set it precisely through the timeline settings.",
					"The gear icon to the right of the timeline opens settings: that is where you enable Animation Events and switch units (seconds / frames).",
				},
			},
			steps = {
				ru = {
					"Выделите свой R15-риг в Workspace.",
					"Avatar → Animation Editor. Введите имя Idle_Test и нажмите Create.",
					"Нажмите R (Rotate) и поверните правую руку рига — на таймлайне появятся точки-ключи.",
					"Перетащите скраббер и нажмите пробел, чтобы проиграть.",
					"Откройте настройки таймлайна (шестерёнка) и включите Show Animation Events — пригодится в модуле 2.",
				},
				en = {
					"Select your R15 rig in the Workspace.",
					"Avatar → Animation Editor. Type the name Idle_Test and click Create.",
					"Press R (Rotate) and rotate the rig's right arm — key dots appear on the timeline.",
					"Drag the scrubber and press space to play it back.",
					"Open the timeline settings (gear) and enable Show Animation Events — you will need it in module 2.",
				},
			},
			practice = {
				ru = "Создайте анимацию Idle_Test длиной 2 секунды, где персонаж поднимает правую руку и опускает её обратно. Минимум 3 ключевых кадра.",
				en = "Create a 2-second Idle_Test animation where the character raises its right arm and lowers it back. At least 3 keyframes.",
			},
			quiz = {
				question = {
					ru = "Вы нажали Animation Editor, но он просит выбрать риг. Почему?",
					en = "You clicked Animation Editor but it asks you to select a rig. Why?",
				},
				options = {
					{ ru = "Не установлен плагин", en = "The plugin is not installed" },
					{ ru = "В Workspace не выделена модель с Motor6D", en = "No model with Motor6D is selected in the Workspace" },
					{ ru = "Нужно сначала опубликовать игру", en = "You must publish the place first" },
					{ ru = "Редактор работает только в Play-режиме", en = "The editor only works in Play mode" },
				},
				answer = 2,
				explain = {
					ru = "Редактору нужен объект для анимации. Выделите модель с суставами Motor6D перед открытием.",
					en = "The editor needs something to animate. Select a model containing Motor6D joints before opening it.",
				},
			},
			keywords = { "editor", "редактор", "timeline", "таймлайн", "scrubber" },
		},

		{
			id = "1-3-first-animation",
			module = 1,
			minutes = 14,
			title = { ru = "Первая анимация: позы и тайминг", en = "Your first animation: poses and timing" },
			goal = {
				ru = "Сделать читаемый цикл idle и понять принцип «поза важнее движения».",
				en = "Build a readable idle loop and internalize 'the pose matters more than the motion'.",
			},
			theory = {
				ru = {
					"Ключевой кадр (keyframe) — это сохранённая ПОЗА в конкретный момент времени. Движок сам достраивает промежуточные кадры (интерполяция). Ваша работа — выбрать хорошие позы и правильные моменты.",
					"Правило зацикливания: чтобы цикл не «дёргался», первый и последний кадр должны совпадать. Самый надёжный способ — скопировать первый кадр (правой кнопкой → Copy) и вставить его в конец.",
					"Тайминг решает всё. Одинаковые интервалы между ключами выглядят механически. Живое движение имеет неравномерный ритм: быстрый выпад и медленный возврат.",
					"Принцип контраста: если все части двигаются одинаково, глаз не читает движение. Смещайте фазы — рука начинает движение на пару кадров раньше корпуса.",
					"Для idle-анимации достаточно очень малых углов: 2–5 градусов на дыхание груди и лёгкое покачивание. Новички почти всегда делают idle слишком размашистым.",
					"Не забывайте про HumanoidRootPart: вертикальное смещение всего тела на 0.05–0.1 studs добавляет вес и дыхание.",
				},
				en = {
					"A keyframe is a saved POSE at a specific moment in time. The engine fills in the frames between them (interpolation). Your job is to pick good poses and good moments.",
					"Looping rule: for a loop not to pop, the first and last frames must match. The safest way is to copy the first keyframe (right click → Copy) and paste it at the end.",
					"Timing is everything. Evenly spaced keys look mechanical. Living motion has an uneven rhythm: a fast strike and a slow recovery.",
					"The contrast principle: if every part moves identically the eye cannot read the motion. Offset the phases — let the arm start a couple of frames before the torso.",
					"An idle needs tiny angles: 2–5 degrees of chest breathing and a slight sway. Beginners almost always make idles far too broad.",
					"Do not forget HumanoidRootPart: shifting the whole body vertically by 0.05–0.1 studs adds weight and breath.",
				},
			},
			steps = {
				ru = {
					"Создайте новую анимацию Idle_Breathing длиной 2 секунды.",
					"Кадр 0:00 — базовая стойка, ничего не трогайте, но поставьте ключ на UpperTorso.",
					"Кадр 1:00 — поднимите UpperTorso на 0.05 studs вверх и наклоните на 2 градуса назад; чуть разведите руки.",
					"Кадр 2:00 — вернитесь ровно в позу кадра 0:00 (скопируйте её).",
					"Включите Loop в настройках редактора и проиграйте: переход должен быть незаметным.",
				},
				en = {
					"Create a new 2-second animation called Idle_Breathing.",
					"Frame 0:00 — the base stance; change nothing but set a key on UpperTorso.",
					"Frame 1:00 — raise UpperTorso by 0.05 studs and tilt it 2 degrees back; open the arms slightly.",
					"Frame 2:00 — return exactly to the pose from frame 0:00 (copy it).",
					"Enable Loop in the editor settings and play: the wrap should be invisible.",
				},
			},
			practice = {
				ru = "Сделайте зацикленный idle на 2 секунды, где первый и последний кадр идентичны, а амплитуда дыхания не превышает 5 градусов.",
				en = "Build a looping 2-second idle where the first and last frames are identical and the breathing amplitude stays under 5 degrees.",
			},
			quiz = {
				question = {
					ru = "Зацикленная анимация заметно «дёргается» в момент повтора. Самая вероятная причина?",
					en = "A looped animation visibly pops at the wrap point. Most likely cause?",
				},
				options = {
					{ ru = "Слишком много ключевых кадров", en = "Too many keyframes" },
					{ ru = "Первый и последний кадр — разные позы", en = "The first and last frames are different poses" },
					{ ru = "Не выставлен Priority", en = "Priority is not set" },
					{ ru = "Анимация слишком короткая", en = "The animation is too short" },
				},
				answer = 2,
				explain = {
					ru = "При зацикливании последний кадр мгновенно сменяется первым. Если позы не совпадают, получается скачок.",
					en = "When looping, the last frame is instantly replaced by the first. If the poses differ you get a jump.",
				},
			},
			keywords = { "keyframe", "ключевой кадр", "idle", "loop", "цикл", "timing", "тайминг", "поза" },
		},

		{
			id = "1-4-easing-curves",
			module = 1,
			minutes = 12,
			title = { ru = "Плавность: easing и кривые", en = "Smoothness: easing and curves" },
			goal = {
				ru = "Управлять характером движения через Easing Style/Direction и Curve Editor.",
				en = "Control the character of motion with Easing Style/Direction and the Curve Editor.",
			},
			theory = {
				ru = {
					"Между двумя ключами движок интерполирует позу. КАК он это делает, задаёт easing — это свойство ключевого кадра, а не всей анимации.",
					"Easing Style — форма кривой: Linear (равномерно, механически), Sine (мягко, универсально), Quad/Cubic (сильнее ускорение), Back (перелёт назад перед движением), Elastic (пружина), Bounce (отскок), Constant (мгновенный скачок без интерполяции).",
					"Easing Direction — где применяется кривая: In (медленно в начале), Out (медленно в конце), InOut (медленно с обеих сторон). Для большинства человеческих движений подходит Sine + InOut.",
					"Реальные тела не стартуют мгновенно: они разгоняются и тормозят. Это называется slow in / slow out и это главный приём, отличающий живую анимацию от «робота».",
					"Чтобы задать easing: выделите ключ на таймлайне, правая кнопка → Easing Style / Easing Direction.",
					"Curve Editor (вкладка рядом с таймлайном) показывает значения как графики и даёт двигать касательные вручную. Это нужно, когда пресетов easing не хватает: например, чтобы сделать резкий удар с длинным затуханием.",
					"Приём Constant незаменим для «щелчков»: смена позы кадр-в-кадр без размазывания, как в pixel-art анимации или для мгновенной телепортации части.",
				},
				en = {
					"Between two keys the engine interpolates the pose. HOW it does that is defined by easing — a property of the keyframe, not of the whole animation.",
					"Easing Style is the shape of the curve: Linear (constant, mechanical), Sine (soft, a good default), Quad/Cubic (stronger acceleration), Back (overshoots backwards first), Elastic (springy), Bounce, Constant (an instant jump with no interpolation).",
					"Easing Direction is where the curve applies: In (slow at the start), Out (slow at the end), InOut (slow at both). Sine + InOut fits most human motion.",
					"Real bodies do not start instantly: they accelerate and decelerate. This is slow in / slow out, the single biggest thing separating living animation from a robot.",
					"To set easing: select a key on the timeline, right click → Easing Style / Easing Direction.",
					"The Curve Editor (a tab next to the timeline) shows values as graphs and lets you drag tangents by hand. Use it when the presets are not enough — for example a sharp hit with a long settle.",
					"Constant is invaluable for snaps: a pose change frame-to-frame with no smearing, as in pixel-art animation or to teleport a part instantly.",
				},
			},
			steps = {
				ru = {
					"Возьмите анимацию с одним резким движением руки (2 ключа).",
					"Выделите второй ключ → Easing Style → Linear. Проиграйте, запомните ощущение.",
					"Смените на Sine + InOut. Проиграйте снова — движение стало естественным.",
					"Попробуйте Back + Out на замахе: рука слегка уйдёт назад перед ударом.",
					"Откройте Curve Editor и посмотрите, как меняется форма графика для каждого стиля.",
				},
				en = {
					"Take an animation with one sharp arm movement (2 keys).",
					"Select the second key → Easing Style → Linear. Play it and remember how it feels.",
					"Switch to Sine + InOut. Play again — the motion now feels natural.",
					"Try Back + Out on a wind-up: the arm drifts back slightly before the strike.",
					"Open the Curve Editor and watch how the graph shape changes per style.",
				},
			},
			practice = {
				ru = "Сделайте анимацию удара, где замах использует Back/Out, сам удар — Quad/In (резкий), а возврат — Sine/InOut (медленный).",
				en = "Build a punch where the wind-up uses Back/Out, the strike uses Quad/In (sharp) and the recovery uses Sine/InOut (slow).",
			},
			quiz = {
				question = {
					ru = "Нужно, чтобы часть мгновенно перескочила в новую позу без плавного перехода. Какой Easing Style?",
					en = "You need a part to snap to a new pose with no smooth transition. Which Easing Style?",
				},
				options = {
					{ ru = "Linear", en = "Linear" },
					{ ru = "Constant", en = "Constant" },
					{ ru = "Elastic", en = "Elastic" },
					{ ru = "Sine", en = "Sine" },
				},
				answer = 2,
				explain = {
					ru = "Constant держит предыдущее значение до самого следующего ключа и меняет позу мгновенно — без интерполяции.",
					en = "Constant holds the previous value until the next key and swaps the pose instantly — no interpolation.",
				},
			},
			keywords = { "easing", "curve", "кривая", "изинг", "плавность", "интерполяция", "graph editor" },
		},

		{
			id = "1-5-export-publish",
			module = 1,
			minutes = 9,
			title = { ru = "Экспорт и AnimationId", en = "Exporting and the AnimationId" },
			goal = {
				ru = "Опубликовать анимацию и получить рабочий rbxassetid, понимая ограничения владельца.",
				en = "Publish an animation, get a working rbxassetid and understand the ownership rules.",
			},
			theory = {
				ru = {
					"Пока анимация живёт только в редакторе, скрипты её не видят. Её нужно опубликовать на Roblox и получить числовой ID.",
					"В редакторе: меню «...» (три точки) → Publish to Roblox. Заполните имя и описание, подтвердите. После публикации ID можно скопировать из того же меню (Copy Asset ID) или в Creator Dashboard → Development Items → Animations.",
					"В скрипте ID используется так: animation.AnimationId = \"rbxassetid://ЧИСЛО\". Именно с префиксом rbxassetid:// — просто число не сработает.",
					"САМАЯ ЧАСТАЯ ОШИБКА новичков: анимация не играет, потому что её владелец не совпадает с владельцем игры. Если вы опубликовали анимацию от своего аккаунта, а игра принадлежит группе — работать не будет. Публикуйте анимацию от того же владельца (в диалоге публикации есть выбор Creator).",
					"Обновление: если вы переработали анимацию, публикуйте её ПОВЕРХ существующего ассета (Overwrite / Update existing), тогда ID не изменится и скрипты править не придётся.",
					"Проверить, что ассет загрузился, можно по track.Length: если после LoadAnimation длина равна 0 — ассет не подгрузился (неверный ID или чужой владелец).",
				},
				en = {
					"While an animation lives only in the editor, scripts cannot see it. You must publish it to Roblox and get a numeric ID.",
					"In the editor: the \"...\" menu → Publish to Roblox. Fill in a name and description and confirm. Afterwards copy the ID from the same menu (Copy Asset ID) or from Creator Dashboard → Development Items → Animations.",
					"In a script the ID is used as animation.AnimationId = \"rbxassetid://NUMBER\". The rbxassetid:// prefix is required — a bare number will not work.",
					"THE most common beginner failure: the animation does not play because its owner differs from the owner of the experience. If you published it under your account but the game belongs to a group, it will not run. Publish under the same creator (the publish dialog has a Creator selector).",
					"Updating: when you rework an animation, publish it OVER the existing asset (Overwrite / Update existing) so the ID stays the same and no script changes are needed.",
					"To confirm the asset loaded, check track.Length: if it is 0 after LoadAnimation, the asset did not load (wrong ID or wrong owner).",
				},
			},
			steps = {
				ru = {
					"Откройте свою анимацию Idle_Breathing в редакторе.",
					"Меню «...» → Publish to Roblox. Проверьте поле Creator: оно должно совпадать с владельцем игры.",
					"После публикации скопируйте Asset ID.",
					"Сохраните ID в заметках — он понадобится в модуле 2.",
				},
				en = {
					"Open your Idle_Breathing animation in the editor.",
					"The \"...\" menu → Publish to Roblox. Check the Creator field: it must match the owner of the experience.",
					"After publishing, copy the Asset ID.",
					"Keep the ID handy — you will need it in module 2.",
				},
			},
			practice = {
				ru = "Опубликуйте свою idle-анимацию и запишите её ID в формате rbxassetid://ЧИСЛО.",
				en = "Publish your idle animation and write down its ID as rbxassetid://NUMBER.",
			},
			quiz = {
				question = {
					ru = "Анимация опубликована, ID вставлен, ошибок в Output нет, но персонаж не двигается, а track.Length = 0. Что проверить первым?",
					en = "The animation is published, the ID is set, no errors in Output, but nothing moves and track.Length = 0. What do you check first?",
				},
				options = {
					{ ru = "Совпадает ли владелец анимации с владельцем игры", en = "Whether the animation's owner matches the game's owner" },
					{ ru = "Скорость трека", en = "The track speed" },
					{ ru = "Количество ключевых кадров", en = "The number of keyframes" },
					{ ru = "Версию Studio", en = "The Studio version" },
				},
				answer = 1,
				explain = {
					ru = "Length = 0 означает, что данные ассета не загрузились. Чаще всего это несовпадение владельца (аккаунт против группы) или неверный ID.",
					en = "Length = 0 means the asset data never loaded. Usually that is an owner mismatch (account vs group) or a wrong ID.",
				},
			},
			keywords = { "export", "экспорт", "publish", "публикация", "assetid", "rbxassetid", "owner", "владелец", "группа" },
		},

		--==================================================================
		-- MODULE 2
		--==================================================================

		{
			id = "2-1-animator-track",
			module = 2,
			minutes = 12,
			title = { ru = "Animator и AnimationTrack", en = "Animator and AnimationTrack" },
			goal = {
				ru = "Проиграть свою анимацию из скрипта по современному API.",
				en = "Play your animation from a script using the current API.",
			},
			theory = {
				ru = {
					"Цепочка всегда одна и та же: Animation (ссылка на ассет) → Animator:LoadAnimation() → AnimationTrack (то, чем вы управляете) → track:Play().",
					"Animator — это объект внутри Humanoid. У любого персонажа он уже есть, надо просто дождаться: humanoid:WaitForChild(\"Animator\").",
					"ВАЖНО: Humanoid:LoadAnimation() и AnimationController:LoadAnimation() устарели (deprecated). Всегда используйте Animator:LoadAnimation(). Старый код в туториалах на YouTube чаще всего именно поэтому и ломается.",
					"LoadAnimation — дорогая операция. Загружайте трек ОДИН раз при старте и переиспользуйте его. Загрузка внутри обработчика нажатия создаёт новый трек на каждый клик и быстро съедает память.",
					"AnimationTrack — это ваш пульт: Play(fadeTime, weight, speed), Stop(fadeTime), AdjustSpeed(), AdjustWeight(), а также свойства IsPlaying, Length, TimePosition, Speed, Looped, Priority.",
					"У Play есть fadeTime (по умолчанию 0.1 с) — за это время трек плавно набирает вес. Резкий Play(0) выглядит дёргано; Stop(0) обрезает движение.",
					"После респавна персонажа появляется НОВЫЙ Humanoid и новый Animator. Все старые треки становятся бесполезными — их надо загружать заново в обработчике CharacterAdded.",
				},
				en = {
					"The chain is always the same: Animation (a pointer to the asset) → Animator:LoadAnimation() → AnimationTrack (what you control) → track:Play().",
					"The Animator is an object inside the Humanoid. Every character already has one; just wait for it: humanoid:WaitForChild(\"Animator\").",
					"IMPORTANT: Humanoid:LoadAnimation() and AnimationController:LoadAnimation() are deprecated. Always use Animator:LoadAnimation(). Old YouTube tutorials break for exactly this reason.",
					"LoadAnimation is expensive. Load the track ONCE at startup and reuse it. Loading inside a click handler creates a new track per click and burns memory fast.",
					"AnimationTrack is your remote control: Play(fadeTime, weight, speed), Stop(fadeTime), AdjustSpeed(), AdjustWeight(), plus the properties IsPlaying, Length, TimePosition, Speed, Looped and Priority.",
					"Play takes a fadeTime (0.1 s by default) over which the track ramps its weight up. A hard Play(0) looks jerky; Stop(0) cuts the motion off.",
					"After a respawn there is a NEW Humanoid and a new Animator. All old tracks are dead — reload them inside a CharacterAdded handler.",
				},
			},
			steps = {
				ru = {
					"Создайте LocalScript в StarterPlayer → StarterPlayerScripts.",
					"Вставьте пример кода этого урока (кнопка «Вставить код»).",
					"Замените rbxassetid://0 на ID своей анимации из урока 1-5.",
					"Нажмите Play и проверьте Output на ошибки.",
				},
				en = {
					"Create a LocalScript in StarterPlayer → StarterPlayerScripts.",
					"Insert this lesson's code sample (the \"Insert code\" button).",
					"Replace rbxassetid://0 with the ID of your animation from lesson 1-5.",
					"Press Play and check the Output for errors.",
				},
			},
			snippet = "play-basic",
			practice = {
				ru = "Запустите свою idle-анимацию из LocalScript. Затем перепишите скрипт так, чтобы трек корректно перезагружался после смерти персонажа.",
				en = "Play your idle animation from a LocalScript. Then rewrite it so the track reloads correctly after the character dies.",
			},
			check = "localscript-with-animator",
			quiz = {
				question = {
					ru = "Какой из вариантов — правильный современный способ получить AnimationTrack?",
					en = "Which of these is the correct modern way to obtain an AnimationTrack?",
				},
				options = {
					{ ru = "humanoid:LoadAnimation(animation)", en = "humanoid:LoadAnimation(animation)" },
					{ ru = "animator:LoadAnimation(animation)", en = "animator:LoadAnimation(animation)" },
					{ ru = "animation:Play()", en = "animation:Play()" },
					{ ru = "character:LoadAnimation(animation)", en = "character:LoadAnimation(animation)" },
				},
				answer = 2,
				explain = {
					ru = "Humanoid:LoadAnimation устарел. Современный путь — получить Animator внутри Humanoid и вызвать LoadAnimation у него.",
					en = "Humanoid:LoadAnimation is deprecated. The modern path is to get the Animator inside the Humanoid and call LoadAnimation on it.",
				},
			},
			keywords = { "animator", "loadanimation", "animationtrack", "track", "play", "deprecated", "трек" },
		},

		{
			id = "2-2-priority-looped",
			module = 2,
			minutes = 11,
			title = { ru = "Приоритеты и зацикливание", en = "Priorities and looping" },
			goal = {
				ru = "Понять, почему анимация «не видна», и управлять слоями через Priority.",
				en = "Understand why an animation seems invisible and control layering with Priority.",
			},
			theory = {
				ru = {
					"Когда несколько треков двигают один сустав, побеждает трек с более высоким приоритетом. Это не смешивание — это перекрытие.",
					"Шкала от низшего к высшему: Core → Idle → Movement → Action → Action2 → Action3 → Action4.",
					"Стандартные анимации персонажа (ходьба, прыжок из скрипта Animate) работают на Movement и Idle. Поэтому ваша анимация с приоритетом Idle будет ПЕРЕКРЫТА ходьбой, и вам покажется, что она «не работает».",
					"Правило по умолчанию: любое действие игрока (удар, взмах, эмоция) ставьте на Action. Тогда оно перекроет стандартную ходьбу.",
					"Приоритет можно задать двумя способами: в редакторе анимаций (сохраняется в самом ассете) или в скрипте через track.Priority = Enum.AnimationPriority.Action. Скрипт имеет приоритет над настройкой ассета.",
					"track.Looped: если анимация должна повторяться (idle, бег) — true. Для одноразовых действий (удар) — false, иначе она никогда не закончится и Ended не сработает.",
					"Свойство Looped тоже сохраняется в ассете при публикации, но в скрипте его можно переопределить.",
					"Если два трека имеют ОДИНАКОВЫЙ приоритет, они смешиваются по весу — об этом следующий урок.",
				},
				en = {
					"When several tracks drive the same joint, the one with the higher priority wins. This is not blending — it is overriding.",
					"The scale from lowest to highest: Core → Idle → Movement → Action → Action2 → Action3 → Action4.",
					"The default character animations (walking, jumping, from the Animate script) run at Movement and Idle. So your animation set to Idle gets OVERRIDDEN by walking, and it looks like it 'does not work'.",
					"Default rule: any player action (a hit, a swing, an emote) goes on Action. That beats the built-in locomotion.",
					"Priority can be set two ways: in the Animation Editor (baked into the asset) or in a script via track.Priority = Enum.AnimationPriority.Action. The script wins over the asset setting.",
					"track.Looped: true for anything that repeats (idle, run). For one-shot actions (a punch) use false, otherwise it never ends and Ended never fires.",
					"Looped is also stored in the asset on publish, but a script can override it.",
					"If two tracks share the SAME priority they blend by weight — that is the next lesson.",
				},
			},
			steps = {
				ru = {
					"Возьмите скрипт из прошлого урока и уберите строку с Priority.",
					"Запустите игру и начните бежать во время анимации — она пропадёт.",
					"Верните track.Priority = Enum.AnimationPriority.Action и повторите: теперь анимация перекрывает бег.",
					"Поэкспериментируйте с Looped = true / false на одноразовом действии.",
				},
				en = {
					"Take the script from the previous lesson and remove the Priority line.",
					"Run the game and start running during the animation — it disappears.",
					"Restore track.Priority = Enum.AnimationPriority.Action and repeat: now it overrides running.",
					"Experiment with Looped = true / false on a one-shot action.",
				},
			},
			practice = {
				ru = "Добейтесь, чтобы ваша анимация взмаха рукой была видна, пока персонаж бежит. Объясните, какой приоритет вы выбрали и почему.",
				en = "Make your arm-wave animation visible while the character is running. Explain which priority you chose and why.",
			},
			quiz = {
				question = {
					ru = "Ваша анимация играет, когда персонаж стоит, но исчезает при беге. Что сделать?",
					en = "Your animation plays while standing but vanishes when running. What do you do?",
				},
				options = {
					{ ru = "Увеличить скорость трека", en = "Increase the track speed" },
					{ ru = "Поставить Priority = Action (выше, чем Movement)", en = "Set Priority = Action (above Movement)" },
					{ ru = "Включить Looped", en = "Enable Looped" },
					{ ru = "Перезагрузить Studio", en = "Restart Studio" },
				},
				answer = 2,
				explain = {
					ru = "Бег работает на приоритете Movement. Чтобы перекрыть его, нужен более высокий уровень — Action.",
					en = "Running runs at Movement priority. To override it you need a higher level — Action.",
				},
			},
			keywords = { "priority", "приоритет", "looped", "цикл", "action", "movement", "перекрытие" },
		},

		{
			id = "2-3-events",
			module = 2,
			minutes = 10,
			title = { ru = "События анимации (маркеры)", en = "Animation events (markers)" },
			goal = {
				ru = "Синхронизировать урон, звук и эффекты с точным кадром анимации.",
				en = "Sync damage, sound and effects to an exact frame of the animation.",
			},
			theory = {
				ru = {
					"Проблема: удар должен наносить урон именно в момент касания, а не через task.wait(0.35) наугад. Если вы поменяете тайминг анимации, все хардкод-задержки поедут.",
					"Решение — Animation Events: именованные маркеры прямо на таймлайне. Скрипт подписывается на имя маркера и получает сигнал ровно в тот момент, когда скраббер до него дошёл.",
					"Создание: в редакторе включите Show Animation Events (шестерёнка справа от таймлайна), поставьте скраббер на нужный кадр, нажмите Edit Animation Events → + Add Event, введите имя (например HitFrame).",
					"У события есть необязательный Parameter — произвольная строка. Через неё удобно передавать данные: \"20\" (урон), \"left,heavy\" (нога и сила).",
					"В коде: track:GetMarkerReachedSignal(\"HitFrame\"):Connect(function(param) ... end). Имя должно совпадать точно, с учётом регистра.",
					"Событие сработает столько раз, сколько маркеров с этим именем стоит на таймлайне. Это удобно для шагов: два маркера FootStep — два звука за цикл.",
					"Маркеры сохраняются внутри ассета анимации, поэтому после изменения событий анимацию нужно опубликовать заново (поверх старого ассета).",
				},
				en = {
					"The problem: a punch should deal damage exactly on contact, not after a guessed task.wait(0.35). Change the animation timing and every hardcoded delay is wrong.",
					"The fix is Animation Events: named markers placed on the timeline. A script subscribes to the marker name and is signalled the instant the scrubber reaches it.",
					"To create one: enable Show Animation Events in the editor (the gear right of the timeline), move the scrubber to the frame, click Edit Animation Events → + Add Event and type a name (e.g. HitFrame).",
					"An event has an optional Parameter — an arbitrary string. It is handy for data: \"20\" (damage) or \"left,heavy\" (which foot and how hard).",
					"In code: track:GetMarkerReachedSignal(\"HitFrame\"):Connect(function(param) ... end). The name must match exactly, case included.",
					"The event fires once per marker with that name on the timeline. Great for footsteps: two FootStep markers, two sounds per cycle.",
					"Markers are stored inside the animation asset, so after editing events you must republish the animation (over the existing asset).",
				},
			},
			steps = {
				ru = {
					"Откройте анимацию удара в редакторе и включите показ событий.",
					"Поставьте маркер HitFrame на кадр контакта и маркер Recover на начало возврата.",
					"Опубликуйте анимацию поверх старого ассета.",
					"Вставьте код этого урока и подпишитесь на оба маркера, выводя print.",
				},
				en = {
					"Open your punch animation in the editor and enable event display.",
					"Place a HitFrame marker on the contact frame and a Recover marker where the recovery starts.",
					"Republish the animation over the existing asset.",
					"Insert this lesson's code and subscribe to both markers with a print.",
				},
			},
			snippet = "events-markers",
			practice = {
				ru = "Добавьте в анимацию ходьбы два маркера FootStep и проигрывайте звук шага по каждому. Передайте через Parameter, какая нога («left» / «right»).",
				en = "Add two FootStep markers to a walk animation and play a step sound on each. Use the Parameter to say which foot ('left' / 'right').",
			},
			quiz = {
				question = {
					ru = "Почему маркеры лучше, чем task.wait(0.35) перед нанесением урона?",
					en = "Why are markers better than task.wait(0.35) before applying damage?",
				},
				options = {
					{ ru = "Они быстрее выполняются", en = "They execute faster" },
					{ ru = "Они привязаны к кадру анимации и не ломаются при смене тайминга", en = "They are tied to the animation frame and survive timing changes" },
					{ ru = "Они работают только на сервере", en = "They only work on the server" },
					{ ru = "Они не требуют публикации", en = "They do not require publishing" },
				},
				answer = 2,
				explain = {
					ru = "Маркер живёт внутри анимации. Изменили тайминг — момент срабатывания сместится вместе с ним, код править не нужно.",
					en = "The marker lives inside the animation. Change the timing and the trigger moves with it — no code changes needed.",
				},
			},
			keywords = { "event", "событие", "marker", "маркер", "getmarkerreachedsignal", "keyframe", "звук", "урон" },
		},

		{
			id = "2-4-weight-speed",
			module = 2,
			minutes = 12,
			title = { ru = "Веса, смешивание и скорость", en = "Weights, blending and speed" },
			goal = {
				ru = "Плавно смешивать несколько анимаций и управлять темпом на лету.",
				en = "Blend several animations smoothly and control tempo on the fly.",
			},
			theory = {
				ru = {
					"Вес (weight) определяет, насколько сильно трек влияет на итоговую позу. Диапазон обычный — от 0 до 1, по умолчанию 1.",
					"Когда несколько треков имеют ОДИНАКОВЫЙ приоритет, итоговая поза = взвешенное среднее их поз. Именно так делают плавный переход ходьба → бег без рывка.",
					"AdjustWeight(weight, fadeTime) меняет вес не мгновенно: WeightCurrent плавно едет к WeightTarget за fadeTime секунд. Всегда давайте хотя бы 0.1, иначе смысл блендинга теряется.",
					"Практический приём: два трека Movement — walk и run. walk:AdjustWeight(1 - alpha), run:AdjustWeight(alpha), где alpha считается от текущей скорости персонажа. Получается непрерывный переход.",
					"AdjustSpeed(speed) меняет темп: 1 — нормально, 2 — вдвое быстрее, 0 — пауза, отрицательное значение — воспроизведение задом наперёд.",
					"Полезная формула: чтобы анимация шага совпадала с реальной скоростью персонажа, ставьте track:AdjustSpeed(humanoid.WalkSpeed / BASE_SPEED), где BASE_SPEED — скорость, под которую анимация рисовалась. Это убирает эффект «скольжения ног».",
					"track.Length — длина при скорости 1. Реальная длительность = Length / Speed.",
					"Не путайте вес и приоритет: приоритет решает, КТО победит; вес решает, НАСКОЛЬКО, среди равных.",
				},
				en = {
					"Weight defines how strongly a track contributes to the final pose. The usual range is 0 to 1, default 1.",
					"When several tracks share the SAME priority, the final pose is the weighted average of their poses. That is exactly how a seamless walk → run transition is built.",
					"AdjustWeight(weight, fadeTime) is not instant: WeightCurrent glides toward WeightTarget over fadeTime seconds. Always give it at least 0.1 or you lose the point of blending.",
					"A practical recipe: two Movement tracks, walk and run. walk:AdjustWeight(1 - alpha) and run:AdjustWeight(alpha), where alpha comes from the character's current speed. The transition becomes continuous.",
					"AdjustSpeed(speed) changes tempo: 1 is normal, 2 is twice as fast, 0 pauses, and a negative value plays it backwards.",
					"A useful formula: to match a walk cycle to the real character speed, use track:AdjustSpeed(humanoid.WalkSpeed / BASE_SPEED), where BASE_SPEED is the speed the animation was authored for. This kills foot sliding.",
					"track.Length is the length at speed 1. The real duration is Length / Speed.",
					"Do not confuse weight and priority: priority decides WHO wins; weight decides BY HOW MUCH, among equals.",
				},
			},
			steps = {
				ru = {
					"Загрузите два трека — walk и run — и поставьте обоим Priority = Movement.",
					"Запустите оба через Play() и выставьте начальные веса 1 и 0.",
					"В RenderStepped считайте alpha от скорости и вызывайте AdjustWeight.",
					"Отдельно проверьте AdjustSpeed(0.5) и AdjustSpeed(-1).",
				},
				en = {
					"Load two tracks — walk and run — and set both to Priority = Movement.",
					"Play both and set the initial weights to 1 and 0.",
					"In RenderStepped compute alpha from speed and call AdjustWeight.",
					"Separately try AdjustSpeed(0.5) and AdjustSpeed(-1).",
				},
			},
			snippet = "blend-weights",
			practice = {
				ru = "Сделайте плавный переход ходьба → бег через веса, без единого Stop(). Затем добавьте синхронизацию скорости анимации с WalkSpeed.",
				en = "Build a smooth walk → run transition using weights, without a single Stop(). Then sync the animation speed to WalkSpeed.",
			},
			quiz = {
				question = {
					ru = "Два трека играют одновременно с приоритетом Movement и весами 0.25 и 0.75. Что увидит игрок?",
					en = "Two tracks play at Movement priority with weights 0.25 and 0.75. What does the player see?",
				},
				options = {
					{ ru = "Только второй трек", en = "Only the second track" },
					{ ru = "Смесь поз, где второй трек влияет втрое сильнее", en = "A blend where the second track contributes three times as much" },
					{ ru = "Треки будут играть по очереди", en = "The tracks alternate" },
					{ ru = "Ошибку в Output", en = "An error in the Output" },
				},
				answer = 2,
				explain = {
					ru = "При равном приоритете позы усредняются по весам: 0.75 / (0.25 + 0.75) = 75 % влияния у второго трека.",
					en = "At equal priority the poses are averaged by weight: 0.75 / (0.25 + 0.75) = 75 % influence for the second track.",
				},
			},
			keywords = { "weight", "вес", "blend", "смешивание", "adjustweight", "adjustspeed", "speed", "скорость" },
		},

		{
			id = "2-5-default-animations",
			module = 2,
			minutes = 9,
			title = { ru = "Замена стандартных анимаций", en = "Replacing the default animations" },
			goal = {
				ru = "Поставить свою походку, прыжок и idle всем игрокам.",
				en = "Give every player your own walk, jump and idle.",
			},
			theory = {
				ru = {
					"Внутри каждого персонажа Roblox создаёт LocalScript с именем Animate. Он содержит вложенные объекты Animation для каждого состояния: run, walk, jump, idle, fall, climb, swim, swimidle.",
					"Чтобы заменить стандартную анимацию, достаточно перезаписать AnimationId у соответствующего объекта — переписывать сам скрипт Animate не нужно.",
					"Делать это надо на СЕРВЕРЕ (Script в ServerScriptService) и в момент появления персонажа. Надёжнее всего подписаться на player.CharacterAppearanceLoaded, а не на CharacterAdded: к этому моменту скрипт Animate уже точно на месте.",
					"Перед заменой стоит остановить уже играющие треки: for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0) end. Иначе старая анимация доиграет поверх новой.",
					"У idle два варианта — Animation1 и Animation2. Скрипт выбирает между ними случайно, а частоту задаёт дочерний объект Weight: шанс = вес анимации / сумма весов всех вариантов состояния.",
					"Альтернативный путь без кода: вставить собственную копию скрипта Animate в StarterCharacterScripts и отредактировать ID прямо в ней. Это удобнее для полного контроля, но копия не будет получать обновления от Roblox.",
					"Помните про совместимость рига: если ваша игра использует R15, все заменяющие анимации тоже должны быть R15.",
				},
				en = {
					"Inside every character Roblox creates a LocalScript called Animate. It holds nested Animation objects for each state: run, walk, jump, idle, fall, climb, swim, swimidle.",
					"To replace a default animation you only overwrite the AnimationId on the matching object — there is no need to rewrite the Animate script itself.",
					"Do it on the SERVER (a Script in ServerScriptService) as the character appears. The most reliable hook is player.CharacterAppearanceLoaded rather than CharacterAdded: by then the Animate script is definitely in place.",
					"Stop the already playing tracks first: for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0) end. Otherwise the old animation finishes on top of the new one.",
					"Idle has two variants, Animation1 and Animation2. The script picks randomly and a child Weight object sets the odds: chance = that animation's weight / the sum of weights for the state.",
					"A code-free alternative: put your own copy of the Animate script into StarterCharacterScripts and edit the IDs directly. That gives full control, but your copy stops receiving Roblox updates.",
					"Mind rig compatibility: if your game uses R15, every replacement animation must be R15 too.",
				},
			},
			steps = {
				ru = {
					"Создайте Script в ServerScriptService и вставьте код этого урока.",
					"Раскомментируйте строку run.RunAnim и подставьте свой ID.",
					"Запустите игру и побегайте.",
					"Добавьте замену idle и задайте Weight так, чтобы вторая вариация играла вдвое чаще.",
				},
				en = {
					"Create a Script in ServerScriptService and insert this lesson's code.",
					"Uncomment the run.RunAnim line and paste your ID.",
					"Run the game and move around.",
					"Add an idle replacement and set Weight so the second variation plays twice as often.",
				},
			},
			snippet = "replace-default",
			practice = {
				ru = "Замените стандартный бег и обе idle-вариации своими анимациями. Настройте веса 1 и 2.",
				en = "Replace the default run and both idle variations with your own animations. Set the weights to 1 and 2.",
			},
			quiz = {
				question = {
					ru = "Где находятся объекты Animation, отвечающие за стандартную ходьбу игрока?",
					en = "Where do the Animation objects for the player's default walk live?",
				},
				options = {
					{ ru = "В ServerStorage", en = "In ServerStorage" },
					{ ru = "Внутри скрипта Animate в модели персонажа", en = "Inside the Animate script in the character model" },
					{ ru = "В Humanoid", en = "In the Humanoid" },
					{ ru = "В StarterGui", en = "In StarterGui" },
				},
				answer = 2,
				explain = {
					ru = "Скрипт Animate внутри персонажа содержит вложенные Animation-объекты для каждого состояния движения.",
					en = "The Animate script inside the character holds nested Animation objects for every locomotion state.",
				},
			},
			keywords = { "default", "стандартные", "animate", "walk", "run", "ходьба", "бег", "замена", "replace" },
		},

		--==================================================================
		-- MODULE 3
		--==================================================================

		{
			id = "3-1-non-humanoid",
			module = 3,
			minutes = 10,
			title = { ru = "Модели без Humanoid", en = "Rigs without a Humanoid" },
			goal = {
				ru = "Анимировать дверь, машину, дракона — всё, что не является персонажем.",
				en = "Animate a door, a car, a dragon — anything that is not a character.",
			},
			theory = {
				ru = {
					"Animator должен где-то жить. У персонажа его родитель — Humanoid. Если Humanoid нет, вы создаёте AnimationController и кладёте Animator внутрь него.",
					"Иерархия: Model → AnimationController → Animator. Дальше всё как обычно: animator:LoadAnimation(animation).",
					"Уточнение по терминологии: сам класс AnimationController не устарел — устарел только его метод LoadAnimation. Поэтому создавайте контроллер, но загружайте через Animator.",
					"Модель всё равно должна быть ригом: части, соединённые Motor6D, и обязательно заданный PrimaryPart. Без Motor6D редактор анимаций не покажет ни одной дорожки.",
					"Частая ошибка — части не заякорены и разлетаются. Правило: якорите ТОЛЬКО корневую часть (Part0 самой первой цепочки), остальные должны быть Anchored = false, иначе суставы не смогут их двигать.",
					"Ещё одна ловушка: CanCollide у движущихся частей лучше выключить, иначе анимированная модель начнёт толкать сама себя.",
				},
				en = {
					"The Animator has to live somewhere. On a character its parent is the Humanoid. Without a Humanoid you create an AnimationController and put the Animator inside it.",
					"The hierarchy is Model → AnimationController → Animator. From there it is business as usual: animator:LoadAnimation(animation).",
					"A terminology note: the AnimationController class itself is not deprecated — only its LoadAnimation method is. So create the controller, but load through the Animator.",
					"The model still has to be a rig: parts joined by Motor6D, with a PrimaryPart set. Without Motor6D the Animation Editor shows no tracks at all.",
					"A common failure is unanchored parts flying apart. The rule: anchor ONLY the root part (the Part0 of the first chain); everything else must be Anchored = false or the joints cannot move them.",
					"Another trap: turn CanCollide off on moving parts, otherwise the animated model starts shoving itself around.",
				},
			},
			steps = {
				ru = {
					"Соберите модель из двух частей и соедините их Motor6D (можно кодом из примера урока 4-х).",
					"Задайте модели PrimaryPart и заякорите только корневую часть.",
					"Откройте Animation Editor с выделенной моделью и сделайте короткую анимацию.",
					"Вставьте Script из примера внутрь модели и запустите игру.",
				},
				en = {
					"Build a two-part model and join them with a Motor6D (the code sample from the rig lesson works).",
					"Set the model's PrimaryPart and anchor only the root part.",
					"Open the Animation Editor with the model selected and make a short animation.",
					"Insert the sample Script into the model and run the game.",
				},
			},
			snippet = "non-humanoid",
			practice = {
				ru = "Сделайте анимированную дверь: две части (рама и полотно), Motor6D, анимация открытия на 1.5 секунды, запуск из скрипта.",
				en = "Build an animated door: two parts (frame and panel), a Motor6D, a 1.5-second opening animation, played from a script.",
			},
			quiz = {
				question = {
					ru = "У модели дракона нет Humanoid. Куда положить Animator?",
					en = "A dragon model has no Humanoid. Where does the Animator go?",
				},
				options = {
					{ ru = "Прямо в Workspace", en = "Directly into the Workspace" },
					{ ru = "Внутрь AnimationController, который лежит в модели", en = "Inside an AnimationController parented to the model" },
					{ ru = "Внутрь любой части модели", en = "Inside any part of the model" },
					{ ru = "Animator не нужен", en = "No Animator is needed" },
				},
				answer = 2,
				explain = {
					ru = "Без Humanoid роль владельца Animator берёт на себя AnimationController.",
					en = "Without a Humanoid, the AnimationController takes over as the Animator's owner.",
				},
			},
			keywords = { "animationcontroller", "non-humanoid", "дверь", "npc", "модель", "motor6d", "anchored" },
		},

		{
			id = "3-2-tools-npc",
			module = 3,
			minutes = 13,
			title = { ru = "Инструменты и NPC", en = "Tools and NPCs" },
			goal = {
				ru = "Анимировать оружие в руках игрока и построить простую машину состояний для NPC.",
				en = "Animate a weapon in the player's hands and build a simple NPC state machine.",
			},
			theory = {
				ru = {
					"Tool анимируется не сам по себе — анимируется ПЕРСОНАЖ, который его держит. Трек грузится на Animator персонажа, а не на инструмент.",
					"Чтобы оружие двигалось вместе с рукой, оно должно быть присоединено к ней. Handle крепится через RightGrip (Roblox создаёт его автоматически) или через собственный Motor6D, если нужна полная свобода.",
					"Жизненный цикл Tool: Equipped (взяли — грузим и запускаем idle-трек), Activated (кликнули — играем удар), Unequipped (убрали — обязательно останавливаем ВСЕ треки, иначе анимация останется висеть).",
					"Idle инструмента ставьте на приоритет Idle, а атаку — на Action. Тогда атака перекроет удержание, а удержание не будет мешать ходьбе.",
					"Для NPC ключевая идея — машина состояний: одно активное состояние в каждый момент, переход только при смене.",
					"Главная ошибка новичков в NPC: вызывать track:Play() каждый кадр в цикле. Трек перезапускается непрерывно и анимация выглядит замершей. Всегда проверяйте, не играет ли уже нужный трек.",
					"Для NPC удобно подписаться на humanoid.Running (даёт скорость) и humanoid.StateChanged (прыжок, падение).",
				},
				en = {
					"A Tool is not animated by itself — you animate the CHARACTER holding it. The track is loaded onto the character's Animator, not onto the tool.",
					"For the weapon to follow the hand it must be attached to it. The Handle is welded through RightGrip (Roblox creates it automatically) or through your own Motor6D when you need full freedom.",
					"Tool lifecycle: Equipped (picked up — load and start the idle track), Activated (clicked — play the swing), Unequipped (put away — you MUST stop every track or the pose stays stuck).",
					"Put the tool idle on Idle priority and the attack on Action. Then the attack overrides the hold, and the hold does not fight locomotion.",
					"For NPCs the key idea is a state machine: exactly one active state at a time, with a transition only when it changes.",
					"The classic NPC mistake is calling track:Play() every frame in a loop. The track restarts constantly and the animation looks frozen. Always check whether the desired track is already playing.",
					"For NPCs, hook humanoid.Running (gives you the speed) and humanoid.StateChanged (jumping, falling).",
				},
			},
			steps = {
				ru = {
					"Создайте Tool с Handle и положите в StarterPack.",
					"Вставьте LocalScript из примера внутрь Tool и подставьте свои ID.",
					"Проверьте: взяли инструмент — играет idle; кликнули — играет удар; убрали — всё остановилось.",
					"Затем возьмите пример с NPC и постройте переключение idle / walk через humanoid.Running.",
				},
				en = {
					"Create a Tool with a Handle and put it in StarterPack.",
					"Insert the sample LocalScript into the Tool and set your IDs.",
					"Verify: equipping plays the idle, clicking plays the swing, unequipping stops everything.",
					"Then take the NPC sample and build idle / walk switching from humanoid.Running.",
				},
			},
			snippet = "tool-animation",
			practice = {
				ru = "Сделайте меч: idle при удержании и взмах по клику. Затем добавьте NPC, который переключается между idle и ходьбой без перезапуска трека каждый кадр.",
				en = "Build a sword: an idle while held and a swing on click. Then add an NPC that switches between idle and walking without restarting the track every frame.",
			},
			quiz = {
				question = {
					ru = "NPC играет анимацию ходьбы, но она выглядит «застывшей» на первом кадре. Причина?",
					en = "An NPC plays a walk animation but it looks frozen on the first frame. Why?",
				},
				options = {
					{ ru = "Слишком низкий приоритет", en = "The priority is too low" },
					{ ru = "Play() вызывается в цикле каждый кадр и постоянно перезапускает трек", en = "Play() is called every frame in a loop and keeps restarting the track" },
					{ ru = "Не хватает Motor6D", en = "A Motor6D is missing" },
					{ ru = "Анимация не опубликована", en = "The animation is not published" },
				},
				answer = 2,
				explain = {
					ru = "Каждый Play() начинает трек заново. В цикле это означает вечный первый кадр. Проверяйте IsPlaying или храните текущее состояние.",
					en = "Every Play() restarts the track. In a loop that means an eternal first frame. Check IsPlaying or track the current state.",
				},
			},
			keywords = { "tool", "инструмент", "оружие", "меч", "npc", "state machine", "equipped", "activated" },
		},

		{
			id = "3-3-replication",
			module = 3,
			minutes = 11,
			title = { ru = "Репликация: кто и что видит", en = "Replication: who sees what" },
			goal = {
				ru = "Сделать так, чтобы анимацию видели все игроки, и не открыть дыру в безопасности.",
				en = "Make every player see the animation without opening a security hole.",
			},
			theory = {
				ru = {
					"Главное правило: если клиент проигрывает анимацию через Animator СВОЕГО персонажа, Roblox сам реплицирует её всем остальным. Ничего пересылать вручную не нужно.",
					"Именно поэтому анимации игрока правильно запускать в LocalScript: получается мгновенный отклик без задержки сети.",
					"Если запустить ту же анимацию на сервере, отклик у самого игрока будет с задержкой пинга. Для действий игрока это ощущается хуже.",
					"Для NPC — наоборот. Персонажем NPC владеет сервер, поэтому его анимации нужно запускать серверным скриптом, иначе их увидит только один клиент.",
					"Опасная ошибка новичков: RemoteEvent, который принимает от клиента AnimationId и играет что угодно. Эксплойтер отправит любой ID. Никогда не принимайте идентификатор анимации от клиента — сервер должен сам знать список допустимых анимаций.",
					"Правильная схема боя: клиент играет анимацию локально (мгновенно) и сообщает серверу «я атаковал». Сервер проверяет кулдаун и дистанцию и уже сам применяет урон.",
					"Обязательно ставьте на сервере ограничение частоты (rate limit). Без него клиент может слать событие сотни раз в секунду.",
				},
				en = {
					"The core rule: when a client plays an animation through ITS OWN character's Animator, Roblox replicates it to everyone else automatically. There is nothing to forward by hand.",
					"That is exactly why player animations belong in a LocalScript: you get instant response with no network delay.",
					"Play the same animation on the server and the acting player feels a ping-sized lag. For player actions that is strictly worse.",
					"For NPCs it is the opposite. The server owns the NPC's character, so its animations must be started by a server script or only one client will see them.",
					"A dangerous beginner mistake: a RemoteEvent that accepts an AnimationId from the client and plays whatever it is given. An exploiter will send any ID. Never accept an animation identifier from the client — the server must own the list of allowed animations.",
					"The correct combat pattern: the client plays the animation locally (instant) and tells the server 'I attacked'. The server validates cooldown and distance and applies the damage itself.",
					"Always rate limit on the server. Without it a client can fire the event hundreds of times per second.",
				},
			},
			steps = {
				ru = {
					"Вставьте пример этого урока: LocalScript играет анимацию, RemoteEvent сообщает серверу.",
					"Запустите тест на двух игроках (Test → Players: 2) и убедитесь, что второй игрок видит анимацию.",
					"Добавьте на сервере проверку кулдауна через os.clock().",
					"Убедитесь, что сервер НЕ получает AnimationId от клиента.",
				},
				en = {
					"Insert this lesson's sample: a LocalScript plays the animation, a RemoteEvent notifies the server.",
					"Run a two-player test (Test → Players: 2) and confirm the second player sees it.",
					"Add a server-side cooldown check with os.clock().",
					"Confirm the server never receives an AnimationId from the client.",
				},
			},
			snippet = "replicated-attack",
			practice = {
				ru = "Реализуйте атаку: клиент играет анимацию, сервер валидирует кулдаун 0.8 с и наносит урон. Проверьте на двух игроках.",
				en = "Implement an attack: the client plays the animation, the server validates a 0.8 s cooldown and applies damage. Test it with two players.",
			},
			quiz = {
				question = {
					ru = "Игрок видит свою анимацию, а другие игроки — нет. Что скорее всего не так?",
					en = "A player sees their own animation but nobody else does. What is most likely wrong?",
				},
				options = {
					{ ru = "Анимация проигрывается на Animator постороннего объекта, а не персонажа игрока", en = "The animation plays on some other object's Animator, not the player's character" },
					{ ru = "Слишком высокий приоритет", en = "The priority is too high" },
					{ ru = "Не задан Looped", en = "Looped is not set" },
					{ ru = "Анимация слишком длинная", en = "The animation is too long" },
				},
				answer = 1,
				explain = {
					ru = "Автоматически реплицируется только то, что клиент играет на Animator своего собственного персонажа. Локальные объекты и чужие модели не реплицируются.",
					en = "Only what a client plays on its own character's Animator replicates automatically. Local objects and other people's models do not.",
				},
			},
			keywords = { "replication", "репликация", "server", "client", "сервер", "клиент", "remoteevent", "exploit", "безопасность" },
		},

		--==================================================================
		-- MODULE 4
		--==================================================================

		{
			id = "4-1-ik",
			module = 4,
			minutes = 13,
			title = { ru = "Инверсная кинематика (IKControl)", en = "Inverse kinematics (IKControl)" },
			goal = {
				ru = "Заставить руку тянуться к предмету, а ноги — вставать на неровности.",
				en = "Make a hand reach an object and feet adapt to uneven ground.",
			},
			theory = {
				ru = {
					"Обычная (прямая) кинематика: вы задаёте угол плеча, потом локтя, потом кисти. Инверсная — наоборот: вы говорите «кисть должна быть ВОТ ЗДЕСЬ», а движок сам считает углы плеча и локтя.",
					"В Roblox для этого есть объект IKControl. Он кладётся внутрь Humanoid (или AnimationController) и работает поверх обычной анимации.",
					"Четыре обязательных свойства: Type (обычно Position или Transform), EndEffector (часть, которая тянется, например LeftHand), Target (куда тянется — любой объект с позицией, чаще Attachment), ChainRoot (где начинается цепочка суставов, например LeftUpperArm).",
					"ChainRoot определяет, сколько суставов участвует. LeftUpperArm — работает всё плечо с локтем; LeftLowerArm — только предплечье.",
					"Свойство Weight (0..1) позволяет плавно включать и выключать IK. Резкое включение с Weight = 1 выглядит как рывок; лучше нарастить его через TweenService.",
					"Без ограничений локоть может выгибаться в обратную сторону. Чтобы этого не было, добавляют HingeConstraint на локоть и BallSocketConstraint на кисть. Условие: аттачменты констрейнта должны совпадать по частям и по позициям с C0/C1 соответствующего Motor6D, а сам констрейнт должен лежать в той же модели.",
					"Типичные применения: руки на руле, ступни на лестнице и склоне, взгляд и рука, тянущаяся к движущейся цели.",
				},
				en = {
					"Forward kinematics: you set the shoulder angle, then the elbow, then the wrist. Inverse kinematics is the reverse: you say 'the hand must be HERE' and the engine solves the shoulder and elbow angles.",
					"Roblox provides the IKControl object for this. It is parented to the Humanoid (or AnimationController) and works on top of the regular animation.",
					"Four required properties: Type (usually Position or Transform), EndEffector (the part that reaches, e.g. LeftHand), Target (what it reaches for — any object with a world position, usually an Attachment) and ChainRoot (where the joint chain starts, e.g. LeftUpperArm).",
					"ChainRoot decides how many joints participate. LeftUpperArm involves the whole shoulder and elbow; LeftLowerArm only the forearm.",
					"The Weight property (0..1) lets you fade IK in and out. Snapping straight to Weight = 1 looks like a jolt; ramp it with TweenService instead.",
					"Without constraints an elbow can bend backwards. To prevent that, add a HingeConstraint at the elbow and a BallSocketConstraint at the wrist. The requirement: the constraint's attachments must sit on the same parts and at the same relative positions as the corresponding Motor6D C0/C1, and the constraint must share the model.",
					"Typical uses: hands on a steering wheel, feet on stairs and slopes, and a hand tracking a moving target.",
				},
			},
			steps = {
				ru = {
					"Запустите игру, найдите свою модель в Workspace и добавьте Attachment в HumanoidRootPart.",
					"Сдвиньте аттачмент вперёд от персонажа инструментом Move.",
					"Добавьте IKControl в Humanoid и заполните Type = Transform, EndEffector = LeftHand, Target = ваш Attachment, ChainRoot = LeftUpperArm.",
					"Двигайте аттачмент и наблюдайте, как рука следует за ним.",
					"Затем вставьте код этого урока, чтобы делать то же самое автоматически.",
				},
				en = {
					"Start a playtest, find your character model in the Workspace and add an Attachment to the HumanoidRootPart.",
					"Move the attachment in front of the character with the Move tool.",
					"Add an IKControl to the Humanoid and set Type = Transform, EndEffector = LeftHand, Target = your Attachment, ChainRoot = LeftUpperArm.",
					"Drag the attachment and watch the arm follow.",
					"Then insert this lesson's code to do the same automatically.",
				},
			},
			snippet = "ik-control",
			practice = {
				ru = "Сделайте так, чтобы левая рука персонажа всегда тянулась к движущейся части. Добавьте плавное включение IK через Weight от 0 до 1 за 0.3 секунды.",
				en = "Make the character's left hand always reach a moving part. Fade the IK in via Weight from 0 to 1 over 0.3 seconds.",
			},
			quiz = {
				question = {
					ru = "Какое свойство IKControl определяет, СКОЛЬКО суставов участвует в решении?",
					en = "Which IKControl property decides HOW MANY joints take part in the solve?",
				},
				options = {
					{ ru = "Target", en = "Target" },
					{ ru = "EndEffector", en = "EndEffector" },
					{ ru = "ChainRoot", en = "ChainRoot" },
					{ ru = "Weight", en = "Weight" },
				},
				answer = 3,
				explain = {
					ru = "ChainRoot задаёт начало цепочки. Все суставы между ChainRoot и EndEffector попадают под управление IK.",
					en = "ChainRoot sets the start of the chain. Every joint between ChainRoot and EndEffector is controlled by the IK solve.",
				},
			},
			keywords = { "ik", "ikcontrol", "инверсная кинематика", "endeffector", "chainroot", "constraint", "hingeconstraint" },
		},

		{
			id = "4-2-procedural",
			module = 4,
			minutes = 12,
			title = { ru = "Процедурная анимация поверх ключевых кадров", en = "Procedural animation on top of keyframes" },
			goal = {
				ru = "Добавлять живые детали кодом: поворот головы, покачивание, отдачу.",
				en = "Add living detail in code: head turning, sway, recoil.",
			},
			theory = {
				ru = {
					"Не всё стоит рисовать руками. Поворот головы за камерой, наклон в повороте, отдача оружия, дыхание — это функции от состояния игры, и их дешевле считать кодом.",
					"Механизм один: свойство Transform у Motor6D. Аниматор пишет туда позу каждый кадр, а вы можете дописать своё смещение ПОВЕРХ, если делаете это после расчёта анимации.",
					"Ключевой момент — порядок. Пишите в Transform внутри RunService.RenderStepped (клиент) или PreSimulation/Stepped, и умножайте на текущее значение: neck.Transform = myOffset * neck.Transform. Так вы добавляете смещение, а не стираете анимацию.",
					"Если присвоить neck.Transform = CFrame.Angles(...) без умножения, вы затрёте анимацию для этого сустава целиком. Иногда это именно то, что нужно, но чаще — нет.",
					"Всегда ограничивайте углы через math.clamp. Голова, повёрнутая на 180 градусов, ломает иллюзию мгновенно.",
					"Для плавности не ставьте целевое значение сразу — интерполируйте: current = current:Lerp(target, 0.2). Это дешёвый способ получить инерцию.",
					"У Animator есть свойство EvaluationThrottled: когда движок пропускает расчёт анимации для дальних персонажей, ваш процедурный код будет бороться с устаревшей позой. Проверяйте его и пропускайте кадр.",
					"Процедурная анимация — клиентская задача. Считать её на сервере для каждого игрока дорого и почти всегда не нужно.",
				},
				en = {
					"Not everything deserves hand-keyed animation. Head tracking, lean into turns, weapon recoil, breathing — these are functions of game state and are cheaper to compute.",
					"There is one mechanism: the Motor6D Transform property. The animator writes a pose there every frame, and you can add your own offset ON TOP as long as you do it after animation evaluation.",
					"Order is what matters. Write to Transform inside RunService.RenderStepped (client) or PreSimulation/Stepped, and multiply by the current value: neck.Transform = myOffset * neck.Transform. That adds an offset instead of erasing the animation.",
					"Assigning neck.Transform = CFrame.Angles(...) without multiplying wipes the animation for that joint entirely. Occasionally that is what you want, but usually not.",
					"Always clamp your angles with math.clamp. A head rotated 180 degrees destroys the illusion instantly.",
					"For smoothness do not jump to the target value — interpolate: current = current:Lerp(target, 0.2). It is a cheap way to get inertia.",
					"The Animator exposes EvaluationThrottled: when the engine skips animation evaluation for distant characters, your procedural code would fight a stale pose. Check it and skip the frame.",
					"Procedural animation is a client-side job. Computing it on the server for every player is expensive and almost never necessary.",
				},
			},
			steps = {
				ru = {
					"Вставьте пример этого урока в StarterCharacterScripts.",
					"Запустите игру и подвигайте камерой вверх-вниз — голова следует за ней.",
					"Замените присваивание на умножение и обратно, чтобы увидеть разницу с работающей анимацией.",
					"Добавьте math.clamp и Lerp для плавности.",
				},
				en = {
					"Insert this lesson's sample into StarterCharacterScripts.",
					"Run the game and move the camera up and down — the head follows.",
					"Switch between assignment and multiplication to see the difference against a playing animation.",
					"Add math.clamp and Lerp for smoothness.",
				},
			},
			snippet = "procedural-lookat",
			practice = {
				ru = "Сделайте поворот головы за камерой с ограничением ±40° по вертикали и ±60° по горизонтали, с плавным Lerp, работающий одновременно с анимацией ходьбы.",
				en = "Build camera head tracking clamped to ±40° vertically and ±60° horizontally, smoothed with Lerp, working alongside a walk animation.",
			},
			quiz = {
				question = {
					ru = "Вы пишете neck.Transform = CFrame.Angles(x, 0, 0) в RenderStepped, и анимация шеи из ключевых кадров пропадает. Как это исправить?",
					en = "You write neck.Transform = CFrame.Angles(x, 0, 0) in RenderStepped and the keyframed neck animation disappears. How do you fix it?",
				},
				options = {
					{ ru = "Уменьшить угол", en = "Reduce the angle" },
					{ ru = "Умножать на текущее значение: CFrame.Angles(x,0,0) * neck.Transform", en = "Multiply by the current value: CFrame.Angles(x,0,0) * neck.Transform" },
					{ ru = "Перенести код на сервер", en = "Move the code to the server" },
					{ ru = "Повысить приоритет анимации", en = "Raise the animation priority" },
				},
				answer = 2,
				explain = {
					ru = "Присваивание затирает позу, вычисленную аниматором. Умножение накладывает ваше смещение поверх неё.",
					en = "Assignment overwrites the pose the animator computed. Multiplication layers your offset on top of it.",
				},
			},
			keywords = { "procedural", "процедурная", "transform", "runservice", "renderstepped", "lerp", "поворот головы" },
		},

		{
			id = "4-3-optimization",
			module = 4,
			minutes = 11,
			title = { ru = "Оптимизация и отладка", en = "Optimization and debugging" },
			goal = {
				ru = "Убрать рывки, утечки треков и лаги на толпе персонажей; уметь искать причину.",
				en = "Remove hitches, track leaks and crowd lag; know how to find the cause.",
			},
			theory = {
				ru = {
					"Утечка треков — проблема №1. Каждый вызов LoadAnimation создаёт новый AnimationTrack. Если делать это в обработчике клика или в цикле, за минуту накопятся сотни треков. Загружайте один раз, храните в таблице.",
					"Рывок при первом проигрывании — ассет ещё не скачан. Лечится предзагрузкой: создайте объекты Animation заранее, вызовите animator:LoadAnimation() при старте и передайте список в ContentProvider:PreloadAsync().",
					"На толпе NPC движок сам снижает частоту расчёта дальних персонажей (LOD). Управляется свойством Animator.PreferLodEnabled (по умолчанию true) и настройкой Workspace.ClientAnimatorThrottlingMode. Отключайте LOD только для важных NPC — массовое отключение убивает производительность.",
					"Не держите десятки треков в состоянии Play с нулевым весом: они всё равно вычисляются. Останавливайте ненужные через Stop().",
					"Чек-лист «анимация не играет»: 1) track.Length == 0 → ассет не загрузился, проверьте ID и владельца; 2) играет, но не видно → приоритет ниже, чем у стандартных анимаций; 3) видно только вам → вы играете не на Animator своего персонажа; 4) замерла на первом кадре → Play() вызывается в цикле; 5) исчезла после смерти → нужен новый трек на новом Animator.",
					"Инструменты диагностики: animator:GetPlayingAnimationTracks() покажет всё, что сейчас активно (включая затухающие); animator:GetTrackByAnimationId(id) найдёт трек по ID без создания нового.",
					"Оборачивайте LoadAnimation в pcall, если ID приходит из данных: неверный ассет иначе уронит скрипт.",
					"В Studio полезны Microprofiler (F6) и вкладка Performance: секция Animation покажет реальную стоимость расчёта поз.",
				},
				en = {
					"Track leaks are problem number one. Every LoadAnimation call creates a new AnimationTrack. Do it inside a click handler or a loop and you accumulate hundreds within a minute. Load once and keep them in a table.",
					"A hitch on first play means the asset is not downloaded yet. Fix it with preloading: create the Animation objects up front, call animator:LoadAnimation() at startup and pass the list to ContentProvider:PreloadAsync().",
					"With crowds of NPCs the engine throttles evaluation for distant characters (LOD). It is governed by Animator.PreferLodEnabled (true by default) and Workspace.ClientAnimatorThrottlingMode. Disable LOD only for important NPCs — turning it off en masse destroys performance.",
					"Do not keep dozens of tracks playing at zero weight: they are still evaluated. Stop the ones you do not need.",
					"The 'animation is not playing' checklist: 1) track.Length == 0 → the asset did not load, check the ID and owner; 2) plays but is invisible → its priority is below the default animations; 3) only you see it → you are not playing on your own character's Animator; 4) frozen on frame one → Play() is being called in a loop; 5) gone after dying → you need a fresh track on the new Animator.",
					"Diagnostic tools: animator:GetPlayingAnimationTracks() lists everything currently active (including fading tracks); animator:GetTrackByAnimationId(id) finds a track by ID without creating a new one.",
					"Wrap LoadAnimation in pcall when the ID comes from data: a bad asset would otherwise kill the script.",
					"In Studio the Microprofiler (F6) and the Performance tab help: the Animation section shows the real cost of pose evaluation.",
				},
			},
			steps = {
				ru = {
					"Вставьте диагностический скрипт из этого урока и запустите с заведомо неверным ID — изучите вывод.",
					"Подставьте верный ID и сравните.",
					"Добавьте ContentProvider:PreloadAsync и убедитесь, что первый Play больше не дёргается.",
					"Выведите animator:GetPlayingAnimationTracks() во время игры и посмотрите, не копятся ли треки.",
				},
				en = {
					"Insert the diagnostic script from this lesson and run it with a deliberately wrong ID — study the output.",
					"Swap in the correct ID and compare.",
					"Add ContentProvider:PreloadAsync and confirm the first Play no longer hitches.",
					"Print animator:GetPlayingAnimationTracks() during play and check that tracks are not piling up.",
				},
			},
			snippet = "debug-checklist",
			practice = {
				ru = "Найдите в своём проекте место, где LoadAnimation вызывается больше одного раза для одной анимации, и перепишите его на кэш треков в таблице.",
				en = "Find a place in your project where LoadAnimation runs more than once for the same animation and rewrite it to cache tracks in a table.",
			},
			quiz = {
				question = {
					ru = "Игра начинает лагать после нескольких минут боя. В коде LoadAnimation вызывается внутри обработчика клика. В чём проблема?",
					en = "The game starts lagging after a few minutes of combat. LoadAnimation is called inside the click handler. What is wrong?",
				},
				options = {
					{ ru = "Анимация слишком длинная", en = "The animation is too long" },
					{ ru = "На каждый клик создаётся новый трек — они накапливаются", en = "Every click creates a new track — they accumulate" },
					{ ru = "Нужно повысить приоритет", en = "The priority needs raising" },
					{ ru = "Нужно отключить Looped", en = "Looped should be disabled" },
				},
				answer = 2,
				explain = {
					ru = "LoadAnimation должен вызываться один раз при инициализации. Внутри обработчика он плодит треки, которые продолжают вычисляться.",
					en = "LoadAnimation belongs in initialization. Inside a handler it spawns tracks that keep being evaluated.",
				},
			},
			keywords = { "оптимизация", "optimization", "preload", "lag", "лаг", "утечка", "leak", "microprofiler", "debug", "отладка" },
		},

		{
			id = "4-4-pipeline",
			module = 4,
			minutes = 10,
			title = { ru = "Внешние инструменты и рабочий процесс", en = "External tools and workflow" },
			goal = {
				ru = "Понимать, когда хватит встроенного редактора, а когда нужны Blender, Moon Animator или mocap.",
				en = "Know when the built-in editor is enough and when to reach for Blender, Moon Animator or mocap.",
			},
			theory = {
				ru = {
					"Встроенный Animation Editor полностью закрывает большинство задач: idle, ходьба, атаки, эмоции. Начинать всегда стоит с него — не нужно усложнять.",
					"Moon Animator — популярный сторонний плагин. Его сильные стороны: анимация нескольких персонажей и объектов в одной сцене, работа с камерой, более удобный график-редактор. Логика та же: на выходе получается обычный ассет анимации с ID.",
					"Blender нужен, когда вы работаете со скиннированными мешами (skinned mesh) — моделями с костями (Bone) и мягкой деформацией вместо жёстких частей. Пайплайн: риг и анимация в Blender → экспорт FBX → импорт в Studio через Avatar → 3D Importer / Import Animation.",
					"При импорте FBX важно совпадение имён костей и масштаба. Roblox использует свою систему единиц, поэтому масштаб почти всегда приходится проверять вручную.",
					"Skinned mesh отличается от обычного рига: там Bone вместо Motor6D, и деформация плавная. Для органики (существа, ткань) это единственный нормальный путь.",
					"Animation Capture (вкладка Avatar) позволяет записать движение лица или тела через веб-камеру прямо в Studio. Быстро для черновика и мимики, но результат почти всегда требует ручной чистки ключей.",
					"Практический совет по процессу: сначала блокинг (грубые ключевые позы с Constant easing), потом тайминг (двигаете ключи), и только потом полировка (easing, кривые, детали). Полировать до того, как утверждён тайминг, — это выброшенное время.",
					"Держите библиотеку: папка в ServerStorage или ModuleScript с таблицей всех ID анимаций. Разбросанные по коду rbxassetid — гарантированная боль при обновлении.",
				},
				en = {
					"The built-in Animation Editor covers most of what you need: idles, walks, attacks, emotes. Always start there — do not over-engineer.",
					"Moon Animator is a popular third-party plugin. Its strengths: animating several characters and props in one scene, camera work and a nicer graph editor. The logic is the same: the output is an ordinary animation asset with an ID.",
					"Blender becomes necessary for skinned meshes — models with Bones and soft deformation instead of rigid parts. The pipeline: rig and animate in Blender → export FBX → import into Studio via Avatar → 3D Importer / Import Animation.",
					"When importing FBX, bone names and scale must line up. Roblox uses its own unit system, so scale nearly always needs a manual check.",
					"A skinned mesh differs from a part rig: it uses Bone instead of Motor6D and deforms smoothly. For organic subjects (creatures, cloth) it is the only sane route.",
					"Animation Capture (the Avatar tab) records face or body motion from a webcam directly in Studio. It is fast for blocking and facial work, but the result almost always needs manual key cleanup.",
					"Process advice: block first (rough key poses with Constant easing), then time it (slide the keys), and only then polish (easing, curves, detail). Polishing before the timing is approved is wasted work.",
					"Keep a library: a folder in ServerStorage or a ModuleScript holding a table of every animation ID. rbxassetid strings scattered through your code guarantee pain later.",
				},
			},
			steps = {
				ru = {
					"Создайте ModuleScript в ReplicatedStorage с таблицей ID всех ваших анимаций.",
					"Перепишите один из прошлых скриптов так, чтобы он брал ID оттуда.",
					"Откройте Avatar → Animation Capture и попробуйте записать мимику (если есть камера).",
					"Если работаете с мешами — попробуйте импортировать простой FBX через 3D Importer.",
				},
				en = {
					"Create a ModuleScript in ReplicatedStorage holding a table of all your animation IDs.",
					"Rewrite one of your earlier scripts to read IDs from it.",
					"Open Avatar → Animation Capture and try recording facial motion (if you have a camera).",
					"If you work with meshes, try importing a simple FBX through the 3D Importer.",
				},
			},
			practice = {
				ru = "Создайте ModuleScript AnimationIds с таблицей вида { Idle = \"rbxassetid://...\", Attack = ... } и переведите на него все свои скрипты из курса.",
				en = "Create an AnimationIds ModuleScript with a table like { Idle = \"rbxassetid://...\", Attack = ... } and migrate every script from the course to use it.",
			},
			quiz = {
				question = {
					ru = "Вам нужно анимировать существо с плавной деформацией тела, а не набор жёстких частей. Что использовать?",
					en = "You need to animate a creature with smooth body deformation rather than rigid parts. What do you use?",
				},
				options = {
					{ ru = "Motor6D и встроенный редактор", en = "Motor6D and the built-in editor" },
					{ ru = "Skinned mesh с костями (Bone), сделанный в Blender", en = "A skinned mesh with Bones, authored in Blender" },
					{ ru = "IKControl", en = "IKControl" },
					{ ru = "Animation Events", en = "Animation Events" },
				},
				answer = 2,
				explain = {
					ru = "Плавная деформация — это скиннинг. Нужны кости (Bone) и меш, подготовленный во внешнем редакторе, обычно в Blender.",
					en = "Smooth deformation means skinning. That requires Bones and a mesh prepared in an external tool, usually Blender.",
				},
			},
			keywords = { "blender", "moon animator", "fbx", "импорт", "skinned mesh", "bone", "mocap", "capture", "пайплайн" },
		},
	}

	Lessons.byId = {}
	for index, lesson in ipairs(Lessons.list) do
		lesson.index = index
		Lessons.byId[lesson.id] = lesson
	end

	function Lessons.get(id)
		return Lessons.byId[id]
	end

	function Lessons.count()
		return #Lessons.list
	end

	function Lessons.inModule(moduleId)
		local out = {}
		for _, lesson in ipairs(Lessons.list) do
			if lesson.module == moduleId then
				out[#out + 1] = lesson
			end
		end
		return out
	end

	function Lessons.next(id)
		local lesson = Lessons.byId[id]
		if not lesson then
			return Lessons.list[1]
		end
		return Lessons.list[lesson.index + 1]
	end

	return Lessons
end

__modules["Data.Snippets"] = function()
	--[[
		Data/Snippets
		Ready-to-use Luau code samples the tutor can insert into the place.
		Every snippet is written against the current (non-deprecated) API:
		  * Animator:LoadAnimation  (NOT Humanoid:LoadAnimation)
		  * task.wait               (NOT wait)
		Each entry declares where it is meant to live so the tutor can explain
		placement and the inserter can pick a sane parent.
	]]

	local Snippets = {}

	Snippets.list = {

		{
			id = "play-basic",
			title = { ru = "Проиграть анимацию на персонаже", en = "Play an animation on a character" },
			placement = { ru = "LocalScript в StarterPlayer → StarterPlayerScripts", en = "LocalScript in StarterPlayer → StarterPlayerScripts" },
			className = "LocalScript",
			parent = "StarterPlayerScripts",
			code = [[
	local Players = game:GetService("Players")

	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()

	-- 1. Humanoid always owns an Animator; wait for both.
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	-- 2. An Animation instance is just a pointer to an uploaded asset.
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://0" -- <- paste your published ID here

	-- 3. Loading returns an AnimationTrack: the playable, controllable object.
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false

	-- 4. Play it.
	track:Play()
	]],
		},

		{
			id = "play-on-key",
			title = { ru = "Анимация по нажатию клавиши", en = "Play an animation on a key press" },
			placement = { ru = "LocalScript в StarterPlayerScripts", en = "LocalScript in StarterPlayerScripts" },
			className = "LocalScript",
			parent = "StarterPlayerScripts",
			code = [[
	local Players = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")

	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://0"

	-- Load ONCE, outside the input handler. Loading on every press leaks tracks.
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return -- the player was typing in chat
		end
		if input.KeyCode == Enum.KeyCode.E then
			if track.IsPlaying then
				track:Stop(0.15)
			else
				track:Play(0.15)
			end
		end
	end)
	]],
		},

		{
			id = "reload-on-respawn",
			title = { ru = "Перезагрузка треков после респавна", en = "Reload tracks after respawn" },
			placement = { ru = "LocalScript в StarterPlayerScripts", en = "LocalScript in StarterPlayerScripts" },
			className = "LocalScript",
			parent = "StarterPlayerScripts",
			code = [[
	local Players = game:GetService("Players")

	local player = Players.LocalPlayer

	local ANIMATION_ID = "rbxassetid://0"

	local currentTrack = nil

	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid")
		local animator = humanoid:WaitForChild("Animator")

		local animation = Instance.new("Animation")
		animation.AnimationId = ANIMATION_ID

		-- A new character means a new Animator, so old tracks are dead.
		currentTrack = animator:LoadAnimation(animation)
		currentTrack.Priority = Enum.AnimationPriority.Action
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	]],
		},

		{
			id = "events-markers",
			title = { ru = "События анимации (маркеры)", en = "Animation events (markers)" },
			placement = { ru = "LocalScript в StarterPlayerScripts", en = "LocalScript in StarterPlayerScripts" },
			className = "LocalScript",
			parent = "StarterPlayerScripts",
			code = [[
	local Players = game:GetService("Players")

	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://0"

	local track = animator:LoadAnimation(animation)

	-- The marker name must match the event you added in the Animation Editor.
	track:GetMarkerReachedSignal("FootStep"):Connect(function(paramString)
		print("footstep, parameter =", paramString)
	end)

	track:GetMarkerReachedSignal("HitFrame"):Connect(function()
		print("this is the exact frame the punch should deal damage")
	end)

	track:Play()
	]],
		},

		{
			id = "track-lifecycle",
			title = { ru = "Жизненный цикл трека: Play/Stop/Ended", en = "Track lifecycle: Play/Stop/Ended" },
			placement = { ru = "LocalScript", en = "LocalScript" },
			className = "LocalScript",
			parent = "StarterPlayerScripts",
			code = [[
	local track = nil -- assume it was loaded earlier

	-- Play(fadeTime, weight, speed)
	track:Play(0.1, 1, 1)

	-- Change playback live.
	track:AdjustSpeed(1.5)      -- 1.5x faster; 0 pauses; negative plays backwards
	track:AdjustWeight(0.5, 0.2) -- blend at half strength over 0.2s

	-- Useful state.
	print(track.IsPlaying, track.Length, track.TimePosition, track.Speed)

	-- Fires when the track finishes or is stopped, after the fade-out.
	track.Ended:Connect(function()
		print("finished")
	end)

	-- Fires each time a looped track wraps around.
	track.DidLoop:Connect(function()
		print("looped")
	end)

	-- Wait for a one-shot animation to finish.
	track.Stopped:Wait()

	track:Stop(0.25) -- always give a fade unless you need a hard cut
	]],
		},

		{
			id = "non-humanoid",
			title = { ru = "Анимация модели без Humanoid", en = "Animate a rig without a Humanoid" },
			placement = { ru = "Script внутри самой модели", en = "Script inside the model itself" },
			className = "Script",
			parent = "Workspace",
			code = [[
	local rig = script.Parent

	-- No Humanoid? Then YOU create the controller that owns the Animator.
	local animationController = rig:FindFirstChildOfClass("AnimationController")
	if not animationController then
		animationController = Instance.new("AnimationController")
		animationController.Parent = rig
	end

	local animator = animationController:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = animationController
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://0"

	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track:Play()
	]],
		},

		{
			id = "replace-default",
			title = { ru = "Заменить стандартные анимации персонажа", en = "Replace the default character animations" },
			placement = { ru = "Script в ServerScriptService", en = "Script in ServerScriptService" },
			className = "Script",
			parent = "ServerScriptService",
			code = [[
	local Players = game:GetService("Players")

	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid")
		local animator = humanoid:WaitForChild("Animator")

		-- Stop whatever the default Animate script already started.
		for _, playingTrack in animator:GetPlayingAnimationTracks() do
			playingTrack:Stop(0)
		end

		local animateScript = character:WaitForChild("Animate")
		-- Uncomment and fill in only the ones you actually replace.
		-- animateScript.run.RunAnim.AnimationId = "rbxassetid://0"
		-- animateScript.walk.WalkAnim.AnimationId = "rbxassetid://0"
		-- animateScript.idle.Animation1.AnimationId = "rbxassetid://0"
		-- animateScript.idle.Animation2.AnimationId = "rbxassetid://0"
		-- animateScript.jump.JumpAnim.AnimationId = "rbxassetid://0"
		-- animateScript.fall.FallAnim.AnimationId = "rbxassetid://0"
		-- animateScript.climb.ClimbAnim.AnimationId = "rbxassetid://0"
		-- animateScript.swim.Swim.AnimationId = "rbxassetid://0"
		-- animateScript.swimidle.SwimIdle.AnimationId = "rbxassetid://0"
	end

	local function onPlayerAdded(player)
		player.CharacterAppearanceLoaded:Connect(onCharacterAdded)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	]],
		},

		{
			id = "replicated-attack",
			title = { ru = "Правильная репликация: клиент играет, сервер решает", en = "Correct replication: client plays, server decides" },
			placement = { ru = "LocalScript + Script + RemoteEvent", en = "LocalScript + Script + RemoteEvent" },
			className = "LocalScript",
			parent = "StarterPlayerScripts",
			-- Level-1 long string: the sample itself contains a --[[ ]] block.
			code = [==[
	-- ============ LocalScript (StarterPlayerScripts) ============
	-- Playing on the client through the character's own Animator replicates
	-- to everyone automatically. Do NOT send the animation over a RemoteEvent.
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://0"
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action

	local attackRemote = ReplicatedStorage:WaitForChild("AttackRemote")

	local function attack()
		track:Play()
		-- Tell the server what happened; the server validates and applies damage.
		attackRemote:FireServer()
	end

	-- ============ Script (ServerScriptService) ============
	--[[
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local attackRemote = Instance.new("RemoteEvent")
	attackRemote.Name = "AttackRemote"
	attackRemote.Parent = ReplicatedStorage

	local cooldowns = {}

	attackRemote.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if cooldowns[player] and now - cooldowns[player] < 0.8 then
			return -- rate limit: never trust the client
		end
		cooldowns[player] = now
		-- apply damage / hit detection here
	end)
	]]
	]==],
		},

		{
			id = "blend-weights",
			title = { ru = "Смешивание анимаций через вес", en = "Blending animations with weight" },
			placement = { ru = "LocalScript", en = "LocalScript" },
			className = "LocalScript",
			parent = "StarterPlayerScripts",
			code = [[
	-- Two tracks at the SAME priority blend by weight.
	-- The visible pose is the weighted average of all playing poses.
	local walkTrack, runTrack = nil, nil -- assume both are loaded

	walkTrack.Priority = Enum.AnimationPriority.Movement
	runTrack.Priority = Enum.AnimationPriority.Movement

	walkTrack:Play()
	runTrack:Play()

	-- alpha 0 = pure walk, 1 = pure run
	local function setBlend(alpha)
		alpha = math.clamp(alpha, 0, 1)
		walkTrack:AdjustWeight(1 - alpha, 0.1)
		runTrack:AdjustWeight(alpha, 0.1)
	end

	-- Drive the blend from actual speed.
	local humanoid = nil -- assume it exists
	game:GetService("RunService").RenderStepped:Connect(function()
		local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
		setBlend(speed / 24)
	end)
	]],
		},

		{
			id = "procedural-lookat",
			title = { ru = "Процедурная анимация: поворот головы", en = "Procedural animation: head look-at" },
			placement = { ru = "LocalScript в StarterCharacterScripts", en = "LocalScript in StarterCharacterScripts" },
			className = "LocalScript",
			parent = "StarterCharacterScripts",
			code = [[
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")

	local player = Players.LocalPlayer
	local character = script.Parent
	local humanoid = character:WaitForChild("Humanoid")
	local torso = character:WaitForChild("UpperTorso")  -- R15
	local neck = torso:WaitForChild("Neck")             -- Motor6D

	local camera = workspace.CurrentCamera

	-- Motor6D.Transform is applied ON TOP of the animation pose every frame.
	-- Writing to it in a Stepped/RenderStepped binding layers procedural motion
	-- over keyframed animation instead of fighting it.
	RunService.RenderStepped:Connect(function()
		local lookVector = camera.CFrame.LookVector
		local pitch = math.asin(math.clamp(lookVector.Y, -1, 1))
		-- Limit the rotation so the neck does not break.
		pitch = math.clamp(pitch, math.rad(-40), math.rad(40))
		neck.Transform = CFrame.Angles(pitch, 0, 0)
	end)
	]],
		},

		{
			id = "preload",
			title = { ru = "Предзагрузка анимаций (без рывка)", en = "Preload animations (no first-play hitch)" },
			placement = { ru = "LocalScript", en = "LocalScript" },
			className = "LocalScript",
			parent = "StarterPlayerScripts",
			code = [[
	local ContentProvider = game:GetService("ContentProvider")
	local Players = game:GetService("Players")

	local ANIMATION_IDS = {
		"rbxassetid://0",
		"rbxassetid://0",
	}

	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	local tracks = {}
	local animations = {}

	for index, id in ANIMATION_IDS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		animations[index] = animation
		-- Load early: the first Play() is what normally stutters.
		tracks[index] = animator:LoadAnimation(animation)
	end

	-- Fetch the asset data before gameplay starts.
	ContentProvider:PreloadAsync(animations)
	print("animations ready")
	]],
		},

		{
			id = "ik-control",
			title = { ru = "IKControl: рука тянется к цели", en = "IKControl: hand reaches a target" },
			placement = { ru = "Script в ServerScriptService или LocalScript", en = "Script in ServerScriptService or a LocalScript" },
			className = "Script",
			parent = "ServerScriptService",
			code = [[
	local Players = game:GetService("Players")

	local function setupReach(character)
		local humanoid = character:WaitForChild("Humanoid")
		local rootPart = character:WaitForChild("HumanoidRootPart")

		-- The thing the hand should reach for.
		local targetAttachment = Instance.new("Attachment")
		targetAttachment.Name = "ReachTarget"
		targetAttachment.Position = Vector3.new(2, 1, -3)
		targetAttachment.Parent = rootPart

		local ikControl = Instance.new("IKControl")
		ikControl.Type = Enum.IKControlType.Transform
		ikControl.EndEffector = character:WaitForChild("LeftHand")
		ikControl.ChainRoot = character:WaitForChild("LeftUpperArm")
		ikControl.Target = targetAttachment
		ikControl.Weight = 1 -- 0..1, ramp this for a smooth blend in/out
		ikControl.Parent = humanoid
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(setupReach)
	end)
	]],
		},

		{
			id = "tool-animation",
			title = { ru = "Анимация инструмента (Tool)", en = "Animating a Tool" },
			placement = { ru = "LocalScript внутри Tool", en = "LocalScript inside the Tool" },
			className = "LocalScript",
			parent = "Tool",
			code = [[
	local tool = script.Parent
	local Players = game:GetService("Players")

	local player = Players.LocalPlayer

	local idleAnimation = Instance.new("Animation")
	idleAnimation.AnimationId = "rbxassetid://0"

	local swingAnimation = Instance.new("Animation")
	swingAnimation.AnimationId = "rbxassetid://0"

	local idleTrack, swingTrack

	tool.Equipped:Connect(function()
		local character = player.Character
		local humanoid = character:WaitForChild("Humanoid")
		local animator = humanoid:WaitForChild("Animator")

		idleTrack = animator:LoadAnimation(idleAnimation)
		idleTrack.Priority = Enum.AnimationPriority.Idle
		idleTrack.Looped = true
		idleTrack:Play(0.2)

		swingTrack = animator:LoadAnimation(swingAnimation)
		swingTrack.Priority = Enum.AnimationPriority.Action
	end)

	tool.Unequipped:Connect(function()
		if idleTrack then
			idleTrack:Stop(0.2)
		end
		if swingTrack then
			swingTrack:Stop(0.1)
		end
	end)

	tool.Activated:Connect(function()
		if swingTrack then
			swingTrack:Play(0.05)
		end
	end)
	]],
		},

		{
			id = "npc-state",
			title = { ru = "NPC: переключение idle / walk", en = "NPC: switching idle / walk" },
			placement = { ru = "Script внутри модели NPC", en = "Script inside the NPC model" },
			className = "Script",
			parent = "Workspace",
			code = [[
	local npc = script.Parent
	local humanoid = npc:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	local function loadTrack(id, priority, looped)
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local track = animator:LoadAnimation(animation)
		track.Priority = priority
		track.Looped = looped
		return track
	end

	local idleTrack = loadTrack("rbxassetid://0", Enum.AnimationPriority.Idle, true)
	local walkTrack = loadTrack("rbxassetid://0", Enum.AnimationPriority.Movement, true)

	local current = nil

	local function switchTo(track)
		if current == track then
			return -- already playing: restarting every frame looks broken
		end
		if current then
			current:Stop(0.2)
		end
		current = track
		track:Play(0.2)
	end

	humanoid.Running:Connect(function(speed)
		if speed > 0.1 then
			switchTo(walkTrack)
		else
			switchTo(idleTrack)
		end
	end)

	switchTo(idleTrack)
	]],
		},

		{
			id = "build-rig-motor6d",
			title = { ru = "Собрать простой риг из Motor6D", en = "Build a simple rig out of Motor6D" },
			placement = { ru = "Script в ServerScriptService (запустить один раз)", en = "Script in ServerScriptService (run once)" },
			className = "Script",
			parent = "ServerScriptService",
			code = [[
	-- A rig is just parts connected by Motor6D joints.
	-- Part0 = parent bone, Part1 = the part that moves.
	local model = Instance.new("Model")
	model.Name = "SimpleRig"

	local function makePart(name, size, cframe)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = cframe
		part.Anchored = false
		part.CanCollide = false
		part.Parent = model
		return part
	end

	local base = makePart("Base", Vector3.new(2, 2, 2), CFrame.new(0, 5, 0))
	local arm = makePart("Arm", Vector3.new(1, 3, 1), CFrame.new(0, 7.5, 0))

	base.Anchored = true
	model.PrimaryPart = base

	local motor = Instance.new("Motor6D")
	motor.Name = "ArmJoint"
	motor.Part0 = base
	motor.Part1 = arm
	-- C0/C1 define where the joint sits relative to each part.
	motor.C0 = CFrame.new(0, 1, 0)
	motor.C1 = CFrame.new(0, -1.5, 0)
	motor.Parent = base

	model.Parent = workspace
	print("Rig built. Select the model and open the Animation Editor.")
	]],
		},

		{
			id = "debug-checklist",
			title = { ru = "Диагностика: почему анимация не играет", en = "Debug: why the animation is not playing" },
			placement = { ru = "LocalScript, временно", en = "LocalScript, temporary" },
			className = "LocalScript",
			parent = "StarterPlayerScripts",
			code = [[
	local Players = game:GetService("Players")

	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	local ANIMATION_ID = "rbxassetid://0"

	local animation = Instance.new("Animation")
	animation.AnimationId = ANIMATION_ID

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not ok then
		warn("LoadAnimation failed:", track)
		warn("Usually: the ID is wrong, or the animation is owned by another account/group.")
		return
	end

	print("Length:", track.Length)
	if track.Length == 0 then
		warn("Length is 0 -> the asset did not load. Check the ID and its owner.")
	end

	track.Priority = Enum.AnimationPriority.Action
	track:Play()

	task.wait(0.1)
	print("IsPlaying:", track.IsPlaying, "Weight:", track.WeightCurrent)

	for _, playing in animator:GetPlayingAnimationTracks() do
		print("playing:", playing.Animation and playing.Animation.AnimationId, playing.Priority)
	end
	]],
		},
	}

	Snippets.byId = {}
	for _, snippet in ipairs(Snippets.list) do
		Snippets.byId[snippet.id] = snippet
	end

	function Snippets.get(id)
		return Snippets.byId[id]
	end

	return Snippets
end

__modules["Data.Strings"] = function()
	--[[
		Data/Strings
		All UI text, in Russian and English. Nothing user-visible should be
		hardcoded anywhere else in the plugin.
	]]

	local Strings = {}

	Strings.languages = { "ru", "en" }

	Strings.data = {
		ru = {
			languageName = "Русский",
			pluginTitle = "ИИ-Учитель Анимации",
			toolbarName = "AnimTeacher",
			buttonTitle = "Учитель анимации",
			buttonTooltip = "Открыть ИИ-учителя по анимации Roblox",

			tabCourse = "Курс",
			tabChat = "Вопрос",
			tabProgress = "Прогресс",

			greetingTitle = "Привет! Я научу вас анимации в Roblox.",
			greetingBody = "Слева — курс из 17 уроков: от первого рига до IK и оптимизации. Не знаете, с чего начать — нажмите «Продолжить обучение». Есть конкретный вопрос — вкладка «Вопрос», спрашивайте своими словами по-русски или по-английски.",

			continueLearning = "Продолжить обучение",
			startCourse = "Начать курс",
			lessonList = "Все уроки",
			back = "Назад",
			nextLesson = "Следующий урок",
			markDone = "Отметить пройденным",
			markedDone = "Урок пройден",
			reopen = "Пройти заново",

			sectionGoal = "Цель урока",
			sectionTheory = "Теория",
			sectionSteps = "Что делать в Studio",
			sectionPractice = "Задание",
			sectionQuiz = "Проверь себя",
			sectionCode = "Пример кода",

			insertCode = "Вставить код в игру",
			copyHint = "Код вставлен: ",
			checkWork = "Проверить мою работу",

			quizCorrect = "Верно!",
			quizWrong = "Не совсем.",
			quizTryAgain = "Попробуйте ещё раз",

			askPlaceholder = "Спросите про анимацию…",
			askButton = "Спросить",
			thinking = "Думаю…",
			relatedLesson = "Связанный урок: ",
			alsoSee = "Смотрите также:",
			openLesson = "Открыть урок",

			fallbackTitle = "Не понял вопрос",
			fallbackBody = "Я знаю только про анимацию в Roblox Studio. Попробуйте спросить конкретнее: «почему анимация не работает», «как проиграть анимацию скриптом», «что такое приоритет», «как смешать анимации», «как сделать IK».",

			progressTitle = "Ваш прогресс",
			progressLessons = "Пройдено уроков",
			progressQuiz = "Правильных ответов в тестах",
			progressModule = "Модуль",
			resetProgress = "Сбросить прогресс",
			resetConfirm = "Нажмите ещё раз, чтобы подтвердить",
			notStarted = "не начат",
			inProgress = "в процессе",
			completed = "пройден",

			minutes = "мин",
			lesson = "Урок",
			of = "из",

			checkPass = "Отлично! ",
			checkFail = "Пока нет. ",
			checkRigFound = "Нашёл риг в Workspace с суставами Motor6D.",
			checkRigMissing = "В Workspace нет модели с Motor6D. Вставьте риг: вкладка Avatar → Rig Builder.",
			checkScriptFound = "Нашёл скрипт, который использует Animator:LoadAnimation.",
			checkScriptMissing = "Не нашёл скрипт с Animator:LoadAnimation. Создайте LocalScript в StarterPlayerScripts и вставьте пример кода.",
			checkDeprecated = "Внимание: найден устаревший вызов Humanoid:LoadAnimation. Замените на Animator:LoadAnimation.",

			languageToggle = "English",
		},

		en = {
			languageName = "English",
			pluginTitle = "AI Animation Teacher",
			toolbarName = "AnimTeacher",
			buttonTitle = "Animation Teacher",
			buttonTooltip = "Open the AI Roblox animation tutor",

			tabCourse = "Course",
			tabChat = "Ask",
			tabProgress = "Progress",

			greetingTitle = "Hi! I will teach you animation in Roblox.",
			greetingBody = "On the left is a 17-lesson course: from your first rig to IK and optimization. Not sure where to start? Press \"Continue learning\". Got a specific question? Use the \"Ask\" tab and write in your own words, in English or Russian.",

			continueLearning = "Continue learning",
			startCourse = "Start the course",
			lessonList = "All lessons",
			back = "Back",
			nextLesson = "Next lesson",
			markDone = "Mark as done",
			markedDone = "Lesson completed",
			reopen = "Study again",

			sectionGoal = "Goal",
			sectionTheory = "Theory",
			sectionSteps = "Do this in Studio",
			sectionPractice = "Exercise",
			sectionQuiz = "Check yourself",
			sectionCode = "Code sample",

			insertCode = "Insert code into the place",
			copyHint = "Code inserted: ",
			checkWork = "Check my work",

			quizCorrect = "Correct!",
			quizWrong = "Not quite.",
			quizTryAgain = "Try again",

			askPlaceholder = "Ask about animation…",
			askButton = "Ask",
			thinking = "Thinking…",
			relatedLesson = "Related lesson: ",
			alsoSee = "See also:",
			openLesson = "Open lesson",

			fallbackTitle = "I did not get that",
			fallbackBody = "I only know Roblox Studio animation. Try something more specific: \"why is my animation not working\", \"how to play an animation from a script\", \"what is priority\", \"how to blend animations\", \"how does IK work\".",

			progressTitle = "Your progress",
			progressLessons = "Lessons completed",
			progressQuiz = "Correct quiz answers",
			progressModule = "Module",
			resetProgress = "Reset progress",
			resetConfirm = "Click again to confirm",
			notStarted = "not started",
			inProgress = "in progress",
			completed = "completed",

			minutes = "min",
			lesson = "Lesson",
			of = "of",

			checkPass = "Nice! ",
			checkFail = "Not yet. ",
			checkRigFound = "Found a rig in the Workspace with Motor6D joints.",
			checkRigMissing = "No model with Motor6D in the Workspace. Insert a rig: Avatar tab → Rig Builder.",
			checkScriptFound = "Found a script using Animator:LoadAnimation.",
			checkScriptMissing = "No script with Animator:LoadAnimation found. Create a LocalScript in StarterPlayerScripts and insert the code sample.",
			checkDeprecated = "Heads up: found a deprecated Humanoid:LoadAnimation call. Switch it to Animator:LoadAnimation.",

			languageToggle = "Русский",
		},
	}

	function Strings.get(language)
		return Strings.data[language] or Strings.data.en
	end

	function Strings.other(language)
		return language == "ru" and "en" or "ru"
	end

	return Strings
end

__modules["UI.App"] = function()
	--[[
		UI/App
		The whole plugin interface: three tabs (Course / Ask / Progress), lesson
		rendering, quizzes, code insertion and "check my work".

		Everything Roblox-specific that the logic modules need is gathered here and
		passed down, so Brain/* and Core/* stay testable.
	]]

	local Theme = __require("UI.Theme")
	local Components = __require("UI.Components")
	local Lessons = __require("Data.Lessons")
	local Snippets = __require("Data.Snippets")
	local Strings = __require("Data.Strings")
	local Answer = __require("Brain.Answer")
	local Checks = __require("Brain.Checks")

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
end

__modules["UI.Components"] = function()
	--[[
		UI/Components
		Small factory helpers for the Instance-based UI.
		Keeping creation in one place keeps the view files readable and makes
		restyling a one-line change.
	]]

	local Theme = __require("UI.Theme")

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
end

__modules["UI.Theme"] = function()
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
end

return __require("Main")
