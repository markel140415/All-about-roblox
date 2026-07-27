--[[
	Двойной прыжок.

	Куда вставить: LocalScript внутри
	StarterPlayer > StarterPlayerScripts
	(можно и в StarterCharacterScripts)

	Как работает: ловим JumpRequest от UserInputService
	(срабатывает на пробел/кнопку прыжка) и, если игрок
	в воздухе и есть запасной прыжок, запускаем прыжок вручную.
]]

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local EXTRA_JUMPS = 1 -- количество дополнительных прыжков
local extraJumpsLeft = 0

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

player.CharacterAdded:Connect(function(character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	extraJumpsLeft = EXTRA_JUMPS

	-- приземлились — пополняем запас прыжков
	humanoid.StateChanged:Connect(function(_old, new)
		if new == Enum.HumanoidStateType.Landed then
			extraJumpsLeft = EXTRA_JUMPS
		end
	end)
end)

UserInputService.JumpRequest:Connect(function()
	local humanoid = getHumanoid()
	if not humanoid then return end

	if humanoid:GetState() == Enum.HumanoidStateType.Freefall and extraJumpsLeft > 0 then
		extraJumpsLeft -= 1
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)
