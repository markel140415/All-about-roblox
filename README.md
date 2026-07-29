# AnimTeacher — ИИ-учитель анимации для Roblox Studio

<sub>[English below](#english)</sub>

Плагин для Roblox Studio, который **учит анимации** прямо внутри редактора:
курс из 17 уроков, ответы на вопросы своими словами, готовые примеры кода
и проверка вашей реальной работы в Studio.

Работает **полностью офлайн**: без интернета, без API-ключей, без подписок.
Вся логика и база знаний — внутри плагина.

---

## Что умеет

| Возможность | Описание |
|---|---|
| **Курс** | 17 уроков в 4 модулях: от «что такое Motor6D» до IK, процедурной анимации и оптимизации |
| **Вопрос своими словами** | Спросите «почему анимация не работает» — получите разбор по шагам. Понимает русский и английский |
| **Примеры кода** | 16 готовых скриптов. Кнопка вставляет их прямо в нужное место игры (с поддержкой Ctrl+Z) |
| **Проверка работы** | Плагин смотрит ваш Workspace и скрипты: нашёл ли риг, используете ли современный API |
| **Тесты** | В каждом уроке вопрос с разбором, почему ответ верный |
| **Прогресс** | Сохраняется между сессиями Studio. Кнопка «Продолжить обучение» помнит, где вы остановились |
| **Два языка** | Русский и английский, переключение одной кнопкой |

Весь код в уроках написан на **актуальном API** (`Animator:LoadAnimation`,
`task.wait`) — устаревшие вызовы вроде `Humanoid:LoadAnimation` не только не
используются, но и отдельно разбираются как частая причина поломок.

---

## Установка

**Способ 1 — готовый файл (быстро)**

1. Скачайте [`build/AnimTeacher.rbxmx`](build/AnimTeacher.rbxmx).
2. Положите его в папку плагинов Studio:
   - Windows: `%LOCALAPPDATA%\Roblox\Plugins`
   - macOS: `~/Documents/Roblox/Plugins`
   
   Открыть папку можно из Studio: вкладка **Plugins → Plugins Folder**.
3. Перезапустите Studio. На вкладке **Plugins** появится кнопка **Учитель анимации**.

**Способ 2 — из исходника**

1. Откройте [`build/AnimTeacher.luau`](build/AnimTeacher.luau) и скопируйте весь текст.
2. В Studio вставьте новый `Script` в **ServerStorage** и вставьте туда код.
3. Правый клик по скрипту → **Save as Local Plugin**.
4. Удалите исходный скрипт из ServerStorage — плагин уже установлен.

---

## Программа курса

**Модуль 1 · Основы анимации**
1. Из чего состоит анимация (части, Motor6D, риг, R6 против R15)
2. Редактор анимаций: интерфейс
3. Первая анимация: позы и тайминг
4. Плавность: easing и кривые
5. Экспорт и AnimationId

**Модуль 2 · Воспроизведение из скриптов**
1. Animator и AnimationTrack
2. Приоритеты и зацикливание
3. События анимации (маркеры)
4. Веса, смешивание и скорость
5. Замена стандартных анимаций

**Модуль 3 · Практика в игре**
1. Модели без Humanoid
2. Инструменты и NPC
3. Репликация: кто и что видит

**Модуль 4 · Продвинутый уровень**
1. Инверсная кинематика (IKControl)
2. Процедурная анимация поверх ключевых кадров
3. Оптимизация и отладка
4. Внешние инструменты и рабочий процесс

---

## Как это работает без интернета

«ИИ» здесь — не языковая модель, а собственный разбор текста и база знаний.
Вопрос проходит через несколько этапов:

1. **Нормализация** — приведение к нижнему регистру с поддержкой кириллицы
   (стандартный `string.lower` в Luau кириллицу не трогает).
2. **Токенизация и стемминг** — «анимации», «анимацию», «анимация» сводятся
   к одному корню.
3. **Концепты** — слова на обоих языках отображаются на общие понятия, поэтому
   русский вопрос находит английскую статью и наоборот.
4. **Фразовые правила** — отдельно ловятся отрицания: «не работает», «не видят
   другие игроки». Без них «как работает X» путается с «X не работает».
5. **Ранжирование** — статьи и уроки получают баллы; если лучший результат ниже
   порога уверенности, плагин честно говорит «не понял вопрос» и предлагает
   варианты, вместо того чтобы выдумывать ответ.

---

## Разработка

Исходники лежат в `src/` как обычные ModuleScript'ы. Плагин для Studio должен
быть одним файлом, поэтому сборщик разворачивает дерево модулей в один бандл.

```bash
python3 tools/build.py            # собрать build/AnimTeacher.luau и .rbxmx
python3 tests/harness.py          # прогнать все тесты (сборка запускается сама)
```

Тестов **176**, они гоняются в настоящем интерпретаторе Lua через `lupa`
(`pip install lupa`) — включая end-to-end проверку, где реальный собранный
плагин запускается в моке Roblox API: открывается виджет, листаются уроки,
проходится тест, вставляется код, срабатывает проверка работы.

```
src/
  Main.luau            точка входа: тулбар, виджет, сервисы Studio
  Brain/Text.luau      кириллица, токенизация, стемминг, концепты
  Brain/Answer.luau    ранжирование и выбор ответа
  Brain/Checks.luau    проверка реального Workspace и скриптов
  Core/Progress.luau   прогресс и его сохранение
  Data/Lessons.luau    17 уроков
  Data/Knowledge.luau  25 статей базы знаний
  Data/Snippets.luau   16 примеров кода
  Data/Strings.luau    весь текст интерфейса (ru/en)
  UI/                  тема, компоненты, экраны
```

Подробности архитектуры — в [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

<a name="english"></a>

# AnimTeacher — AI Animation Teacher for Roblox Studio

A Roblox Studio plugin that **teaches animation** inside the editor: a
17-lesson course, free-form Q&A, ready-to-use code samples, and checks that
inspect your actual place.

Runs **fully offline** — no internet, no API keys, no subscriptions.

## Features

- **17 lessons in 4 modules**, from Motor6D basics to IK, procedural animation
  and optimization.
- **Ask in your own words**, in English or Russian — the tutor understands both
  and answers in the language you used.
- **16 code samples**, inserted straight into the right service with undo support.
- **"Check my work"** inspects your Workspace and scripts and tells you what is
  missing — including warning you about deprecated `Humanoid:LoadAnimation`.
- **Quizzes and saved progress** across Studio sessions.

Every sample uses the current API (`Animator:LoadAnimation`, `task.wait`).

## Install

Drop [`build/AnimTeacher.rbxmx`](build/AnimTeacher.rbxmx) into your Studio
plugins folder (**Plugins → Plugins Folder**) and restart Studio. Or paste
[`build/AnimTeacher.luau`](build/AnimTeacher.luau) into a Script and use
**Save as Local Plugin**.

## Development

```bash
python3 tools/build.py     # bundle src/ into build/
python3 tests/harness.py   # run all 176 tests (builds first)
```

Tests run in a real Lua interpreter via `lupa`, including an end-to-end test
that boots the built plugin against a Roblox API mock and drives the UI.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the design.

## License

MIT — see [LICENSE](LICENSE).

---

## 📚 All about Roblox — гайды и примеры для начинающих

Помимо плагина AnimTeacher, в репозитории есть **русскоязычные материалы по Roblox и Luau**:

- **[docs/](docs/)** — 7 разделов: [что такое Roblox](docs/01-chto-takoe-roblox.md),
  [первые шаги в Studio](docs/02-pervye-shagi-v-studio.md), [основы Luau](docs/03-osnovy-luau.md),
  [скриптинг](docs/04-skripting-v-roblox.md), [создание и продвижение игры](docs/05-sozdanie-i-prodvizhenie-igry.md),
  [оптимизация производительности](docs/06-optimizatsiya-proizvoditelnosti.md) и [безопасность](docs/07-bezopasnost.md).
- **[scripts/](scripts/)** — 5 готовых примеров скриптов на Luau с комментариями
  (leaderstats, сбор монет, смена дня и ночи, телепорт-площадки, двойной прыжок).
- **[resources/poleznye-ssylki.md](resources/poleznye-ssylki.md)** — официальные ресурсы и инструменты разработчика.
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — как дополнять гайды и примеры.
