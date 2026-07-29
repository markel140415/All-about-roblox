--[[
	Сбор монет при касании.

	Куда вставить: ServerScriptService (обычный Script)
	Подготовка: создайте в Workspace папку с именем "Coins"
	и положите в неё Part'ы (например, золотые цилиндры).
	Части могут быть любыми BasePart — имя не важно.

	Зависит от leaderstats.lua: начисляет +1 в значение "Coins".
]]

local Players = game:GetService("Players")

local coinsFolder = workspace:WaitForChild("Coins")

local COOLDOWN = 0.5      -- защита от многократного срабатывания, сек
local COIN_VALUE = 1      -- сколько монет даёт одна монета
local RESPAWN_TIME = 10   -- через сколько секунд монета появится снова; 0 = исчезает навсегда

local lastTouch = {}

local function giveCoins(player: Player, amount: number)
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins then
		coins.Value += amount
	end
end

local function onCoinTouched(coin: BasePart)
	local originalParent = coin.Parent

	coin.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then return end

		local now = os.clock()
		if lastTouch[player] and now - lastTouch[player] < COOLDOWN then return end
		lastTouch[player] = now

		giveCoins(player, COIN_VALUE)

		-- монета исчезает
		coin.Parent = nil

		if RESPAWN_TIME > 0 then
			task.delay(RESPAWN_TIME, function()
				coin.Parent = originalParent
			end)
		end
	end)
end

for _, coin in ipairs(coinsFolder:GetChildren()) do
	if coin:IsA("BasePart") then
		coin.CanCollide = false -- чтобы об монету не спотыкались
		onCoinTouched(coin)
	end
end
