--[[ Tests for Core/Progress and Brain/Checks. ]]

local Progress = _require("Core.Progress")
local Checks = _require("Brain.Checks")
local Lessons = _require("Data.Lessons")
local H = (function()
	local f = io.open(ROOT_DIR .. "/tests/helpers.lua", "r")
	local src = f:read("*a")
	f:close()
	return load(src, "@helpers.lua")()
end)()

----------------------------------------------------------------------
-- a fake plugin settings store
----------------------------------------------------------------------
local function fakeStore()
	local data = {}
	return {
		get = function(key)
			return data[key]
		end,
		set = function(key, value)
			data[key] = value
		end,
		_data = data,
	}
end

H.section("Progress: defaults")
local store = fakeStore()
local p = Progress.new(store)
H.equal(p:completedCount(), 0, "starts with nothing completed")
H.equal(p:overallPercent(), 0, "0 percent")
H.equal(p:getLanguage(), "ru", "defaults to Russian")
H.equal(p:nextLesson().id, Lessons.list[1].id, "next lesson is the first one")

H.section("Progress: completing lessons")
p:setCompleted(Lessons.list[1].id, true)
H.ok(p:isCompleted(Lessons.list[1].id), "lesson marked complete")
H.equal(p:completedCount(), 1, "count is 1")
H.equal(p:nextLesson().id, Lessons.list[2].id, "next lesson advances past completed")
p:setCompleted(Lessons.list[1].id, false)
H.equal(p:completedCount(), 0, "un-marking works")

H.section("Progress: current lesson takes priority when unfinished")
p:setCurrentLesson(Lessons.list[5].id)
H.equal(p:nextLesson().id, Lessons.list[5].id, "resumes the current lesson")
p:setCompleted(Lessons.list[5].id, true)
H.equal(p:nextLesson().id, Lessons.list[1].id, "falls back to first incomplete")

H.section("Progress: quizzes")
p:setQuizResult("1-1-what-is-animation", true)
p:setQuizResult("1-2-editor-tour", false)
H.equal(p:correctQuizCount(), 1, "counts only correct answers")
H.equal(p:quizResult("1-2-editor-tour"), "wrong", "stores wrong answers too")

H.section("Progress: module status")
-- Start from a clean slate: earlier sections completed lessons in module 1.
p:reset()
local status = p:moduleStatus(1)
H.equal(status.total, #Lessons.inModule(1), "module total matches")
H.equal(status.state, "notStarted", "module 1 not started yet")
p:setCompleted(Lessons.inModule(1)[1].id, true)
H.equal(p:moduleStatus(1).state, "inProgress", "module 1 in progress after one lesson")
for _, lesson in ipairs(Lessons.inModule(1)) do
	p:setCompleted(lesson.id, true)
end
H.equal(p:moduleStatus(1).state, "completed", "module completes")

H.section("Progress: persistence across instances")
local reloaded = Progress.new(store)
H.ok(reloaded:isCompleted(Lessons.inModule(1)[1].id), "state survives a reload")
reloaded:setLanguage("en")
H.equal(Progress.new(store):getLanguage(), "en", "language persists")

H.section("Progress: reset")
reloaded:reset()
H.equal(reloaded:completedCount(), 0, "reset clears lessons")
H.equal(reloaded:correctQuizCount(), 0, "reset clears quizzes")

----------------------------------------------------------------------
-- fake Roblox instances for Checks
----------------------------------------------------------------------
local function makeInstance(className, name, children, source)
	local inst
	inst = {
		ClassName = className,
		Name = name,
		Source = source,
		Children = children or {},
		IsA = function(self, query)
			if self.ClassName == query then
				return true
			end
			-- minimal inheritance the checks rely on
			if query == "LuaSourceContainer" then
				return self.ClassName == "Script"
					or self.ClassName == "LocalScript"
					or self.ClassName == "ModuleScript"
			end
			return false
		end,
		GetDescendants = function(self)
			local out = {}
			local function walk(node)
				for _, child in ipairs(node.Children) do
					out[#out + 1] = child
					walk(child)
				end
			end
			walk(self)
			return out
		end,
	}
	for _, child in ipairs(inst.Children) do
		child.Parent = inst
	end
	return inst
end

H.section("Checks: rig detection")
local emptyWorkspace = makeInstance("Workspace", "Workspace", {})
local emptyEnv = { workspace = emptyWorkspace }
local rigResult = Checks.run("rig-in-workspace", emptyEnv)
H.equal(rigResult.passed, false, "no rig -> fails")
H.equal(rigResult.messageKey, "checkRigMissing", "reports the missing rig")

local torso = makeInstance("Part", "UpperTorso", {
	makeInstance("Motor6D", "Neck"),
	makeInstance("Motor6D", "LeftShoulder"),
})
local rigModel = makeInstance("Model", "Dummy", { torso })
local rigEnv = { workspace = makeInstance("Workspace", "Workspace", { rigModel }) }
local rigOk = Checks.run("rig-in-workspace", rigEnv)
H.equal(rigOk.passed, true, "rig with Motor6D -> passes")
H.equal(rigOk.count, 2, "counts the joints")

H.section("Checks: script detection")
local modernSource = [[
local animator = humanoid:WaitForChild("Animator")
local track = animator:LoadAnimation(animation)
track:Play()
]]
local deprecatedSource = [[
local track = humanoid:LoadAnimation(animation)
track:Play()
]]

local noScriptEnv = {
	workspace = makeInstance("Workspace", "Workspace", {}),
	starterPlayerScripts = makeInstance("Folder", "StarterPlayerScripts", {}),
}
H.equal(Checks.run("localscript-with-animator", noScriptEnv).passed, false, "no script -> fails")

local modernEnv = {
	workspace = makeInstance("Workspace", "Workspace", {}),
	starterPlayerScripts = makeInstance("Folder", "StarterPlayerScripts", {
		makeInstance("LocalScript", "PlayAnim", {}, modernSource),
	}),
}
local modernResult = Checks.run("localscript-with-animator", modernEnv)
H.equal(modernResult.passed, true, "modern Animator call -> passes")
H.equal(modernResult.extraKey, nil, "no deprecation warning")

local deprecatedEnv = {
	workspace = makeInstance("Workspace", "Workspace", {}),
	starterPlayerScripts = makeInstance("Folder", "StarterPlayerScripts", {
		makeInstance("LocalScript", "OldAnim", {}, deprecatedSource),
	}),
}
local deprecatedResult = Checks.run("localscript-with-animator", deprecatedEnv)
H.equal(deprecatedResult.passed, false, "deprecated-only call does not pass")
H.equal(deprecatedResult.extraKey, "checkDeprecated", "warns about the deprecated API")

H.section("Checks: registry")
H.equal(Checks.run("does-not-exist", emptyEnv), nil, "unknown check returns nil")
H.ok(Checks.exists("rig-in-workspace"), "exists() works")

H.section("Checks: every lesson check id is implemented")
local allImplemented = true
for _, lesson in ipairs(Lessons.list) do
	if lesson.check and not Checks.exists(lesson.check) then
		print("       lesson " .. lesson.id .. " wants missing check " .. lesson.check)
		allImplemented = false
	end
end
H.ok(allImplemented, "no lesson references a missing check")

return H.summary()
