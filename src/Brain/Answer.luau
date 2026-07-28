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

local Text = require(script.Parent.Text)
local Knowledge = require(script.Parent.Parent.Data.Knowledge)
local Lessons = require(script.Parent.Parent.Data.Lessons)

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
