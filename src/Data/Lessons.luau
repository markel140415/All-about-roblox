--[[
	Data/Lessons
	The animation curriculum: 4 modules, 14 lessons, zero to advanced.

	Every lesson is bilingual (ru/en) and has the same shape:
	  id        unique string id
	  module    module number (1..4)
	  title     short name
	  goal      one sentence: what the learner can do after this lesson
	  minutes   rough time budget
	  theory    array of paragraphs (the explanation)
	  steps     array of concrete actions to perform in Studio
	  snippet   optional id from Data/Snippets to insert
	  practice  the exercise
	  check     optional id of an automated check (see Brain/Checks)
	  quiz      one multiple-choice question with an explanation
	  keywords  extra search terms for the Q&A engine

	No Roblox API is touched here, so this file is unit tested.
]]

local Lessons = {}

Lessons.modules = {
	{
		id = 1,
		title = { ru = "Модуль 1 · Основы анимации", en = "Module 1 · Animation basics" },
		summary = {
			ru = "Риг, Motor6D, редактор анимаций, ключевые кадры, экспорт.",
			en = "Rigs, Motor6D, the Animation Editor, keyframes, exporting.",
		},
	},
	{
		id = 2,
		title = { ru = "Модуль 2 · Воспроизведение из скриптов", en = "Module 2 · Playback from scripts" },
		summary = {
			ru = "Animator, AnimationTrack, приоритеты, события, веса.",
			en = "Animator, AnimationTrack, priorities, events, weights.",
		},
	},
	{
		id = 3,
		title = { ru = "Модуль 3 · Практика в игре", en = "Module 3 · Real gameplay" },
		summary = {
			ru = "Инструменты, NPC, модели без Humanoid, репликация.",
			en = "Tools, NPCs, non-Humanoid rigs, replication.",
		},
	},
	{
		id = 4,
		title = { ru = "Модуль 4 · Продвинутый уровень", en = "Module 4 · Advanced" },
		summary = {
			ru = "IK, процедурная анимация, оптимизация, отладка.",
			en = "IK, procedural animation, optimization, debugging.",
		},
	},
}

Lessons.list = {

	--==================================================================
	-- MODULE 1
	--==================================================================

	{
		id = "1-1-what-is-animation",
		module = 1,
		minutes = 8,
		title = { ru = "Из чего состоит анимация в Roblox", en = "What a Roblox animation is made of" },
		goal = {
			ru = "Понять связку «части → Motor6D → риг → анимация» и разницу R6 / R15.",
			en = "Understand the chain parts → Motor6D → rig → animation, and R6 vs R15.",
		},
		theory = {
			ru = {
				"Анимация в Roblox не двигает части напрямую. Она вращает СУСТАВЫ. Сустав — это объект Motor6D, который соединяет две части: Part0 (родитель, остаётся на месте) и Part1 (потомок, который поворачивается).",
				"Набор частей, связанных Motor6D, называется РИГ (rig). Именно риг вы анимируете. Если в модели нет Motor6D — анимировать нечего, редактор просто не увидит суставов.",
				"У Motor6D есть C0 и C1 — это CFrame'ы, задающие, где именно находится точка вращения относительно каждой части. Анимация меняет свойство Transform у Motor6D: это смещение поверх базовой позы.",
				"Два стандартных рига персонажа: R6 — 6 частей и 5 суставов (Neck, Left/Right Shoulder, Left/Right Hip), стилизованный и дешёвый. R15 — 15 частей и 14 суставов, есть локти, колени, кисти и UpperTorso/LowerTorso; движения гораздо плавнее.",
				"Важное правило: анимация, сделанная для R15, НЕ будет работать на R6 и наоборот. Имена суставов разные. Выбирайте риг до того, как начнёте анимировать.",
			},
			en = {
				"A Roblox animation never moves parts directly. It rotates JOINTS. A joint is a Motor6D object that connects two parts: Part0 (the parent, stays put) and Part1 (the child, which rotates).",
				"A set of parts connected by Motor6D is called a RIG. The rig is what you animate. If a model has no Motor6D, there is nothing to animate and the editor will show no joints.",
				"Motor6D has C0 and C1 — CFrames that define where the pivot sits relative to each part. An animation drives the Motor6D Transform property: an offset applied on top of the base pose.",
				"There are two standard character rigs: R6 — 6 parts and 5 joints (Neck, Left/Right Shoulder, Left/Right Hip), stylized and cheap. R15 — 15 parts and 14 joints, with elbows, knees, wrists and UpperTorso/LowerTorso; much smoother motion.",
				"Key rule: an animation authored for R15 will NOT work on R6 and vice versa. The joint names differ. Pick your rig before you start animating.",
			},
		},
		steps = {
			ru = {
				"Откройте вкладку Avatar → Rig Builder и вставьте R15 Rig в Workspace.",
				"В Explorer раскройте модель и найдите внутри частей объекты Motor6D (например, UpperTorso → Neck, LeftUpperArm → LeftElbow).",
				"Выделите любой Motor6D и посмотрите в Properties на Part0, Part1, C0, C1.",
				"Для сравнения вставьте R6 Rig и посчитайте суставы: их будет всего 5.",
			},
			en = {
				"Open the Avatar tab → Rig Builder and insert an R15 Rig into the Workspace.",
				"In the Explorer, expand the model and find the Motor6D objects inside the parts (for example UpperTorso → Neck, LeftUpperArm → LeftElbow).",
				"Select any Motor6D and inspect Part0, Part1, C0 and C1 in Properties.",
				"For comparison insert an R6 Rig and count its joints: there are only 5.",
			},
		},
		practice = {
			ru = "Вставьте R15-риг в Workspace и найдите в нём минимум 3 объекта Motor6D. Назовите, какие части соединяет сустав LeftElbow.",
			en = "Insert an R15 rig into the Workspace and locate at least 3 Motor6D objects. Say which parts the LeftElbow joint connects.",
		},
		check = "rig-in-workspace",
		quiz = {
			question = {
				ru = "Что именно анимация изменяет, когда персонаж машет рукой?",
				en = "What does an animation actually change when a character waves?",
			},
			options = {
				{ ru = "Свойство Position у части руки", en = "The Position property of the arm part" },
				{ ru = "Свойство Transform у Motor6D сустава", en = "The Transform property of the Motor6D joint" },
				{ ru = "Свойство CFrame у модели целиком", en = "The CFrame of the whole model" },
				{ ru = "Скорость Humanoid", en = "The Humanoid's speed" },
			},
			answer = 2,
			explain = {
				ru = "Анимация вращает суставы: она пишет в Motor6D.Transform. Позиции частей пересчитываются физическим движком уже как следствие.",
				en = "Animations rotate joints by writing to Motor6D.Transform. Part positions are recomputed by the engine as a consequence.",
			},
		},
		keywords = { "motor6d", "rig", "r6", "r15", "joint", "сустав", "риг" },
	},

	{
		id = "1-2-editor-tour",
		module = 1,
		minutes = 10,
		title = { ru = "Редактор анимаций: интерфейс", en = "The Animation Editor: the interface" },
		goal = {
			ru = "Уверенно открывать редактор, двигать таймлайн и ставить первые позы.",
			en = "Confidently open the editor, navigate the timeline and set your first poses.",
		},
		theory = {
			ru = {
				"Animation Editor находится во вкладке Avatar. Порядок всегда один: сначала ВЫДЕЛИТЬ риг в Workspace, потом нажать Animation Editor. Если ничего не выделено, редактор попросит выбрать риг.",
				"При первом открытии он попросит имя анимации. Это внутреннее имя (KeyframeSequence), его потом видно в списке — назовите осмысленно, например Idle_Breathing.",
				"Слева — список дорожек (по одной на сустав). Справа — таймлайн со шкалой времени. Красная вертикальная линия — скраббер (текущее время).",
				"Чтобы поставить ключ: поставьте скраббер на нужное время, поверните часть в 3D-виде инструментом Rotate (R) — ключевой кадр создастся автоматически на всех изменённых суставах.",
				"По умолчанию длина анимации 1 секунда. Её можно растянуть, перетащив конечный маркер, или задать точно через настройки таймлайна.",
				"Кнопка с шестерёнкой справа от таймлайна открывает настройки: там включается показ Animation Events и переключение единиц (секунды / кадры).",
			},
			en = {
				"The Animation Editor lives in the Avatar tab. The order is always the same: first SELECT the rig in the Workspace, then click Animation Editor. With nothing selected it will ask you to pick a rig.",
				"On first open it asks for an animation name. This is the internal name (the KeyframeSequence) shown in the list later — name it meaningfully, e.g. Idle_Breathing.",
				"On the left is the track list (one per joint). On the right is the timeline. The red vertical line is the scrubber (the current time).",
				"To create a key: move the scrubber to the desired time, then rotate a part in the 3D view with the Rotate tool (R) — a keyframe is created automatically on every joint you changed.",
				"The default animation length is 1 second. Drag the end marker to extend it, or set it precisely through the timeline settings.",
				"The gear icon to the right of the timeline opens settings: that is where you enable Animation Events and switch units (seconds / frames).",
			},
		},
		steps = {
			ru = {
				"Выделите свой R15-риг в Workspace.",
				"Avatar → Animation Editor. Введите имя Idle_Test и нажмите Create.",
				"Нажмите R (Rotate) и поверните правую руку рига — на таймлайне появятся точки-ключи.",
				"Перетащите скраббер и нажмите пробел, чтобы проиграть.",
				"Откройте настройки таймлайна (шестерёнка) и включите Show Animation Events — пригодится в модуле 2.",
			},
			en = {
				"Select your R15 rig in the Workspace.",
				"Avatar → Animation Editor. Type the name Idle_Test and click Create.",
				"Press R (Rotate) and rotate the rig's right arm — key dots appear on the timeline.",
				"Drag the scrubber and press space to play it back.",
				"Open the timeline settings (gear) and enable Show Animation Events — you will need it in module 2.",
			},
		},
		practice = {
			ru = "Создайте анимацию Idle_Test длиной 2 секунды, где персонаж поднимает правую руку и опускает её обратно. Минимум 3 ключевых кадра.",
			en = "Create a 2-second Idle_Test animation where the character raises its right arm and lowers it back. At least 3 keyframes.",
		},
		quiz = {
			question = {
				ru = "Вы нажали Animation Editor, но он просит выбрать риг. Почему?",
				en = "You clicked Animation Editor but it asks you to select a rig. Why?",
			},
			options = {
				{ ru = "Не установлен плагин", en = "The plugin is not installed" },
				{ ru = "В Workspace не выделена модель с Motor6D", en = "No model with Motor6D is selected in the Workspace" },
				{ ru = "Нужно сначала опубликовать игру", en = "You must publish the place first" },
				{ ru = "Редактор работает только в Play-режиме", en = "The editor only works in Play mode" },
			},
			answer = 2,
			explain = {
				ru = "Редактору нужен объект для анимации. Выделите модель с суставами Motor6D перед открытием.",
				en = "The editor needs something to animate. Select a model containing Motor6D joints before opening it.",
			},
		},
		keywords = { "editor", "редактор", "timeline", "таймлайн", "scrubber" },
	},

	{
		id = "1-3-first-animation",
		module = 1,
		minutes = 14,
		title = { ru = "Первая анимация: позы и тайминг", en = "Your first animation: poses and timing" },
		goal = {
			ru = "Сделать читаемый цикл idle и понять принцип «поза важнее движения».",
			en = "Build a readable idle loop and internalize 'the pose matters more than the motion'.",
		},
		theory = {
			ru = {
				"Ключевой кадр (keyframe) — это сохранённая ПОЗА в конкретный момент времени. Движок сам достраивает промежуточные кадры (интерполяция). Ваша работа — выбрать хорошие позы и правильные моменты.",
				"Правило зацикливания: чтобы цикл не «дёргался», первый и последний кадр должны совпадать. Самый надёжный способ — скопировать первый кадр (правой кнопкой → Copy) и вставить его в конец.",
				"Тайминг решает всё. Одинаковые интервалы между ключами выглядят механически. Живое движение имеет неравномерный ритм: быстрый выпад и медленный возврат.",
				"Принцип контраста: если все части двигаются одинаково, глаз не читает движение. Смещайте фазы — рука начинает движение на пару кадров раньше корпуса.",
				"Для idle-анимации достаточно очень малых углов: 2–5 градусов на дыхание груди и лёгкое покачивание. Новички почти всегда делают idle слишком размашистым.",
				"Не забывайте про HumanoidRootPart: вертикальное смещение всего тела на 0.05–0.1 studs добавляет вес и дыхание.",
			},
			en = {
				"A keyframe is a saved POSE at a specific moment in time. The engine fills in the frames between them (interpolation). Your job is to pick good poses and good moments.",
				"Looping rule: for a loop not to pop, the first and last frames must match. The safest way is to copy the first keyframe (right click → Copy) and paste it at the end.",
				"Timing is everything. Evenly spaced keys look mechanical. Living motion has an uneven rhythm: a fast strike and a slow recovery.",
				"The contrast principle: if every part moves identically the eye cannot read the motion. Offset the phases — let the arm start a couple of frames before the torso.",
				"An idle needs tiny angles: 2–5 degrees of chest breathing and a slight sway. Beginners almost always make idles far too broad.",
				"Do not forget HumanoidRootPart: shifting the whole body vertically by 0.05–0.1 studs adds weight and breath.",
			},
		},
		steps = {
			ru = {
				"Создайте новую анимацию Idle_Breathing длиной 2 секунды.",
				"Кадр 0:00 — базовая стойка, ничего не трогайте, но поставьте ключ на UpperTorso.",
				"Кадр 1:00 — поднимите UpperTorso на 0.05 studs вверх и наклоните на 2 градуса назад; чуть разведите руки.",
				"Кадр 2:00 — вернитесь ровно в позу кадра 0:00 (скопируйте её).",
				"Включите Loop в настройках редактора и проиграйте: переход должен быть незаметным.",
			},
			en = {
				"Create a new 2-second animation called Idle_Breathing.",
				"Frame 0:00 — the base stance; change nothing but set a key on UpperTorso.",
				"Frame 1:00 — raise UpperTorso by 0.05 studs and tilt it 2 degrees back; open the arms slightly.",
				"Frame 2:00 — return exactly to the pose from frame 0:00 (copy it).",
				"Enable Loop in the editor settings and play: the wrap should be invisible.",
			},
		},
		practice = {
			ru = "Сделайте зацикленный idle на 2 секунды, где первый и последний кадр идентичны, а амплитуда дыхания не превышает 5 градусов.",
			en = "Build a looping 2-second idle where the first and last frames are identical and the breathing amplitude stays under 5 degrees.",
		},
		quiz = {
			question = {
				ru = "Зацикленная анимация заметно «дёргается» в момент повтора. Самая вероятная причина?",
				en = "A looped animation visibly pops at the wrap point. Most likely cause?",
			},
			options = {
				{ ru = "Слишком много ключевых кадров", en = "Too many keyframes" },
				{ ru = "Первый и последний кадр — разные позы", en = "The first and last frames are different poses" },
				{ ru = "Не выставлен Priority", en = "Priority is not set" },
				{ ru = "Анимация слишком короткая", en = "The animation is too short" },
			},
			answer = 2,
			explain = {
				ru = "При зацикливании последний кадр мгновенно сменяется первым. Если позы не совпадают, получается скачок.",
				en = "When looping, the last frame is instantly replaced by the first. If the poses differ you get a jump.",
			},
		},
		keywords = { "keyframe", "ключевой кадр", "idle", "loop", "цикл", "timing", "тайминг", "поза" },
	},

	{
		id = "1-4-easing-curves",
		module = 1,
		minutes = 12,
		title = { ru = "Плавность: easing и кривые", en = "Smoothness: easing and curves" },
		goal = {
			ru = "Управлять характером движения через Easing Style/Direction и Curve Editor.",
			en = "Control the character of motion with Easing Style/Direction and the Curve Editor.",
		},
		theory = {
			ru = {
				"Между двумя ключами движок интерполирует позу. КАК он это делает, задаёт easing — это свойство ключевого кадра, а не всей анимации.",
				"Easing Style — форма кривой: Linear (равномерно, механически), Sine (мягко, универсально), Quad/Cubic (сильнее ускорение), Back (перелёт назад перед движением), Elastic (пружина), Bounce (отскок), Constant (мгновенный скачок без интерполяции).",
				"Easing Direction — где применяется кривая: In (медленно в начале), Out (медленно в конце), InOut (медленно с обеих сторон). Для большинства человеческих движений подходит Sine + InOut.",
				"Реальные тела не стартуют мгновенно: они разгоняются и тормозят. Это называется slow in / slow out и это главный приём, отличающий живую анимацию от «робота».",
				"Чтобы задать easing: выделите ключ на таймлайне, правая кнопка → Easing Style / Easing Direction.",
				"Curve Editor (вкладка рядом с таймлайном) показывает значения как графики и даёт двигать касательные вручную. Это нужно, когда пресетов easing не хватает: например, чтобы сделать резкий удар с длинным затуханием.",
				"Приём Constant незаменим для «щелчков»: смена позы кадр-в-кадр без размазывания, как в pixel-art анимации или для мгновенной телепортации части.",
			},
			en = {
				"Between two keys the engine interpolates the pose. HOW it does that is defined by easing — a property of the keyframe, not of the whole animation.",
				"Easing Style is the shape of the curve: Linear (constant, mechanical), Sine (soft, a good default), Quad/Cubic (stronger acceleration), Back (overshoots backwards first), Elastic (springy), Bounce, Constant (an instant jump with no interpolation).",
				"Easing Direction is where the curve applies: In (slow at the start), Out (slow at the end), InOut (slow at both). Sine + InOut fits most human motion.",
				"Real bodies do not start instantly: they accelerate and decelerate. This is slow in / slow out, the single biggest thing separating living animation from a robot.",
				"To set easing: select a key on the timeline, right click → Easing Style / Easing Direction.",
				"The Curve Editor (a tab next to the timeline) shows values as graphs and lets you drag tangents by hand. Use it when the presets are not enough — for example a sharp hit with a long settle.",
				"Constant is invaluable for snaps: a pose change frame-to-frame with no smearing, as in pixel-art animation or to teleport a part instantly.",
			},
		},
		steps = {
			ru = {
				"Возьмите анимацию с одним резким движением руки (2 ключа).",
				"Выделите второй ключ → Easing Style → Linear. Проиграйте, запомните ощущение.",
				"Смените на Sine + InOut. Проиграйте снова — движение стало естественным.",
				"Попробуйте Back + Out на замахе: рука слегка уйдёт назад перед ударом.",
				"Откройте Curve Editor и посмотрите, как меняется форма графика для каждого стиля.",
			},
			en = {
				"Take an animation with one sharp arm movement (2 keys).",
				"Select the second key → Easing Style → Linear. Play it and remember how it feels.",
				"Switch to Sine + InOut. Play again — the motion now feels natural.",
				"Try Back + Out on a wind-up: the arm drifts back slightly before the strike.",
				"Open the Curve Editor and watch how the graph shape changes per style.",
			},
		},
		practice = {
			ru = "Сделайте анимацию удара, где замах использует Back/Out, сам удар — Quad/In (резкий), а возврат — Sine/InOut (медленный).",
			en = "Build a punch where the wind-up uses Back/Out, the strike uses Quad/In (sharp) and the recovery uses Sine/InOut (slow).",
		},
		quiz = {
			question = {
				ru = "Нужно, чтобы часть мгновенно перескочила в новую позу без плавного перехода. Какой Easing Style?",
				en = "You need a part to snap to a new pose with no smooth transition. Which Easing Style?",
			},
			options = {
				{ ru = "Linear", en = "Linear" },
				{ ru = "Constant", en = "Constant" },
				{ ru = "Elastic", en = "Elastic" },
				{ ru = "Sine", en = "Sine" },
			},
			answer = 2,
			explain = {
				ru = "Constant держит предыдущее значение до самого следующего ключа и меняет позу мгновенно — без интерполяции.",
				en = "Constant holds the previous value until the next key and swaps the pose instantly — no interpolation.",
			},
		},
		keywords = { "easing", "curve", "кривая", "изинг", "плавность", "интерполяция", "graph editor" },
	},

	{
		id = "1-5-export-publish",
		module = 1,
		minutes = 9,
		title = { ru = "Экспорт и AnimationId", en = "Exporting and the AnimationId" },
		goal = {
			ru = "Опубликовать анимацию и получить рабочий rbxassetid, понимая ограничения владельца.",
			en = "Publish an animation, get a working rbxassetid and understand the ownership rules.",
		},
		theory = {
			ru = {
				"Пока анимация живёт только в редакторе, скрипты её не видят. Её нужно опубликовать на Roblox и получить числовой ID.",
				"В редакторе: меню «...» (три точки) → Publish to Roblox. Заполните имя и описание, подтвердите. После публикации ID можно скопировать из того же меню (Copy Asset ID) или в Creator Dashboard → Development Items → Animations.",
				"В скрипте ID используется так: animation.AnimationId = \"rbxassetid://ЧИСЛО\". Именно с префиксом rbxassetid:// — просто число не сработает.",
				"САМАЯ ЧАСТАЯ ОШИБКА новичков: анимация не играет, потому что её владелец не совпадает с владельцем игры. Если вы опубликовали анимацию от своего аккаунта, а игра принадлежит группе — работать не будет. Публикуйте анимацию от того же владельца (в диалоге публикации есть выбор Creator).",
				"Обновление: если вы переработали анимацию, публикуйте её ПОВЕРХ существующего ассета (Overwrite / Update existing), тогда ID не изменится и скрипты править не придётся.",
				"Проверить, что ассет загрузился, можно по track.Length: если после LoadAnimation длина равна 0 — ассет не подгрузился (неверный ID или чужой владелец).",
			},
			en = {
				"While an animation lives only in the editor, scripts cannot see it. You must publish it to Roblox and get a numeric ID.",
				"In the editor: the \"...\" menu → Publish to Roblox. Fill in a name and description and confirm. Afterwards copy the ID from the same menu (Copy Asset ID) or from Creator Dashboard → Development Items → Animations.",
				"In a script the ID is used as animation.AnimationId = \"rbxassetid://NUMBER\". The rbxassetid:// prefix is required — a bare number will not work.",
				"THE most common beginner failure: the animation does not play because its owner differs from the owner of the experience. If you published it under your account but the game belongs to a group, it will not run. Publish under the same creator (the publish dialog has a Creator selector).",
				"Updating: when you rework an animation, publish it OVER the existing asset (Overwrite / Update existing) so the ID stays the same and no script changes are needed.",
				"To confirm the asset loaded, check track.Length: if it is 0 after LoadAnimation, the asset did not load (wrong ID or wrong owner).",
			},
		},
		steps = {
			ru = {
				"Откройте свою анимацию Idle_Breathing в редакторе.",
				"Меню «...» → Publish to Roblox. Проверьте поле Creator: оно должно совпадать с владельцем игры.",
				"После публикации скопируйте Asset ID.",
				"Сохраните ID в заметках — он понадобится в модуле 2.",
			},
			en = {
				"Open your Idle_Breathing animation in the editor.",
				"The \"...\" menu → Publish to Roblox. Check the Creator field: it must match the owner of the experience.",
				"After publishing, copy the Asset ID.",
				"Keep the ID handy — you will need it in module 2.",
			},
		},
		practice = {
			ru = "Опубликуйте свою idle-анимацию и запишите её ID в формате rbxassetid://ЧИСЛО.",
			en = "Publish your idle animation and write down its ID as rbxassetid://NUMBER.",
		},
		quiz = {
			question = {
				ru = "Анимация опубликована, ID вставлен, ошибок в Output нет, но персонаж не двигается, а track.Length = 0. Что проверить первым?",
				en = "The animation is published, the ID is set, no errors in Output, but nothing moves and track.Length = 0. What do you check first?",
			},
			options = {
				{ ru = "Совпадает ли владелец анимации с владельцем игры", en = "Whether the animation's owner matches the game's owner" },
				{ ru = "Скорость трека", en = "The track speed" },
				{ ru = "Количество ключевых кадров", en = "The number of keyframes" },
				{ ru = "Версию Studio", en = "The Studio version" },
			},
			answer = 1,
			explain = {
				ru = "Length = 0 означает, что данные ассета не загрузились. Чаще всего это несовпадение владельца (аккаунт против группы) или неверный ID.",
				en = "Length = 0 means the asset data never loaded. Usually that is an owner mismatch (account vs group) or a wrong ID.",
			},
		},
		keywords = { "export", "экспорт", "publish", "публикация", "assetid", "rbxassetid", "owner", "владелец", "группа" },
	},

	--==================================================================
	-- MODULE 2
	--==================================================================

	{
		id = "2-1-animator-track",
		module = 2,
		minutes = 12,
		title = { ru = "Animator и AnimationTrack", en = "Animator and AnimationTrack" },
		goal = {
			ru = "Проиграть свою анимацию из скрипта по современному API.",
			en = "Play your animation from a script using the current API.",
		},
		theory = {
			ru = {
				"Цепочка всегда одна и та же: Animation (ссылка на ассет) → Animator:LoadAnimation() → AnimationTrack (то, чем вы управляете) → track:Play().",
				"Animator — это объект внутри Humanoid. У любого персонажа он уже есть, надо просто дождаться: humanoid:WaitForChild(\"Animator\").",
				"ВАЖНО: Humanoid:LoadAnimation() и AnimationController:LoadAnimation() устарели (deprecated). Всегда используйте Animator:LoadAnimation(). Старый код в туториалах на YouTube чаще всего именно поэтому и ломается.",
				"LoadAnimation — дорогая операция. Загружайте трек ОДИН раз при старте и переиспользуйте его. Загрузка внутри обработчика нажатия создаёт новый трек на каждый клик и быстро съедает память.",
				"AnimationTrack — это ваш пульт: Play(fadeTime, weight, speed), Stop(fadeTime), AdjustSpeed(), AdjustWeight(), а также свойства IsPlaying, Length, TimePosition, Speed, Looped, Priority.",
				"У Play есть fadeTime (по умолчанию 0.1 с) — за это время трек плавно набирает вес. Резкий Play(0) выглядит дёргано; Stop(0) обрезает движение.",
				"После респавна персонажа появляется НОВЫЙ Humanoid и новый Animator. Все старые треки становятся бесполезными — их надо загружать заново в обработчике CharacterAdded.",
			},
			en = {
				"The chain is always the same: Animation (a pointer to the asset) → Animator:LoadAnimation() → AnimationTrack (what you control) → track:Play().",
				"The Animator is an object inside the Humanoid. Every character already has one; just wait for it: humanoid:WaitForChild(\"Animator\").",
				"IMPORTANT: Humanoid:LoadAnimation() and AnimationController:LoadAnimation() are deprecated. Always use Animator:LoadAnimation(). Old YouTube tutorials break for exactly this reason.",
				"LoadAnimation is expensive. Load the track ONCE at startup and reuse it. Loading inside a click handler creates a new track per click and burns memory fast.",
				"AnimationTrack is your remote control: Play(fadeTime, weight, speed), Stop(fadeTime), AdjustSpeed(), AdjustWeight(), plus the properties IsPlaying, Length, TimePosition, Speed, Looped and Priority.",
				"Play takes a fadeTime (0.1 s by default) over which the track ramps its weight up. A hard Play(0) looks jerky; Stop(0) cuts the motion off.",
				"After a respawn there is a NEW Humanoid and a new Animator. All old tracks are dead — reload them inside a CharacterAdded handler.",
			},
		},
		steps = {
			ru = {
				"Создайте LocalScript в StarterPlayer → StarterPlayerScripts.",
				"Вставьте пример кода этого урока (кнопка «Вставить код»).",
				"Замените rbxassetid://0 на ID своей анимации из урока 1-5.",
				"Нажмите Play и проверьте Output на ошибки.",
			},
			en = {
				"Create a LocalScript in StarterPlayer → StarterPlayerScripts.",
				"Insert this lesson's code sample (the \"Insert code\" button).",
				"Replace rbxassetid://0 with the ID of your animation from lesson 1-5.",
				"Press Play and check the Output for errors.",
			},
		},
		snippet = "play-basic",
		practice = {
			ru = "Запустите свою idle-анимацию из LocalScript. Затем перепишите скрипт так, чтобы трек корректно перезагружался после смерти персонажа.",
			en = "Play your idle animation from a LocalScript. Then rewrite it so the track reloads correctly after the character dies.",
		},
		check = "localscript-with-animator",
		quiz = {
			question = {
				ru = "Какой из вариантов — правильный современный способ получить AnimationTrack?",
				en = "Which of these is the correct modern way to obtain an AnimationTrack?",
			},
			options = {
				{ ru = "humanoid:LoadAnimation(animation)", en = "humanoid:LoadAnimation(animation)" },
				{ ru = "animator:LoadAnimation(animation)", en = "animator:LoadAnimation(animation)" },
				{ ru = "animation:Play()", en = "animation:Play()" },
				{ ru = "character:LoadAnimation(animation)", en = "character:LoadAnimation(animation)" },
			},
			answer = 2,
			explain = {
				ru = "Humanoid:LoadAnimation устарел. Современный путь — получить Animator внутри Humanoid и вызвать LoadAnimation у него.",
				en = "Humanoid:LoadAnimation is deprecated. The modern path is to get the Animator inside the Humanoid and call LoadAnimation on it.",
			},
		},
		keywords = { "animator", "loadanimation", "animationtrack", "track", "play", "deprecated", "трек" },
	},

	{
		id = "2-2-priority-looped",
		module = 2,
		minutes = 11,
		title = { ru = "Приоритеты и зацикливание", en = "Priorities and looping" },
		goal = {
			ru = "Понять, почему анимация «не видна», и управлять слоями через Priority.",
			en = "Understand why an animation seems invisible and control layering with Priority.",
		},
		theory = {
			ru = {
				"Когда несколько треков двигают один сустав, побеждает трек с более высоким приоритетом. Это не смешивание — это перекрытие.",
				"Шкала от низшего к высшему: Core → Idle → Movement → Action → Action2 → Action3 → Action4.",
				"Стандартные анимации персонажа (ходьба, прыжок из скрипта Animate) работают на Movement и Idle. Поэтому ваша анимация с приоритетом Idle будет ПЕРЕКРЫТА ходьбой, и вам покажется, что она «не работает».",
				"Правило по умолчанию: любое действие игрока (удар, взмах, эмоция) ставьте на Action. Тогда оно перекроет стандартную ходьбу.",
				"Приоритет можно задать двумя способами: в редакторе анимаций (сохраняется в самом ассете) или в скрипте через track.Priority = Enum.AnimationPriority.Action. Скрипт имеет приоритет над настройкой ассета.",
				"track.Looped: если анимация должна повторяться (idle, бег) — true. Для одноразовых действий (удар) — false, иначе она никогда не закончится и Ended не сработает.",
				"Свойство Looped тоже сохраняется в ассете при публикации, но в скрипте его можно переопределить.",
				"Если два трека имеют ОДИНАКОВЫЙ приоритет, они смешиваются по весу — об этом следующий урок.",
			},
			en = {
				"When several tracks drive the same joint, the one with the higher priority wins. This is not blending — it is overriding.",
				"The scale from lowest to highest: Core → Idle → Movement → Action → Action2 → Action3 → Action4.",
				"The default character animations (walking, jumping, from the Animate script) run at Movement and Idle. So your animation set to Idle gets OVERRIDDEN by walking, and it looks like it 'does not work'.",
				"Default rule: any player action (a hit, a swing, an emote) goes on Action. That beats the built-in locomotion.",
				"Priority can be set two ways: in the Animation Editor (baked into the asset) or in a script via track.Priority = Enum.AnimationPriority.Action. The script wins over the asset setting.",
				"track.Looped: true for anything that repeats (idle, run). For one-shot actions (a punch) use false, otherwise it never ends and Ended never fires.",
				"Looped is also stored in the asset on publish, but a script can override it.",
				"If two tracks share the SAME priority they blend by weight — that is the next lesson.",
			},
		},
		steps = {
			ru = {
				"Возьмите скрипт из прошлого урока и уберите строку с Priority.",
				"Запустите игру и начните бежать во время анимации — она пропадёт.",
				"Верните track.Priority = Enum.AnimationPriority.Action и повторите: теперь анимация перекрывает бег.",
				"Поэкспериментируйте с Looped = true / false на одноразовом действии.",
			},
			en = {
				"Take the script from the previous lesson and remove the Priority line.",
				"Run the game and start running during the animation — it disappears.",
				"Restore track.Priority = Enum.AnimationPriority.Action and repeat: now it overrides running.",
				"Experiment with Looped = true / false on a one-shot action.",
			},
		},
		practice = {
			ru = "Добейтесь, чтобы ваша анимация взмаха рукой была видна, пока персонаж бежит. Объясните, какой приоритет вы выбрали и почему.",
			en = "Make your arm-wave animation visible while the character is running. Explain which priority you chose and why.",
		},
		quiz = {
			question = {
				ru = "Ваша анимация играет, когда персонаж стоит, но исчезает при беге. Что сделать?",
				en = "Your animation plays while standing but vanishes when running. What do you do?",
			},
			options = {
				{ ru = "Увеличить скорость трека", en = "Increase the track speed" },
				{ ru = "Поставить Priority = Action (выше, чем Movement)", en = "Set Priority = Action (above Movement)" },
				{ ru = "Включить Looped", en = "Enable Looped" },
				{ ru = "Перезагрузить Studio", en = "Restart Studio" },
			},
			answer = 2,
			explain = {
				ru = "Бег работает на приоритете Movement. Чтобы перекрыть его, нужен более высокий уровень — Action.",
				en = "Running runs at Movement priority. To override it you need a higher level — Action.",
			},
		},
		keywords = { "priority", "приоритет", "looped", "цикл", "action", "movement", "перекрытие" },
	},

	{
		id = "2-3-events",
		module = 2,
		minutes = 10,
		title = { ru = "События анимации (маркеры)", en = "Animation events (markers)" },
		goal = {
			ru = "Синхронизировать урон, звук и эффекты с точным кадром анимации.",
			en = "Sync damage, sound and effects to an exact frame of the animation.",
		},
		theory = {
			ru = {
				"Проблема: удар должен наносить урон именно в момент касания, а не через task.wait(0.35) наугад. Если вы поменяете тайминг анимации, все хардкод-задержки поедут.",
				"Решение — Animation Events: именованные маркеры прямо на таймлайне. Скрипт подписывается на имя маркера и получает сигнал ровно в тот момент, когда скраббер до него дошёл.",
				"Создание: в редакторе включите Show Animation Events (шестерёнка справа от таймлайна), поставьте скраббер на нужный кадр, нажмите Edit Animation Events → + Add Event, введите имя (например HitFrame).",
				"У события есть необязательный Parameter — произвольная строка. Через неё удобно передавать данные: \"20\" (урон), \"left,heavy\" (нога и сила).",
				"В коде: track:GetMarkerReachedSignal(\"HitFrame\"):Connect(function(param) ... end). Имя должно совпадать точно, с учётом регистра.",
				"Событие сработает столько раз, сколько маркеров с этим именем стоит на таймлайне. Это удобно для шагов: два маркера FootStep — два звука за цикл.",
				"Маркеры сохраняются внутри ассета анимации, поэтому после изменения событий анимацию нужно опубликовать заново (поверх старого ассета).",
			},
			en = {
				"The problem: a punch should deal damage exactly on contact, not after a guessed task.wait(0.35). Change the animation timing and every hardcoded delay is wrong.",
				"The fix is Animation Events: named markers placed on the timeline. A script subscribes to the marker name and is signalled the instant the scrubber reaches it.",
				"To create one: enable Show Animation Events in the editor (the gear right of the timeline), move the scrubber to the frame, click Edit Animation Events → + Add Event and type a name (e.g. HitFrame).",
				"An event has an optional Parameter — an arbitrary string. It is handy for data: \"20\" (damage) or \"left,heavy\" (which foot and how hard).",
				"In code: track:GetMarkerReachedSignal(\"HitFrame\"):Connect(function(param) ... end). The name must match exactly, case included.",
				"The event fires once per marker with that name on the timeline. Great for footsteps: two FootStep markers, two sounds per cycle.",
				"Markers are stored inside the animation asset, so after editing events you must republish the animation (over the existing asset).",
			},
		},
		steps = {
			ru = {
				"Откройте анимацию удара в редакторе и включите показ событий.",
				"Поставьте маркер HitFrame на кадр контакта и маркер Recover на начало возврата.",
				"Опубликуйте анимацию поверх старого ассета.",
				"Вставьте код этого урока и подпишитесь на оба маркера, выводя print.",
			},
			en = {
				"Open your punch animation in the editor and enable event display.",
				"Place a HitFrame marker on the contact frame and a Recover marker where the recovery starts.",
				"Republish the animation over the existing asset.",
				"Insert this lesson's code and subscribe to both markers with a print.",
			},
		},
		snippet = "events-markers",
		practice = {
			ru = "Добавьте в анимацию ходьбы два маркера FootStep и проигрывайте звук шага по каждому. Передайте через Parameter, какая нога («left» / «right»).",
			en = "Add two FootStep markers to a walk animation and play a step sound on each. Use the Parameter to say which foot ('left' / 'right').",
		},
		quiz = {
			question = {
				ru = "Почему маркеры лучше, чем task.wait(0.35) перед нанесением урона?",
				en = "Why are markers better than task.wait(0.35) before applying damage?",
			},
			options = {
				{ ru = "Они быстрее выполняются", en = "They execute faster" },
				{ ru = "Они привязаны к кадру анимации и не ломаются при смене тайминга", en = "They are tied to the animation frame and survive timing changes" },
				{ ru = "Они работают только на сервере", en = "They only work on the server" },
				{ ru = "Они не требуют публикации", en = "They do not require publishing" },
			},
			answer = 2,
			explain = {
				ru = "Маркер живёт внутри анимации. Изменили тайминг — момент срабатывания сместится вместе с ним, код править не нужно.",
				en = "The marker lives inside the animation. Change the timing and the trigger moves with it — no code changes needed.",
			},
		},
		keywords = { "event", "событие", "marker", "маркер", "getmarkerreachedsignal", "keyframe", "звук", "урон" },
	},

	{
		id = "2-4-weight-speed",
		module = 2,
		minutes = 12,
		title = { ru = "Веса, смешивание и скорость", en = "Weights, blending and speed" },
		goal = {
			ru = "Плавно смешивать несколько анимаций и управлять темпом на лету.",
			en = "Blend several animations smoothly and control tempo on the fly.",
		},
		theory = {
			ru = {
				"Вес (weight) определяет, насколько сильно трек влияет на итоговую позу. Диапазон обычный — от 0 до 1, по умолчанию 1.",
				"Когда несколько треков имеют ОДИНАКОВЫЙ приоритет, итоговая поза = взвешенное среднее их поз. Именно так делают плавный переход ходьба → бег без рывка.",
				"AdjustWeight(weight, fadeTime) меняет вес не мгновенно: WeightCurrent плавно едет к WeightTarget за fadeTime секунд. Всегда давайте хотя бы 0.1, иначе смысл блендинга теряется.",
				"Практический приём: два трека Movement — walk и run. walk:AdjustWeight(1 - alpha), run:AdjustWeight(alpha), где alpha считается от текущей скорости персонажа. Получается непрерывный переход.",
				"AdjustSpeed(speed) меняет темп: 1 — нормально, 2 — вдвое быстрее, 0 — пауза, отрицательное значение — воспроизведение задом наперёд.",
				"Полезная формула: чтобы анимация шага совпадала с реальной скоростью персонажа, ставьте track:AdjustSpeed(humanoid.WalkSpeed / BASE_SPEED), где BASE_SPEED — скорость, под которую анимация рисовалась. Это убирает эффект «скольжения ног».",
				"track.Length — длина при скорости 1. Реальная длительность = Length / Speed.",
				"Не путайте вес и приоритет: приоритет решает, КТО победит; вес решает, НАСКОЛЬКО, среди равных.",
			},
			en = {
				"Weight defines how strongly a track contributes to the final pose. The usual range is 0 to 1, default 1.",
				"When several tracks share the SAME priority, the final pose is the weighted average of their poses. That is exactly how a seamless walk → run transition is built.",
				"AdjustWeight(weight, fadeTime) is not instant: WeightCurrent glides toward WeightTarget over fadeTime seconds. Always give it at least 0.1 or you lose the point of blending.",
				"A practical recipe: two Movement tracks, walk and run. walk:AdjustWeight(1 - alpha) and run:AdjustWeight(alpha), where alpha comes from the character's current speed. The transition becomes continuous.",
				"AdjustSpeed(speed) changes tempo: 1 is normal, 2 is twice as fast, 0 pauses, and a negative value plays it backwards.",
				"A useful formula: to match a walk cycle to the real character speed, use track:AdjustSpeed(humanoid.WalkSpeed / BASE_SPEED), where BASE_SPEED is the speed the animation was authored for. This kills foot sliding.",
				"track.Length is the length at speed 1. The real duration is Length / Speed.",
				"Do not confuse weight and priority: priority decides WHO wins; weight decides BY HOW MUCH, among equals.",
			},
		},
		steps = {
			ru = {
				"Загрузите два трека — walk и run — и поставьте обоим Priority = Movement.",
				"Запустите оба через Play() и выставьте начальные веса 1 и 0.",
				"В RenderStepped считайте alpha от скорости и вызывайте AdjustWeight.",
				"Отдельно проверьте AdjustSpeed(0.5) и AdjustSpeed(-1).",
			},
			en = {
				"Load two tracks — walk and run — and set both to Priority = Movement.",
				"Play both and set the initial weights to 1 and 0.",
				"In RenderStepped compute alpha from speed and call AdjustWeight.",
				"Separately try AdjustSpeed(0.5) and AdjustSpeed(-1).",
			},
		},
		snippet = "blend-weights",
		practice = {
			ru = "Сделайте плавный переход ходьба → бег через веса, без единого Stop(). Затем добавьте синхронизацию скорости анимации с WalkSpeed.",
			en = "Build a smooth walk → run transition using weights, without a single Stop(). Then sync the animation speed to WalkSpeed.",
		},
		quiz = {
			question = {
				ru = "Два трека играют одновременно с приоритетом Movement и весами 0.25 и 0.75. Что увидит игрок?",
				en = "Two tracks play at Movement priority with weights 0.25 and 0.75. What does the player see?",
			},
			options = {
				{ ru = "Только второй трек", en = "Only the second track" },
				{ ru = "Смесь поз, где второй трек влияет втрое сильнее", en = "A blend where the second track contributes three times as much" },
				{ ru = "Треки будут играть по очереди", en = "The tracks alternate" },
				{ ru = "Ошибку в Output", en = "An error in the Output" },
			},
			answer = 2,
			explain = {
				ru = "При равном приоритете позы усредняются по весам: 0.75 / (0.25 + 0.75) = 75 % влияния у второго трека.",
				en = "At equal priority the poses are averaged by weight: 0.75 / (0.25 + 0.75) = 75 % influence for the second track.",
			},
		},
		keywords = { "weight", "вес", "blend", "смешивание", "adjustweight", "adjustspeed", "speed", "скорость" },
	},

	{
		id = "2-5-default-animations",
		module = 2,
		minutes = 9,
		title = { ru = "Замена стандартных анимаций", en = "Replacing the default animations" },
		goal = {
			ru = "Поставить свою походку, прыжок и idle всем игрокам.",
			en = "Give every player your own walk, jump and idle.",
		},
		theory = {
			ru = {
				"Внутри каждого персонажа Roblox создаёт LocalScript с именем Animate. Он содержит вложенные объекты Animation для каждого состояния: run, walk, jump, idle, fall, climb, swim, swimidle.",
				"Чтобы заменить стандартную анимацию, достаточно перезаписать AnimationId у соответствующего объекта — переписывать сам скрипт Animate не нужно.",
				"Делать это надо на СЕРВЕРЕ (Script в ServerScriptService) и в момент появления персонажа. Надёжнее всего подписаться на player.CharacterAppearanceLoaded, а не на CharacterAdded: к этому моменту скрипт Animate уже точно на месте.",
				"Перед заменой стоит остановить уже играющие треки: for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0) end. Иначе старая анимация доиграет поверх новой.",
				"У idle два варианта — Animation1 и Animation2. Скрипт выбирает между ними случайно, а частоту задаёт дочерний объект Weight: шанс = вес анимации / сумма весов всех вариантов состояния.",
				"Альтернативный путь без кода: вставить собственную копию скрипта Animate в StarterCharacterScripts и отредактировать ID прямо в ней. Это удобнее для полного контроля, но копия не будет получать обновления от Roblox.",
				"Помните про совместимость рига: если ваша игра использует R15, все заменяющие анимации тоже должны быть R15.",
			},
			en = {
				"Inside every character Roblox creates a LocalScript called Animate. It holds nested Animation objects for each state: run, walk, jump, idle, fall, climb, swim, swimidle.",
				"To replace a default animation you only overwrite the AnimationId on the matching object — there is no need to rewrite the Animate script itself.",
				"Do it on the SERVER (a Script in ServerScriptService) as the character appears. The most reliable hook is player.CharacterAppearanceLoaded rather than CharacterAdded: by then the Animate script is definitely in place.",
				"Stop the already playing tracks first: for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0) end. Otherwise the old animation finishes on top of the new one.",
				"Idle has two variants, Animation1 and Animation2. The script picks randomly and a child Weight object sets the odds: chance = that animation's weight / the sum of weights for the state.",
				"A code-free alternative: put your own copy of the Animate script into StarterCharacterScripts and edit the IDs directly. That gives full control, but your copy stops receiving Roblox updates.",
				"Mind rig compatibility: if your game uses R15, every replacement animation must be R15 too.",
			},
		},
		steps = {
			ru = {
				"Создайте Script в ServerScriptService и вставьте код этого урока.",
				"Раскомментируйте строку run.RunAnim и подставьте свой ID.",
				"Запустите игру и побегайте.",
				"Добавьте замену idle и задайте Weight так, чтобы вторая вариация играла вдвое чаще.",
			},
			en = {
				"Create a Script in ServerScriptService and insert this lesson's code.",
				"Uncomment the run.RunAnim line and paste your ID.",
				"Run the game and move around.",
				"Add an idle replacement and set Weight so the second variation plays twice as often.",
			},
		},
		snippet = "replace-default",
		practice = {
			ru = "Замените стандартный бег и обе idle-вариации своими анимациями. Настройте веса 1 и 2.",
			en = "Replace the default run and both idle variations with your own animations. Set the weights to 1 and 2.",
		},
		quiz = {
			question = {
				ru = "Где находятся объекты Animation, отвечающие за стандартную ходьбу игрока?",
				en = "Where do the Animation objects for the player's default walk live?",
			},
			options = {
				{ ru = "В ServerStorage", en = "In ServerStorage" },
				{ ru = "Внутри скрипта Animate в модели персонажа", en = "Inside the Animate script in the character model" },
				{ ru = "В Humanoid", en = "In the Humanoid" },
				{ ru = "В StarterGui", en = "In StarterGui" },
			},
			answer = 2,
			explain = {
				ru = "Скрипт Animate внутри персонажа содержит вложенные Animation-объекты для каждого состояния движения.",
				en = "The Animate script inside the character holds nested Animation objects for every locomotion state.",
			},
		},
		keywords = { "default", "стандартные", "animate", "walk", "run", "ходьба", "бег", "замена", "replace" },
	},

	--==================================================================
	-- MODULE 3
	--==================================================================

	{
		id = "3-1-non-humanoid",
		module = 3,
		minutes = 10,
		title = { ru = "Модели без Humanoid", en = "Rigs without a Humanoid" },
		goal = {
			ru = "Анимировать дверь, машину, дракона — всё, что не является персонажем.",
			en = "Animate a door, a car, a dragon — anything that is not a character.",
		},
		theory = {
			ru = {
				"Animator должен где-то жить. У персонажа его родитель — Humanoid. Если Humanoid нет, вы создаёте AnimationController и кладёте Animator внутрь него.",
				"Иерархия: Model → AnimationController → Animator. Дальше всё как обычно: animator:LoadAnimation(animation).",
				"Уточнение по терминологии: сам класс AnimationController не устарел — устарел только его метод LoadAnimation. Поэтому создавайте контроллер, но загружайте через Animator.",
				"Модель всё равно должна быть ригом: части, соединённые Motor6D, и обязательно заданный PrimaryPart. Без Motor6D редактор анимаций не покажет ни одной дорожки.",
				"Частая ошибка — части не заякорены и разлетаются. Правило: якорите ТОЛЬКО корневую часть (Part0 самой первой цепочки), остальные должны быть Anchored = false, иначе суставы не смогут их двигать.",
				"Ещё одна ловушка: CanCollide у движущихся частей лучше выключить, иначе анимированная модель начнёт толкать сама себя.",
			},
			en = {
				"The Animator has to live somewhere. On a character its parent is the Humanoid. Without a Humanoid you create an AnimationController and put the Animator inside it.",
				"The hierarchy is Model → AnimationController → Animator. From there it is business as usual: animator:LoadAnimation(animation).",
				"A terminology note: the AnimationController class itself is not deprecated — only its LoadAnimation method is. So create the controller, but load through the Animator.",
				"The model still has to be a rig: parts joined by Motor6D, with a PrimaryPart set. Without Motor6D the Animation Editor shows no tracks at all.",
				"A common failure is unanchored parts flying apart. The rule: anchor ONLY the root part (the Part0 of the first chain); everything else must be Anchored = false or the joints cannot move them.",
				"Another trap: turn CanCollide off on moving parts, otherwise the animated model starts shoving itself around.",
			},
		},
		steps = {
			ru = {
				"Соберите модель из двух частей и соедините их Motor6D (можно кодом из примера урока 4-х).",
				"Задайте модели PrimaryPart и заякорите только корневую часть.",
				"Откройте Animation Editor с выделенной моделью и сделайте короткую анимацию.",
				"Вставьте Script из примера внутрь модели и запустите игру.",
			},
			en = {
				"Build a two-part model and join them with a Motor6D (the code sample from the rig lesson works).",
				"Set the model's PrimaryPart and anchor only the root part.",
				"Open the Animation Editor with the model selected and make a short animation.",
				"Insert the sample Script into the model and run the game.",
			},
		},
		snippet = "non-humanoid",
		practice = {
			ru = "Сделайте анимированную дверь: две части (рама и полотно), Motor6D, анимация открытия на 1.5 секунды, запуск из скрипта.",
			en = "Build an animated door: two parts (frame and panel), a Motor6D, a 1.5-second opening animation, played from a script.",
		},
		quiz = {
			question = {
				ru = "У модели дракона нет Humanoid. Куда положить Animator?",
				en = "A dragon model has no Humanoid. Where does the Animator go?",
			},
			options = {
				{ ru = "Прямо в Workspace", en = "Directly into the Workspace" },
				{ ru = "Внутрь AnimationController, который лежит в модели", en = "Inside an AnimationController parented to the model" },
				{ ru = "Внутрь любой части модели", en = "Inside any part of the model" },
				{ ru = "Animator не нужен", en = "No Animator is needed" },
			},
			answer = 2,
			explain = {
				ru = "Без Humanoid роль владельца Animator берёт на себя AnimationController.",
				en = "Without a Humanoid, the AnimationController takes over as the Animator's owner.",
			},
		},
		keywords = { "animationcontroller", "non-humanoid", "дверь", "npc", "модель", "motor6d", "anchored" },
	},

	{
		id = "3-2-tools-npc",
		module = 3,
		minutes = 13,
		title = { ru = "Инструменты и NPC", en = "Tools and NPCs" },
		goal = {
			ru = "Анимировать оружие в руках игрока и построить простую машину состояний для NPC.",
			en = "Animate a weapon in the player's hands and build a simple NPC state machine.",
		},
		theory = {
			ru = {
				"Tool анимируется не сам по себе — анимируется ПЕРСОНАЖ, который его держит. Трек грузится на Animator персонажа, а не на инструмент.",
				"Чтобы оружие двигалось вместе с рукой, оно должно быть присоединено к ней. Handle крепится через RightGrip (Roblox создаёт его автоматически) или через собственный Motor6D, если нужна полная свобода.",
				"Жизненный цикл Tool: Equipped (взяли — грузим и запускаем idle-трек), Activated (кликнули — играем удар), Unequipped (убрали — обязательно останавливаем ВСЕ треки, иначе анимация останется висеть).",
				"Idle инструмента ставьте на приоритет Idle, а атаку — на Action. Тогда атака перекроет удержание, а удержание не будет мешать ходьбе.",
				"Для NPC ключевая идея — машина состояний: одно активное состояние в каждый момент, переход только при смене.",
				"Главная ошибка новичков в NPC: вызывать track:Play() каждый кадр в цикле. Трек перезапускается непрерывно и анимация выглядит замершей. Всегда проверяйте, не играет ли уже нужный трек.",
				"Для NPC удобно подписаться на humanoid.Running (даёт скорость) и humanoid.StateChanged (прыжок, падение).",
			},
			en = {
				"A Tool is not animated by itself — you animate the CHARACTER holding it. The track is loaded onto the character's Animator, not onto the tool.",
				"For the weapon to follow the hand it must be attached to it. The Handle is welded through RightGrip (Roblox creates it automatically) or through your own Motor6D when you need full freedom.",
				"Tool lifecycle: Equipped (picked up — load and start the idle track), Activated (clicked — play the swing), Unequipped (put away — you MUST stop every track or the pose stays stuck).",
				"Put the tool idle on Idle priority and the attack on Action. Then the attack overrides the hold, and the hold does not fight locomotion.",
				"For NPCs the key idea is a state machine: exactly one active state at a time, with a transition only when it changes.",
				"The classic NPC mistake is calling track:Play() every frame in a loop. The track restarts constantly and the animation looks frozen. Always check whether the desired track is already playing.",
				"For NPCs, hook humanoid.Running (gives you the speed) and humanoid.StateChanged (jumping, falling).",
			},
		},
		steps = {
			ru = {
				"Создайте Tool с Handle и положите в StarterPack.",
				"Вставьте LocalScript из примера внутрь Tool и подставьте свои ID.",
				"Проверьте: взяли инструмент — играет idle; кликнули — играет удар; убрали — всё остановилось.",
				"Затем возьмите пример с NPC и постройте переключение idle / walk через humanoid.Running.",
			},
			en = {
				"Create a Tool with a Handle and put it in StarterPack.",
				"Insert the sample LocalScript into the Tool and set your IDs.",
				"Verify: equipping plays the idle, clicking plays the swing, unequipping stops everything.",
				"Then take the NPC sample and build idle / walk switching from humanoid.Running.",
			},
		},
		snippet = "tool-animation",
		practice = {
			ru = "Сделайте меч: idle при удержании и взмах по клику. Затем добавьте NPC, который переключается между idle и ходьбой без перезапуска трека каждый кадр.",
			en = "Build a sword: an idle while held and a swing on click. Then add an NPC that switches between idle and walking without restarting the track every frame.",
		},
		quiz = {
			question = {
				ru = "NPC играет анимацию ходьбы, но она выглядит «застывшей» на первом кадре. Причина?",
				en = "An NPC plays a walk animation but it looks frozen on the first frame. Why?",
			},
			options = {
				{ ru = "Слишком низкий приоритет", en = "The priority is too low" },
				{ ru = "Play() вызывается в цикле каждый кадр и постоянно перезапускает трек", en = "Play() is called every frame in a loop and keeps restarting the track" },
				{ ru = "Не хватает Motor6D", en = "A Motor6D is missing" },
				{ ru = "Анимация не опубликована", en = "The animation is not published" },
			},
			answer = 2,
			explain = {
				ru = "Каждый Play() начинает трек заново. В цикле это означает вечный первый кадр. Проверяйте IsPlaying или храните текущее состояние.",
				en = "Every Play() restarts the track. In a loop that means an eternal first frame. Check IsPlaying or track the current state.",
			},
		},
		keywords = { "tool", "инструмент", "оружие", "меч", "npc", "state machine", "equipped", "activated" },
	},

	{
		id = "3-3-replication",
		module = 3,
		minutes = 11,
		title = { ru = "Репликация: кто и что видит", en = "Replication: who sees what" },
		goal = {
			ru = "Сделать так, чтобы анимацию видели все игроки, и не открыть дыру в безопасности.",
			en = "Make every player see the animation without opening a security hole.",
		},
		theory = {
			ru = {
				"Главное правило: если клиент проигрывает анимацию через Animator СВОЕГО персонажа, Roblox сам реплицирует её всем остальным. Ничего пересылать вручную не нужно.",
				"Именно поэтому анимации игрока правильно запускать в LocalScript: получается мгновенный отклик без задержки сети.",
				"Если запустить ту же анимацию на сервере, отклик у самого игрока будет с задержкой пинга. Для действий игрока это ощущается хуже.",
				"Для NPC — наоборот. Персонажем NPC владеет сервер, поэтому его анимации нужно запускать серверным скриптом, иначе их увидит только один клиент.",
				"Опасная ошибка новичков: RemoteEvent, который принимает от клиента AnimationId и играет что угодно. Эксплойтер отправит любой ID. Никогда не принимайте идентификатор анимации от клиента — сервер должен сам знать список допустимых анимаций.",
				"Правильная схема боя: клиент играет анимацию локально (мгновенно) и сообщает серверу «я атаковал». Сервер проверяет кулдаун и дистанцию и уже сам применяет урон.",
				"Обязательно ставьте на сервере ограничение частоты (rate limit). Без него клиент может слать событие сотни раз в секунду.",
			},
			en = {
				"The core rule: when a client plays an animation through ITS OWN character's Animator, Roblox replicates it to everyone else automatically. There is nothing to forward by hand.",
				"That is exactly why player animations belong in a LocalScript: you get instant response with no network delay.",
				"Play the same animation on the server and the acting player feels a ping-sized lag. For player actions that is strictly worse.",
				"For NPCs it is the opposite. The server owns the NPC's character, so its animations must be started by a server script or only one client will see them.",
				"A dangerous beginner mistake: a RemoteEvent that accepts an AnimationId from the client and plays whatever it is given. An exploiter will send any ID. Never accept an animation identifier from the client — the server must own the list of allowed animations.",
				"The correct combat pattern: the client plays the animation locally (instant) and tells the server 'I attacked'. The server validates cooldown and distance and applies the damage itself.",
				"Always rate limit on the server. Without it a client can fire the event hundreds of times per second.",
			},
		},
		steps = {
			ru = {
				"Вставьте пример этого урока: LocalScript играет анимацию, RemoteEvent сообщает серверу.",
				"Запустите тест на двух игроках (Test → Players: 2) и убедитесь, что второй игрок видит анимацию.",
				"Добавьте на сервере проверку кулдауна через os.clock().",
				"Убедитесь, что сервер НЕ получает AnimationId от клиента.",
			},
			en = {
				"Insert this lesson's sample: a LocalScript plays the animation, a RemoteEvent notifies the server.",
				"Run a two-player test (Test → Players: 2) and confirm the second player sees it.",
				"Add a server-side cooldown check with os.clock().",
				"Confirm the server never receives an AnimationId from the client.",
			},
		},
		snippet = "replicated-attack",
		practice = {
			ru = "Реализуйте атаку: клиент играет анимацию, сервер валидирует кулдаун 0.8 с и наносит урон. Проверьте на двух игроках.",
			en = "Implement an attack: the client plays the animation, the server validates a 0.8 s cooldown and applies damage. Test it with two players.",
		},
		quiz = {
			question = {
				ru = "Игрок видит свою анимацию, а другие игроки — нет. Что скорее всего не так?",
				en = "A player sees their own animation but nobody else does. What is most likely wrong?",
			},
			options = {
				{ ru = "Анимация проигрывается на Animator постороннего объекта, а не персонажа игрока", en = "The animation plays on some other object's Animator, not the player's character" },
				{ ru = "Слишком высокий приоритет", en = "The priority is too high" },
				{ ru = "Не задан Looped", en = "Looped is not set" },
				{ ru = "Анимация слишком длинная", en = "The animation is too long" },
			},
			answer = 1,
			explain = {
				ru = "Автоматически реплицируется только то, что клиент играет на Animator своего собственного персонажа. Локальные объекты и чужие модели не реплицируются.",
				en = "Only what a client plays on its own character's Animator replicates automatically. Local objects and other people's models do not.",
			},
		},
		keywords = { "replication", "репликация", "server", "client", "сервер", "клиент", "remoteevent", "exploit", "безопасность" },
	},

	--==================================================================
	-- MODULE 4
	--==================================================================

	{
		id = "4-1-ik",
		module = 4,
		minutes = 13,
		title = { ru = "Инверсная кинематика (IKControl)", en = "Inverse kinematics (IKControl)" },
		goal = {
			ru = "Заставить руку тянуться к предмету, а ноги — вставать на неровности.",
			en = "Make a hand reach an object and feet adapt to uneven ground.",
		},
		theory = {
			ru = {
				"Обычная (прямая) кинематика: вы задаёте угол плеча, потом локтя, потом кисти. Инверсная — наоборот: вы говорите «кисть должна быть ВОТ ЗДЕСЬ», а движок сам считает углы плеча и локтя.",
				"В Roblox для этого есть объект IKControl. Он кладётся внутрь Humanoid (или AnimationController) и работает поверх обычной анимации.",
				"Четыре обязательных свойства: Type (обычно Position или Transform), EndEffector (часть, которая тянется, например LeftHand), Target (куда тянется — любой объект с позицией, чаще Attachment), ChainRoot (где начинается цепочка суставов, например LeftUpperArm).",
				"ChainRoot определяет, сколько суставов участвует. LeftUpperArm — работает всё плечо с локтем; LeftLowerArm — только предплечье.",
				"Свойство Weight (0..1) позволяет плавно включать и выключать IK. Резкое включение с Weight = 1 выглядит как рывок; лучше нарастить его через TweenService.",
				"Без ограничений локоть может выгибаться в обратную сторону. Чтобы этого не было, добавляют HingeConstraint на локоть и BallSocketConstraint на кисть. Условие: аттачменты констрейнта должны совпадать по частям и по позициям с C0/C1 соответствующего Motor6D, а сам констрейнт должен лежать в той же модели.",
				"Типичные применения: руки на руле, ступни на лестнице и склоне, взгляд и рука, тянущаяся к движущейся цели.",
			},
			en = {
				"Forward kinematics: you set the shoulder angle, then the elbow, then the wrist. Inverse kinematics is the reverse: you say 'the hand must be HERE' and the engine solves the shoulder and elbow angles.",
				"Roblox provides the IKControl object for this. It is parented to the Humanoid (or AnimationController) and works on top of the regular animation.",
				"Four required properties: Type (usually Position or Transform), EndEffector (the part that reaches, e.g. LeftHand), Target (what it reaches for — any object with a world position, usually an Attachment) and ChainRoot (where the joint chain starts, e.g. LeftUpperArm).",
				"ChainRoot decides how many joints participate. LeftUpperArm involves the whole shoulder and elbow; LeftLowerArm only the forearm.",
				"The Weight property (0..1) lets you fade IK in and out. Snapping straight to Weight = 1 looks like a jolt; ramp it with TweenService instead.",
				"Without constraints an elbow can bend backwards. To prevent that, add a HingeConstraint at the elbow and a BallSocketConstraint at the wrist. The requirement: the constraint's attachments must sit on the same parts and at the same relative positions as the corresponding Motor6D C0/C1, and the constraint must share the model.",
				"Typical uses: hands on a steering wheel, feet on stairs and slopes, and a hand tracking a moving target.",
			},
		},
		steps = {
			ru = {
				"Запустите игру, найдите свою модель в Workspace и добавьте Attachment в HumanoidRootPart.",
				"Сдвиньте аттачмент вперёд от персонажа инструментом Move.",
				"Добавьте IKControl в Humanoid и заполните Type = Transform, EndEffector = LeftHand, Target = ваш Attachment, ChainRoot = LeftUpperArm.",
				"Двигайте аттачмент и наблюдайте, как рука следует за ним.",
				"Затем вставьте код этого урока, чтобы делать то же самое автоматически.",
			},
			en = {
				"Start a playtest, find your character model in the Workspace and add an Attachment to the HumanoidRootPart.",
				"Move the attachment in front of the character with the Move tool.",
				"Add an IKControl to the Humanoid and set Type = Transform, EndEffector = LeftHand, Target = your Attachment, ChainRoot = LeftUpperArm.",
				"Drag the attachment and watch the arm follow.",
				"Then insert this lesson's code to do the same automatically.",
			},
		},
		snippet = "ik-control",
		practice = {
			ru = "Сделайте так, чтобы левая рука персонажа всегда тянулась к движущейся части. Добавьте плавное включение IK через Weight от 0 до 1 за 0.3 секунды.",
			en = "Make the character's left hand always reach a moving part. Fade the IK in via Weight from 0 to 1 over 0.3 seconds.",
		},
		quiz = {
			question = {
				ru = "Какое свойство IKControl определяет, СКОЛЬКО суставов участвует в решении?",
				en = "Which IKControl property decides HOW MANY joints take part in the solve?",
			},
			options = {
				{ ru = "Target", en = "Target" },
				{ ru = "EndEffector", en = "EndEffector" },
				{ ru = "ChainRoot", en = "ChainRoot" },
				{ ru = "Weight", en = "Weight" },
			},
			answer = 3,
			explain = {
				ru = "ChainRoot задаёт начало цепочки. Все суставы между ChainRoot и EndEffector попадают под управление IK.",
				en = "ChainRoot sets the start of the chain. Every joint between ChainRoot and EndEffector is controlled by the IK solve.",
			},
		},
		keywords = { "ik", "ikcontrol", "инверсная кинематика", "endeffector", "chainroot", "constraint", "hingeconstraint" },
	},

	{
		id = "4-2-procedural",
		module = 4,
		minutes = 12,
		title = { ru = "Процедурная анимация поверх ключевых кадров", en = "Procedural animation on top of keyframes" },
		goal = {
			ru = "Добавлять живые детали кодом: поворот головы, покачивание, отдачу.",
			en = "Add living detail in code: head turning, sway, recoil.",
		},
		theory = {
			ru = {
				"Не всё стоит рисовать руками. Поворот головы за камерой, наклон в повороте, отдача оружия, дыхание — это функции от состояния игры, и их дешевле считать кодом.",
				"Механизм один: свойство Transform у Motor6D. Аниматор пишет туда позу каждый кадр, а вы можете дописать своё смещение ПОВЕРХ, если делаете это после расчёта анимации.",
				"Ключевой момент — порядок. Пишите в Transform внутри RunService.RenderStepped (клиент) или PreSimulation/Stepped, и умножайте на текущее значение: neck.Transform = myOffset * neck.Transform. Так вы добавляете смещение, а не стираете анимацию.",
				"Если присвоить neck.Transform = CFrame.Angles(...) без умножения, вы затрёте анимацию для этого сустава целиком. Иногда это именно то, что нужно, но чаще — нет.",
				"Всегда ограничивайте углы через math.clamp. Голова, повёрнутая на 180 градусов, ломает иллюзию мгновенно.",
				"Для плавности не ставьте целевое значение сразу — интерполируйте: current = current:Lerp(target, 0.2). Это дешёвый способ получить инерцию.",
				"У Animator есть свойство EvaluationThrottled: когда движок пропускает расчёт анимации для дальних персонажей, ваш процедурный код будет бороться с устаревшей позой. Проверяйте его и пропускайте кадр.",
				"Процедурная анимация — клиентская задача. Считать её на сервере для каждого игрока дорого и почти всегда не нужно.",
			},
			en = {
				"Not everything deserves hand-keyed animation. Head tracking, lean into turns, weapon recoil, breathing — these are functions of game state and are cheaper to compute.",
				"There is one mechanism: the Motor6D Transform property. The animator writes a pose there every frame, and you can add your own offset ON TOP as long as you do it after animation evaluation.",
				"Order is what matters. Write to Transform inside RunService.RenderStepped (client) or PreSimulation/Stepped, and multiply by the current value: neck.Transform = myOffset * neck.Transform. That adds an offset instead of erasing the animation.",
				"Assigning neck.Transform = CFrame.Angles(...) without multiplying wipes the animation for that joint entirely. Occasionally that is what you want, but usually not.",
				"Always clamp your angles with math.clamp. A head rotated 180 degrees destroys the illusion instantly.",
				"For smoothness do not jump to the target value — interpolate: current = current:Lerp(target, 0.2). It is a cheap way to get inertia.",
				"The Animator exposes EvaluationThrottled: when the engine skips animation evaluation for distant characters, your procedural code would fight a stale pose. Check it and skip the frame.",
				"Procedural animation is a client-side job. Computing it on the server for every player is expensive and almost never necessary.",
			},
		},
		steps = {
			ru = {
				"Вставьте пример этого урока в StarterCharacterScripts.",
				"Запустите игру и подвигайте камерой вверх-вниз — голова следует за ней.",
				"Замените присваивание на умножение и обратно, чтобы увидеть разницу с работающей анимацией.",
				"Добавьте math.clamp и Lerp для плавности.",
			},
			en = {
				"Insert this lesson's sample into StarterCharacterScripts.",
				"Run the game and move the camera up and down — the head follows.",
				"Switch between assignment and multiplication to see the difference against a playing animation.",
				"Add math.clamp and Lerp for smoothness.",
			},
		},
		snippet = "procedural-lookat",
		practice = {
			ru = "Сделайте поворот головы за камерой с ограничением ±40° по вертикали и ±60° по горизонтали, с плавным Lerp, работающий одновременно с анимацией ходьбы.",
			en = "Build camera head tracking clamped to ±40° vertically and ±60° horizontally, smoothed with Lerp, working alongside a walk animation.",
		},
		quiz = {
			question = {
				ru = "Вы пишете neck.Transform = CFrame.Angles(x, 0, 0) в RenderStepped, и анимация шеи из ключевых кадров пропадает. Как это исправить?",
				en = "You write neck.Transform = CFrame.Angles(x, 0, 0) in RenderStepped and the keyframed neck animation disappears. How do you fix it?",
			},
			options = {
				{ ru = "Уменьшить угол", en = "Reduce the angle" },
				{ ru = "Умножать на текущее значение: CFrame.Angles(x,0,0) * neck.Transform", en = "Multiply by the current value: CFrame.Angles(x,0,0) * neck.Transform" },
				{ ru = "Перенести код на сервер", en = "Move the code to the server" },
				{ ru = "Повысить приоритет анимации", en = "Raise the animation priority" },
			},
			answer = 2,
			explain = {
				ru = "Присваивание затирает позу, вычисленную аниматором. Умножение накладывает ваше смещение поверх неё.",
				en = "Assignment overwrites the pose the animator computed. Multiplication layers your offset on top of it.",
			},
		},
		keywords = { "procedural", "процедурная", "transform", "runservice", "renderstepped", "lerp", "поворот головы" },
	},

	{
		id = "4-3-optimization",
		module = 4,
		minutes = 11,
		title = { ru = "Оптимизация и отладка", en = "Optimization and debugging" },
		goal = {
			ru = "Убрать рывки, утечки треков и лаги на толпе персонажей; уметь искать причину.",
			en = "Remove hitches, track leaks and crowd lag; know how to find the cause.",
		},
		theory = {
			ru = {
				"Утечка треков — проблема №1. Каждый вызов LoadAnimation создаёт новый AnimationTrack. Если делать это в обработчике клика или в цикле, за минуту накопятся сотни треков. Загружайте один раз, храните в таблице.",
				"Рывок при первом проигрывании — ассет ещё не скачан. Лечится предзагрузкой: создайте объекты Animation заранее, вызовите animator:LoadAnimation() при старте и передайте список в ContentProvider:PreloadAsync().",
				"На толпе NPC движок сам снижает частоту расчёта дальних персонажей (LOD). Управляется свойством Animator.PreferLodEnabled (по умолчанию true) и настройкой Workspace.ClientAnimatorThrottlingMode. Отключайте LOD только для важных NPC — массовое отключение убивает производительность.",
				"Не держите десятки треков в состоянии Play с нулевым весом: они всё равно вычисляются. Останавливайте ненужные через Stop().",
				"Чек-лист «анимация не играет»: 1) track.Length == 0 → ассет не загрузился, проверьте ID и владельца; 2) играет, но не видно → приоритет ниже, чем у стандартных анимаций; 3) видно только вам → вы играете не на Animator своего персонажа; 4) замерла на первом кадре → Play() вызывается в цикле; 5) исчезла после смерти → нужен новый трек на новом Animator.",
				"Инструменты диагностики: animator:GetPlayingAnimationTracks() покажет всё, что сейчас активно (включая затухающие); animator:GetTrackByAnimationId(id) найдёт трек по ID без создания нового.",
				"Оборачивайте LoadAnimation в pcall, если ID приходит из данных: неверный ассет иначе уронит скрипт.",
				"В Studio полезны Microprofiler (F6) и вкладка Performance: секция Animation покажет реальную стоимость расчёта поз.",
			},
			en = {
				"Track leaks are problem number one. Every LoadAnimation call creates a new AnimationTrack. Do it inside a click handler or a loop and you accumulate hundreds within a minute. Load once and keep them in a table.",
				"A hitch on first play means the asset is not downloaded yet. Fix it with preloading: create the Animation objects up front, call animator:LoadAnimation() at startup and pass the list to ContentProvider:PreloadAsync().",
				"With crowds of NPCs the engine throttles evaluation for distant characters (LOD). It is governed by Animator.PreferLodEnabled (true by default) and Workspace.ClientAnimatorThrottlingMode. Disable LOD only for important NPCs — turning it off en masse destroys performance.",
				"Do not keep dozens of tracks playing at zero weight: they are still evaluated. Stop the ones you do not need.",
				"The 'animation is not playing' checklist: 1) track.Length == 0 → the asset did not load, check the ID and owner; 2) plays but is invisible → its priority is below the default animations; 3) only you see it → you are not playing on your own character's Animator; 4) frozen on frame one → Play() is being called in a loop; 5) gone after dying → you need a fresh track on the new Animator.",
				"Diagnostic tools: animator:GetPlayingAnimationTracks() lists everything currently active (including fading tracks); animator:GetTrackByAnimationId(id) finds a track by ID without creating a new one.",
				"Wrap LoadAnimation in pcall when the ID comes from data: a bad asset would otherwise kill the script.",
				"In Studio the Microprofiler (F6) and the Performance tab help: the Animation section shows the real cost of pose evaluation.",
			},
		},
		steps = {
			ru = {
				"Вставьте диагностический скрипт из этого урока и запустите с заведомо неверным ID — изучите вывод.",
				"Подставьте верный ID и сравните.",
				"Добавьте ContentProvider:PreloadAsync и убедитесь, что первый Play больше не дёргается.",
				"Выведите animator:GetPlayingAnimationTracks() во время игры и посмотрите, не копятся ли треки.",
			},
			en = {
				"Insert the diagnostic script from this lesson and run it with a deliberately wrong ID — study the output.",
				"Swap in the correct ID and compare.",
				"Add ContentProvider:PreloadAsync and confirm the first Play no longer hitches.",
				"Print animator:GetPlayingAnimationTracks() during play and check that tracks are not piling up.",
			},
		},
		snippet = "debug-checklist",
		practice = {
			ru = "Найдите в своём проекте место, где LoadAnimation вызывается больше одного раза для одной анимации, и перепишите его на кэш треков в таблице.",
			en = "Find a place in your project where LoadAnimation runs more than once for the same animation and rewrite it to cache tracks in a table.",
		},
		quiz = {
			question = {
				ru = "Игра начинает лагать после нескольких минут боя. В коде LoadAnimation вызывается внутри обработчика клика. В чём проблема?",
				en = "The game starts lagging after a few minutes of combat. LoadAnimation is called inside the click handler. What is wrong?",
			},
			options = {
				{ ru = "Анимация слишком длинная", en = "The animation is too long" },
				{ ru = "На каждый клик создаётся новый трек — они накапливаются", en = "Every click creates a new track — they accumulate" },
				{ ru = "Нужно повысить приоритет", en = "The priority needs raising" },
				{ ru = "Нужно отключить Looped", en = "Looped should be disabled" },
			},
			answer = 2,
			explain = {
				ru = "LoadAnimation должен вызываться один раз при инициализации. Внутри обработчика он плодит треки, которые продолжают вычисляться.",
				en = "LoadAnimation belongs in initialization. Inside a handler it spawns tracks that keep being evaluated.",
			},
		},
		keywords = { "оптимизация", "optimization", "preload", "lag", "лаг", "утечка", "leak", "microprofiler", "debug", "отладка" },
	},

	{
		id = "4-4-pipeline",
		module = 4,
		minutes = 10,
		title = { ru = "Внешние инструменты и рабочий процесс", en = "External tools and workflow" },
		goal = {
			ru = "Понимать, когда хватит встроенного редактора, а когда нужны Blender, Moon Animator или mocap.",
			en = "Know when the built-in editor is enough and when to reach for Blender, Moon Animator or mocap.",
		},
		theory = {
			ru = {
				"Встроенный Animation Editor полностью закрывает большинство задач: idle, ходьба, атаки, эмоции. Начинать всегда стоит с него — не нужно усложнять.",
				"Moon Animator — популярный сторонний плагин. Его сильные стороны: анимация нескольких персонажей и объектов в одной сцене, работа с камерой, более удобный график-редактор. Логика та же: на выходе получается обычный ассет анимации с ID.",
				"Blender нужен, когда вы работаете со скиннированными мешами (skinned mesh) — моделями с костями (Bone) и мягкой деформацией вместо жёстких частей. Пайплайн: риг и анимация в Blender → экспорт FBX → импорт в Studio через Avatar → 3D Importer / Import Animation.",
				"При импорте FBX важно совпадение имён костей и масштаба. Roblox использует свою систему единиц, поэтому масштаб почти всегда приходится проверять вручную.",
				"Skinned mesh отличается от обычного рига: там Bone вместо Motor6D, и деформация плавная. Для органики (существа, ткань) это единственный нормальный путь.",
				"Animation Capture (вкладка Avatar) позволяет записать движение лица или тела через веб-камеру прямо в Studio. Быстро для черновика и мимики, но результат почти всегда требует ручной чистки ключей.",
				"Практический совет по процессу: сначала блокинг (грубые ключевые позы с Constant easing), потом тайминг (двигаете ключи), и только потом полировка (easing, кривые, детали). Полировать до того, как утверждён тайминг, — это выброшенное время.",
				"Держите библиотеку: папка в ServerStorage или ModuleScript с таблицей всех ID анимаций. Разбросанные по коду rbxassetid — гарантированная боль при обновлении.",
			},
			en = {
				"The built-in Animation Editor covers most of what you need: idles, walks, attacks, emotes. Always start there — do not over-engineer.",
				"Moon Animator is a popular third-party plugin. Its strengths: animating several characters and props in one scene, camera work and a nicer graph editor. The logic is the same: the output is an ordinary animation asset with an ID.",
				"Blender becomes necessary for skinned meshes — models with Bones and soft deformation instead of rigid parts. The pipeline: rig and animate in Blender → export FBX → import into Studio via Avatar → 3D Importer / Import Animation.",
				"When importing FBX, bone names and scale must line up. Roblox uses its own unit system, so scale nearly always needs a manual check.",
				"A skinned mesh differs from a part rig: it uses Bone instead of Motor6D and deforms smoothly. For organic subjects (creatures, cloth) it is the only sane route.",
				"Animation Capture (the Avatar tab) records face or body motion from a webcam directly in Studio. It is fast for blocking and facial work, but the result almost always needs manual key cleanup.",
				"Process advice: block first (rough key poses with Constant easing), then time it (slide the keys), and only then polish (easing, curves, detail). Polishing before the timing is approved is wasted work.",
				"Keep a library: a folder in ServerStorage or a ModuleScript holding a table of every animation ID. rbxassetid strings scattered through your code guarantee pain later.",
			},
		},
		steps = {
			ru = {
				"Создайте ModuleScript в ReplicatedStorage с таблицей ID всех ваших анимаций.",
				"Перепишите один из прошлых скриптов так, чтобы он брал ID оттуда.",
				"Откройте Avatar → Animation Capture и попробуйте записать мимику (если есть камера).",
				"Если работаете с мешами — попробуйте импортировать простой FBX через 3D Importer.",
			},
			en = {
				"Create a ModuleScript in ReplicatedStorage holding a table of all your animation IDs.",
				"Rewrite one of your earlier scripts to read IDs from it.",
				"Open Avatar → Animation Capture and try recording facial motion (if you have a camera).",
				"If you work with meshes, try importing a simple FBX through the 3D Importer.",
			},
		},
		practice = {
			ru = "Создайте ModuleScript AnimationIds с таблицей вида { Idle = \"rbxassetid://...\", Attack = ... } и переведите на него все свои скрипты из курса.",
			en = "Create an AnimationIds ModuleScript with a table like { Idle = \"rbxassetid://...\", Attack = ... } and migrate every script from the course to use it.",
		},
		quiz = {
			question = {
				ru = "Вам нужно анимировать существо с плавной деформацией тела, а не набор жёстких частей. Что использовать?",
				en = "You need to animate a creature with smooth body deformation rather than rigid parts. What do you use?",
			},
			options = {
				{ ru = "Motor6D и встроенный редактор", en = "Motor6D and the built-in editor" },
				{ ru = "Skinned mesh с костями (Bone), сделанный в Blender", en = "A skinned mesh with Bones, authored in Blender" },
				{ ru = "IKControl", en = "IKControl" },
				{ ru = "Animation Events", en = "Animation Events" },
			},
			answer = 2,
			explain = {
				ru = "Плавная деформация — это скиннинг. Нужны кости (Bone) и меш, подготовленный во внешнем редакторе, обычно в Blender.",
				en = "Smooth deformation means skinning. That requires Bones and a mesh prepared in an external tool, usually Blender.",
			},
		},
		keywords = { "blender", "moon animator", "fbx", "импорт", "skinned mesh", "bone", "mocap", "capture", "пайплайн" },
	},
}

Lessons.byId = {}
for index, lesson in ipairs(Lessons.list) do
	lesson.index = index
	Lessons.byId[lesson.id] = lesson
end

function Lessons.get(id)
	return Lessons.byId[id]
end

function Lessons.count()
	return #Lessons.list
end

function Lessons.inModule(moduleId)
	local out = {}
	for _, lesson in ipairs(Lessons.list) do
		if lesson.module == moduleId then
			out[#out + 1] = lesson
		end
	end
	return out
end

function Lessons.next(id)
	local lesson = Lessons.byId[id]
	if not lesson then
		return Lessons.list[1]
	end
	return Lessons.list[lesson.index + 1]
end

return Lessons
