# 💻 Примеры скриптов

Готовые скрипты на Luau с подробными комментариями. Просто скопируйте код и вставьте в Roblox Studio — в шапке каждого файла написано, куда именно.

## 📋 Как вставить скрипт

1. В Roblox Studio откройте окно **Explorer** (`View → Explorer`).
2. Наведитесь на нужный контейнер (например, `ServerScriptService`).
3. Нажмите **`+`** рядом с ним и выберите тип:
   - **Script** — для серверной логики;
   - **LocalScript** — для клиентской (интерфейс, ввод, камера).
4. В открывшийся редактор вставьте код из файла.
5. Нажмите **F5** (Play) и проверьте результат.

## 📦 Что здесь есть

| Файл | Тип | Контейнер | Что нужно подготовить |
|------|-----|-----------|------------------------|
| [`leaderstats.lua`](leaderstats.lua) | Script | ServerScriptService | Ничего |
| [`collect-coins.lua`](collect-coins.lua) | Script | ServerScriptService | Папку `Coins` с Part'ами в Workspace |
| [`day-night-cycle.lua`](day-night-cycle.lua) | Script | ServerScriptService | Ничего |
| [`teleport-pad.lua`](teleport-pad.lua) | Script | ServerScriptService | Part'ы `TeleportA` и `TeleportB` в Workspace |
| [`double-jump.lua`](double-jump.lua) | LocalScript | StarterPlayer → StarterPlayerScripts | Ничего |

## ⚠️ Важно

- Скрипты — **примеры для обучения**, а не production-код. Про безопасность (валидация на сервере) читайте в [разделе 7](../docs/07-bezopasnost.md).
- `collect-coins.lua` работает в паре с `leaderstats.lua` (начисляет в значение `Coins`).
- У вас свой вариант скрипта? Будем рады — см. [`CONTRIBUTING.md`](../CONTRIBUTING.md).
