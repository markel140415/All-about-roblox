# 3. Основы Luau

**Luau** — язык программирования Roblox. Это быстрая, обратно совместимая и доработанная версия Lua 5.1 с gradual typing, улучшенными таблицами и удобным синтаксисом.

## 👋 Первая программа

Создайте скрипт и напишите:

```lua
print("Привет, Roblox!")
```

Сообщение появится в окне **Output**.

## 📦 Переменные

```lua
local playerName = "Игрок"   -- строка
local coins = 100            -- число
local isAlive = true         -- булево значение
local target = nil           -- «ничего»
```

- `local` создаёт локальную переменную — **всегда используйте `local`**, это быстрее и безопаснее.
- Константы по соглашению пишут ЗАГЛАВНЫМИ_БУКВАМИ: `local MAX_SPEED = 32`.

## 🔤 Типы данных

| Тип | Пример |
|-----|--------|
| `number` | `42`, `3.14` |
| `string` | `"привет"` |
| `boolean` | `true` / `false` |
| `nil` | отсутствие значения |
| `table` | массивы и словари |
| объекты Roblox | `Instance`, `Vector3`, `CFrame`, `Color3`, `Enum`… |

## ➕ Операции

```lua
local a = 10
local b = 3

print(a + b)      -- 13
print(a - b)      -- 7
print(a * b)      -- 30
print(a / b)      -- 3.333...
print(a // b)     -- 3   (целочисленное деление)
print(a % b)      -- 1   (остаток)
print(a ^ b)      -- 1000
print(a == b)     -- false
print(a ~= b)     -- true (не равно)
print(a >= b)     -- true

-- составные операторы (фишка Luau)
a += 5   -- a = a + 5
a -= 2
a *= 2
```

Строки объединяются оператором `..`:

```lua
print("Монет: " .. coins)
```

## 🔀 Условия

```lua
local hp = 35

if hp <= 0 then
	print("Игрок погиб")
elseif hp < 50 then
	print("Мало здоровья!")
else
	print("Всё в порядке")
end
```

## 🔁 Циклы

```lua
-- счётчик от 1 до 5
for i = 1, 5 do
	print("Итерация " .. i)
end

-- по всем детям объекта
for _, child in ipairs(workspace:GetChildren()) do
	print(child.Name)
end

-- while
local n = 0
while n < 3 do
	n += 1
	print(n)
end

-- бесконечный цикл с паузой (часто нужен в играх)
while true do
	print("тик")
	task.wait(1)
end
```

> 💡 `task.wait(секунды)` — «правильная» пауза в Roblox. Старый `wait()` тоже работает, но `task.*` точнее и современнее.

## 📋 Таблицы (массивы и словари)

```lua
-- массив
local inventory = {"меч", "щит", "зелье"}
print(inventory[1])            -- "меч" (нумерация с 1!)
table.insert(inventory, "лук")
table.remove(inventory, 1)

-- словарь
local playerData = {
	name = "Игрок",
	level = 12,
	isPremium = true,
}
print(playerData.name)         -- "Игрок"
playerData.level += 1

-- обход словаря
for key, value in playerData do
	print(key, "=", value)
end
```

## 🛠️ Функции

```lua
local function add(a, b)
	return a + b
end

print(add(2, 3)) -- 5

-- типизированная версия (рекомендуется)
local function multiply(a: number, b: number): number
	return a * b
end
```

## 🏷️ Аннотации типов

Luau умеет проверять типы — это ловит ошибки до запуска игры:

```lua
local coins: number = 100
local name: string = "Игрок"
local parts: {BasePart} = {}   -- массив деталей

local function greet(who: string): string
	return "Привет, " .. who .. "!"
end
```

Включите строгую проверку в настройках скрипта: `--!strict` в первой строке.

## 🧙 Мета-таблицы и ООП

Объектно-ориентированное программирование в Luau строится на мета-таблицах:

```lua
local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(name: string, hp: number)
	local self = setmetatable({}, Enemy)
	self.name = name
	self.hp = hp
	return self
end

function Enemy:takeDamage(amount: number)
	self.hp -= amount
	print(self.name .. " получает " .. amount .. " урона, осталось " .. self.hp)
end

local goblin = Enemy.new("Гоблин", 50)
goblin:takeDamage(20)
```

## ⚠️ Частые ошибки новичков

1. **Нумерация массивов с 1**, а не с 0.
2. Забытое `local` создаёт глобальную переменную — избегайте этого.
3. `=` (присваивание) и `==` (сравнение) — разные вещи.
4. Строка `"10"` и число `10` — не одно и то же; используйте `tonumber()`.
5. Индекс за пределами массива вернёт `nil`, а не ошибку.

➡️ Дальше: [Скриптинг в Roblox](04-skripting-v-roblox.md)
