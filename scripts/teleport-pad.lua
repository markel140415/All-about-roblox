--[[
	Телепорт-площадки: stepped на одну — переносит на другую, и обратно.

	Куда вставить: ServerScriptService (обычный Script)
	Подготовка: создайте в Workspace две Part с именами
	"TeleportA" и "TeleportB" (Anchor'нутые).

	Совет: сделайте площадки яркими (Neon) и добавьте
	Part.CFrame + Vector3.new(0, 3, 0), чтобы игрок
	не застревал внутри площадки после телепортации.
]]

local Players = game:GetService("Players")

local padA = workspace:WaitForChild("TeleportA")
local padB = workspace:WaitForChild("TeleportB")

local COOLDOWN = 2 -- сек между телепортациями одного игрока
local cooldowns = {}

local function setupTeleport(from: BasePart, to: BasePart)
	from.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local now = os.clock()
		if cooldowns[player] and now - cooldowns[player] < COOLDOWN then return end
		cooldowns[player] = now

		-- переносим чуть выше площадки, чтобы не застрять
		root.CFrame = to.CFrame + Vector3.new(0, 3, 0)
	end)
end

setupTeleport(padA, padB)
setupTeleport(padB, padA)
