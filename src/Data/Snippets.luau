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
