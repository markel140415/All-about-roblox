--[[
	leaderstats — классическая таблица лидеров с монетами.

	Куда вставить: ServerScriptService (обычный Script)
	Результат: у каждого игрока появляется статистика "Coins",
	видимая всем в списке игроков (клавиша Tab в игре).

	Совет: чтобы монеты сохранялись между сессиями,
	см. раздел про DataStoreService в docs/04-skripting-v-roblox.md
]]

local Players = game:GetService("Players")

local STARTING_COINS = 0 -- сколько монет выдавать новичку

local function onPlayerAdded(player: Player)
	-- папка обязана называться именно "leaderstats"
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = STARTING_COINS
	coins.Parent = leaderstats

	-- пример: +10 монет каждые 60 секунд
	task.spawn(function()
		while player.Parent do
			task.wait(60)
			coins.Value += 10
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
