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
