--[[
	Плавный цикл смены дня и ночи.

	Куда вставить: ServerScriptService (обычный Script)
	Настройка: DAY_LENGTH_SECONDS — длительность полных суток
	в реальном времени (по умолчанию 10 минут).

	Стандартное освещение Roblox само подстраивает небо,
	солнце и луну под Lighting.ClockTime.
]]

local Lighting = game:GetService("Lighting")

local DAY_LENGTH_SECONDS = 600 -- 10 минут = игровые сутки

local clockTime = Lighting.ClockTime

while true do
	local dt = task.wait(0.1)
	-- за сутки (24 часа) стрелка должна пройти полный круг
	clockTime = (clockTime + dt * (24 / DAY_LENGTH_SECONDS)) % 24
	Lighting.ClockTime = clockTime
end
