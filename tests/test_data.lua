--[[
	Data integrity tests.
	Bad course data is worse than a bug: it teaches the wrong thing.
	These tests check structure, bilingual completeness, cross references
	and that no sample code uses deprecated APIs.
]]

local Lessons = _require("Data.Lessons")
local Knowledge = _require("Data.Knowledge")
local Snippets = _require("Data.Snippets")
local H = (function()
	local f = io.open(ROOT_DIR .. "/tests/helpers.lua", "r")
	local src = f:read("*a")
	f:close()
	return load(src, "@helpers.lua")()
end)()

local LANGS = { "ru", "en" }

local function bilingual(value)
	if type(value) ~= "table" then
		return false
	end
	for _, lang in ipairs(LANGS) do
		local v = value[lang]
		if v == nil then
			return false
		end
		if type(v) == "string" and #v == 0 then
			return false
		end
		if type(v) == "table" and #v == 0 then
			return false
		end
	end
	return true
end

H.section("Lessons: structure")
H.ok(#Lessons.list >= 14, "at least 14 lessons (" .. #Lessons.list .. ")")
H.equal(#Lessons.modules, 4, "4 modules")

local seenIds = {}
local structureOk = true
local bilingualOk = true
local quizOk = true
for _, lesson in ipairs(Lessons.list) do
	if seenIds[lesson.id] then
		print("       duplicate lesson id: " .. lesson.id)
		structureOk = false
	end
	seenIds[lesson.id] = true

	if type(lesson.module) ~= "number" or lesson.module < 1 or lesson.module > 4 then
		print("       bad module on " .. lesson.id)
		structureOk = false
	end
	if type(lesson.minutes) ~= "number" or lesson.minutes <= 0 then
		print("       bad minutes on " .. lesson.id)
		structureOk = false
	end

	for _, field in ipairs({ "title", "goal", "theory", "steps", "practice" }) do
		if not bilingual(lesson[field]) then
			print("       " .. lesson.id .. " missing bilingual " .. field)
			bilingualOk = false
		end
	end

	local quiz = lesson.quiz
	if not quiz then
		print("       " .. lesson.id .. " has no quiz")
		quizOk = false
	else
		if not bilingual(quiz.question) or not bilingual(quiz.explain) then
			print("       " .. lesson.id .. " quiz not bilingual")
			quizOk = false
		end
		if #quiz.options ~= 4 then
			print("       " .. lesson.id .. " quiz needs 4 options, has " .. #quiz.options)
			quizOk = false
		end
		for _, option in ipairs(quiz.options) do
			if not bilingual(option) then
				print("       " .. lesson.id .. " quiz option not bilingual")
				quizOk = false
			end
		end
		if type(quiz.answer) ~= "number" or quiz.answer < 1 or quiz.answer > #quiz.options then
			print("       " .. lesson.id .. " quiz answer out of range")
			quizOk = false
		end
	end
end
H.ok(structureOk, "lesson ids and fields are well formed")
H.ok(bilingualOk, "every lesson is fully bilingual")
H.ok(quizOk, "every quiz has 4 bilingual options and a valid answer")

H.section("Lessons: every module is populated")
for _, moduleInfo in ipairs(Lessons.modules) do
	local inModule = Lessons.inModule(moduleInfo.id)
	H.ok(#inModule >= 3, "module " .. moduleInfo.id .. " has " .. #inModule .. " lessons")
	H.ok(bilingual(moduleInfo.title), "module " .. moduleInfo.id .. " title bilingual")
end

H.section("Lessons: navigation")
H.equal(Lessons.next(Lessons.list[1].id).id, Lessons.list[2].id, "next() advances")
H.equal(Lessons.next(Lessons.list[#Lessons.list].id), nil, "next() ends at the last lesson")
H.equal(Lessons.get("2-1-animator-track").module, 2, "get() by id")

H.section("Snippets: referenced ids all exist")
local snippetRefsOk = true
for _, lesson in ipairs(Lessons.list) do
	if lesson.snippet and not Snippets.get(lesson.snippet) then
		print("       lesson " .. lesson.id .. " references missing snippet " .. lesson.snippet)
		snippetRefsOk = false
	end
end
for _, entry in ipairs(Knowledge.entries) do
	if entry.snippet and not Snippets.get(entry.snippet) then
		print("       kb " .. entry.id .. " references missing snippet " .. entry.snippet)
		snippetRefsOk = false
	end
	if entry.lesson and not Lessons.get(entry.lesson) then
		print("       kb " .. entry.id .. " references missing lesson " .. entry.lesson)
		snippetRefsOk = false
	end
end
H.ok(snippetRefsOk, "all snippet/lesson cross references resolve")

H.section("Snippets: no deprecated APIs in taught code")
local deprecated = {
	"humanoid:LoadAnimation",
	"Humanoid:LoadAnimation",
	"animationController:LoadAnimation",
	"AnimationController:LoadAnimation",
}
local cleanCode = true
for _, snippet in ipairs(Snippets.list) do
	for _, bad in ipairs(deprecated) do
		if string.find(snippet.code, bad, 1, true) then
			print("       snippet " .. snippet.id .. " uses deprecated " .. bad)
			cleanCode = false
		end
	end
	-- Bare wait() is discouraged in favour of task.wait().
	if string.find(snippet.code, "[^.%w]wait%s*%(") then
		print("       snippet " .. snippet.id .. " uses bare wait()")
		cleanCode = false
	end
end
H.ok(cleanCode, "no deprecated calls in any snippet")

H.section("Snippets: metadata is complete")
local metaOk = true
for _, snippet in ipairs(Snippets.list) do
	if not bilingual(snippet.title) or not bilingual(snippet.placement) then
		print("       snippet " .. snippet.id .. " metadata not bilingual")
		metaOk = false
	end
	if type(snippet.code) ~= "string" or #snippet.code < 40 then
		print("       snippet " .. snippet.id .. " code too short")
		metaOk = false
	end
	if type(snippet.className) ~= "string" then
		print("       snippet " .. snippet.id .. " has no className")
		metaOk = false
	end
end
H.ok(metaOk, "every snippet has bilingual metadata and real code")
H.ok(#Snippets.list >= 12, "at least 12 snippets (" .. #Snippets.list .. ")")

H.section("Knowledge: structure")
local kbOk = true
local kbSeen = {}
for _, entry in ipairs(Knowledge.entries) do
	if kbSeen[entry.id] then
		print("       duplicate kb id: " .. entry.id)
		kbOk = false
	end
	kbSeen[entry.id] = true
	if not bilingual(entry.title) or not bilingual(entry.answer) then
		print("       kb " .. entry.id .. " not bilingual")
		kbOk = false
	end
	if #(entry.concepts or {}) == 0 then
		print("       kb " .. entry.id .. " has no concepts")
		kbOk = false
	end
end
H.ok(kbOk, "knowledge entries are well formed")
H.ok(#Knowledge.entries >= 15, "at least 15 KB entries (" .. #Knowledge.entries .. ")")

H.section("Knowledge: answers are substantial")
local substantial = true
for _, entry in ipairs(Knowledge.entries) do
	for _, lang in ipairs(LANGS) do
		if #entry.answer[lang] < 3 then
			print("       kb " .. entry.id .. " " .. lang .. " answer has < 3 paragraphs")
			substantial = false
		end
	end
end
H.ok(substantial, "every answer has at least 3 paragraphs in both languages")

return H.summary()
