# 4. Скриптинг в Roblox

В Roblox код выполняется на **сервере** и на **клиенте** у каждого игрока. Понимание этой границы — ключ ко всему скриптингу.

## 🎭 Три вида скриптов

| Тип | Где выполняется | Где создаётся | Для чего |
|-----|-----------------|---------------|----------|
| **Script** | На сервере | ServerScriptService, Workspace, ServerStorage | Логика игры, данные, безопасность |
| **LocalScript** | На клиенте игрока | StarterPlayerScripts, StarterCharacterScripts, GUI | Ввод, камера, интерфейс, эффекты |
| **ModuleScript** | Там, где его вызвали | Где угодно | Переиспользуемый код («библиотеки») |

> 🔒 **Золотое правило:** никогда не доверяйте клиенту. Проверку урона, валюты, покупок всегда делайте на сервере — клиент можно взломать.

## 🔍 Как находить объекты

```lua
-- доступ к сервисам — через GetService
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- поиск объектов
local part = workspace:WaitForChild("MyPart")          -- ждёт появления
local model = workspace:FindFirstChild("Monster")       -- nil, если нет
```

- `WaitForChild` — ждёт, пока объект появится (нужно при загрузке).
- `FindFirstChild` — мгновенно возвращает объект или `nil`.

## 🎪 События

Roblox работает на событиях — код реагирует на то, что происходит в мире:

```lua
local Players = game:GetService("Players")

-- игрок зашёл в игру
Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " зашёл в игру!")
end)

-- деталь кого-то коснулась
workspace.MyPart.Touched:Connect(function(hit)
	print(hit.Name .. " коснулся плиты")
end)

-- каждый кадр (для плавной анимации)
RunService.Heartbeat:Connect(function(dt)
	-- dt — время с прошлого кадра в секундах
end)
```

## 📡 Клиент ↔ Сервер: RemoteEvent

Клиент и сервер общаются через **RemoteEvent** и **RemoteFunction**. Положите RemoteEvent в **ReplicatedStorage**.

**Сервер** (Script в ServerScriptService):

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local buyEvent = ReplicatedStorage:WaitForChild("BuyItem")

buyEvent.OnServerEvent:Connect(function(player, itemName: string)
	-- ВАЖНО: проверяем всё на сервере!
	print(player.Name .. " хочет купить " .. itemName)
	-- ...проверить валюту, выдать предмет...
end)
```

**Клиент** (LocalScript):

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local buyEvent = ReplicatedStorage:WaitForChild("BuyItem")

-- первый аргумент (player) сервер получает автоматически
buyEvent:FireServer("Меч")
```

> ⚠️ **Безопасность:** клиент может отправить ЛЮБЫЕ аргументы. Всегда валидируйте их на сервере: проверяйте тип, диапазон, права игрока.

## 🧩 Главные сервисы

| Сервис | Назначение |
|--------|------------|
| `Players` | игроки: вход, выход, персонажи |
| `Workspace` | игровой мир, физика, raycast |
| `RunService` | события кадров: Heartbeat, RenderStepped |
| `TweenService` | плавная анимация свойств |
| `DataStoreService` | сохранение данных между сессиями |
| `ReplicatedStorage` | общие для клиента и сервера ресурсы |
| `MarketplaceService` | покупки за Robux, Game Pass |
| `UserInputService` | ввод: клавиатура, мышь, тач (клиент) |
| `Lighting` | освещение, небо, пост-обработка |

## 💾 Сохранение данных (DataStore)

```lua
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local store = DataStoreService:GetDataStore("PlayerCoins_v1")

local function loadCoins(player: Player): number
	local success, coins = pcall(function()
		return store:GetAsync("user_" .. player.UserId)
	end)
	if success and coins then
		return coins
	else
		warn("Не удалось загрузить данные " .. player.Name)
		return 0
	end
end

Players.PlayerAdded:Connect(function(player)
	local coins = loadCoins(player)
	print(player.Name .. ", твои монеты: " .. coins)
	-- ...положить в leaderstats...
end)
```

- Оборачивайте вызовы DataStore в `pcall` — они могут завершиться ошибкой.
- Включите **Enable Studio Access to API Services** в настройках игры, чтобы данные работали в Studio.
- Версионируйте ключи (`_v1`), чтобы не потерять данные при смене формата.

## 🎬 Пример: плавное движение через TweenService

```lua
local TweenService = game:GetService("TweenService")

local part = workspace:WaitForChild("Door")
local goal = {CFrame = part.CFrame + Vector3.new(0, 5, 0)}
local info = TweenInfo.new(
	1.5,                                -- длительность, сек
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

local tween = TweenService:Create(part, info, goal)
tween:Play()
tween.Completed:Wait()   -- дождаться окончания (если нужно)
```

➡️ Дальше: [Создание и продвижение игры](05-sozdanie-i-prodvizhenie-igry.md)
