--[[
	Core/Progress
	Tracks which lessons are finished and which quizzes were answered.

	Persistence goes through plugin:SetSetting/GetSetting, but the module never
	touches the Plugin object directly: it receives a tiny `store` interface
	({ get = function(key), set = function(key, value) }). That keeps the logic
	unit testable and makes the Studio dependency explicit.
]]

local Lessons = require(script.Parent.Parent.Data.Lessons)

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
