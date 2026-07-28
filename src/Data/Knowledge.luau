--[[
	Data/Knowledge
	The offline Q&A base. Each entry answers one real question a learner asks.

	Matching is done by Brain/Answer against:
	  concepts  - concept ids from Brain/Text (cross-language)
	  must      - optional: at least one of these concepts must be present
	  patterns  - literal substrings (either language) worth a strong boost
	  keywords  - extra plain words, stemmed at match time

	`answer` is bilingual and written as plain paragraphs. `snippet` and
	`lesson` let the tutor offer a follow-up action.
]]

local Knowledge = {}

Knowledge.entries = {

	{
		id = "kb-not-playing",
		concepts = { "notworking", "animation", "play" },
		must = { "notworking" },
		patterns = { "не работает", "не играет", "не проигрывается", "ничего не происходит",
			"not working", "not playing", "doesn't play", "does not play", "nothing happens" },
		title = { ru = "Анимация не проигрывается — полная диагностика", en = "Animation does not play — full diagnosis" },
		answer = {
			ru = {
				"Проверяйте по порядку, это закрывает почти все случаи:",
				"1. Выведите print(track.Length) сразу после LoadAnimation. Если 0 — ассет не загрузился. Причина почти всегда одна: анимация опубликована не от того владельца. Если игра принадлежит группе, анимация тоже должна быть опубликована от группы.",
				"2. Проверьте формат ID: должно быть \"rbxassetid://123456\", а не просто число и не ссылка на страницу каталога.",
				"3. Если Length нормальная, а движения нет — дело в приоритете. Поставьте track.Priority = Enum.AnimationPriority.Action: стандартные ходьба и idle работают на Movement/Idle и перекрывают вашу анимацию.",
				"4. Убедитесь, что вы используете animator:LoadAnimation(), а не устаревший humanoid:LoadAnimation().",
				"5. Если анимация замерла на первом кадре — где-то Play() вызывается в цикле и перезапускает трек каждый кадр.",
				"6. Если перестала играть после смерти персонажа — после респавна создаётся новый Animator, трек нужно загрузить заново в CharacterAdded.",
				"7. Совпадает ли тип рига? Анимация для R15 не будет работать на R6.",
			},
			en = {
				"Work through these in order; they cover nearly every case:",
				"1. print(track.Length) right after LoadAnimation. If it is 0 the asset never loaded. The cause is almost always ownership: if the experience belongs to a group, the animation must be published under that group too.",
				"2. Check the ID format: it must be \"rbxassetid://123456\", not a bare number and not a catalog page URL.",
				"3. If Length looks right but nothing moves, it is priority. Set track.Priority = Enum.AnimationPriority.Action — the default walk and idle run at Movement/Idle and override yours.",
				"4. Make sure you call animator:LoadAnimation(), not the deprecated humanoid:LoadAnimation().",
				"5. If it is frozen on the first frame, Play() is being called in a loop and restarting the track every frame.",
				"6. If it stopped after dying, respawning creates a new Animator — reload the track inside CharacterAdded.",
				"7. Do the rig types match? An R15 animation will not run on R6.",
			},
		},
		snippet = "debug-checklist",
		lesson = "4-3-optimization",
	},

	{
		id = "kb-how-to-play",
		concepts = { "animation", "play", "script" },
		must = { "play" },
		patterns = { "как проиграть", "как запустить анимацию", "как воспроизвести", "how to play", "how do i play" },
		title = { ru = "Как проиграть анимацию из скрипта", en = "How to play an animation from a script" },
		answer = {
			ru = {
				"Цепочка всегда одинаковая: Animation → Animator:LoadAnimation() → AnimationTrack → :Play().",
				"Animator лежит внутри Humanoid, поэтому его надо дождаться: local animator = humanoid:WaitForChild(\"Animator\").",
				"Загружайте трек ОДИН раз при инициализации, а не при каждом нажатии — иначе треки накапливаются и игра начинает лагать.",
				"Для действий игрока используйте LocalScript: так отклик мгновенный, и Roblox сам покажет анимацию остальным игрокам.",
				"Не забудьте выставить приоритет: track.Priority = Enum.AnimationPriority.Action.",
			},
			en = {
				"The chain is always the same: Animation → Animator:LoadAnimation() → AnimationTrack → :Play().",
				"The Animator lives inside the Humanoid, so wait for it: local animator = humanoid:WaitForChild(\"Animator\").",
				"Load the track ONCE during initialization, not on every press — otherwise tracks pile up and the game starts to lag.",
				"For player actions use a LocalScript: the response is instant and Roblox replicates it to everyone else for you.",
				"Remember the priority: track.Priority = Enum.AnimationPriority.Action.",
			},
		},
		snippet = "play-basic",
		lesson = "2-1-animator-track",
	},

	{
		id = "kb-priority",
		concepts = { "priority" },
		patterns = { "приоритет", "priority", "перекрывает", "overrides" },
		title = { ru = "Приоритеты анимаций", en = "Animation priorities" },
		answer = {
			ru = {
				"Шкала от низшего к высшему: Core → Idle → Movement → Action → Action2 → Action3 → Action4.",
				"Когда два трека двигают один и тот же сустав, побеждает тот, у кого приоритет выше. Это перекрытие, а не смешивание.",
				"Стандартные ходьба и бег работают на Movement, стандартный idle — на Idle. Поэтому любое ваше действие (удар, эмоция) ставьте минимум на Action, иначе его не будет видно при движении.",
				"Задать можно в редакторе анимаций (сохранится в ассете) или в коде: track.Priority = Enum.AnimationPriority.Action. Код имеет приоритет над настройкой ассета.",
				"Если нужно, чтобы два трека СМЕШИВАЛИСЬ, а не перекрывали друг друга, дайте им одинаковый приоритет и управляйте весами через AdjustWeight.",
			},
			en = {
				"The scale from lowest to highest: Core → Idle → Movement → Action → Action2 → Action3 → Action4.",
				"When two tracks drive the same joint, the higher priority wins. That is overriding, not blending.",
				"The default walk and run sit at Movement and the default idle at Idle. So any action of yours (a hit, an emote) needs at least Action or it will be invisible while moving.",
				"Set it in the Animation Editor (baked into the asset) or in code: track.Priority = Enum.AnimationPriority.Action. Code wins over the asset setting.",
				"If you want two tracks to BLEND instead of override, give them the same priority and drive AdjustWeight.",
			},
		},
		lesson = "2-2-priority-looped",
	},

	{
		id = "kb-replication",
		concepts = { "replication" },
		patterns = { "не видят", "другие игроки", "видно только мне", "other players", "only i can see", "replicate" },
		title = { ru = "Другие игроки не видят анимацию", en = "Other players cannot see the animation" },
		answer = {
			ru = {
				"Главное правило: если клиент проигрывает анимацию через Animator СВОЕГО персонажа, Roblox реплицирует её всем автоматически. Пересылать через RemoteEvent ничего не надо.",
				"Если видно только вам — скорее всего, вы играете анимацию на Animator объекта, который существует только на клиенте, или на чужой модели.",
				"Для NPC всё наоборот: их персонажем владеет сервер, поэтому анимации NPC надо запускать серверным Script, иначе их увидит только один клиент.",
				"Про безопасность: никогда не принимайте AnimationId от клиента через RemoteEvent. Эксплойтер пришлёт что угодно. Сервер должен сам знать список разрешённых анимаций.",
				"Правильная схема боя: клиент играет анимацию локально (мгновенный отклик) и сообщает серверу факт действия; сервер проверяет кулдаун и наносит урон.",
			},
			en = {
				"The core rule: when a client plays an animation through ITS OWN character's Animator, Roblox replicates it to everyone automatically. There is nothing to forward over a RemoteEvent.",
				"If only you can see it, you are probably playing on the Animator of an object that exists only on the client, or on someone else's model.",
				"For NPCs it is reversed: the server owns their characters, so NPC animations must be started from a server Script or only one client will see them.",
				"On security: never accept an AnimationId from the client over a RemoteEvent. An exploiter will send anything. The server must own the list of allowed animations.",
				"The correct combat pattern: the client plays locally (instant feedback) and reports the action; the server validates the cooldown and applies damage.",
			},
		},
		snippet = "replicated-attack",
		lesson = "3-3-replication",
	},

	{
		id = "kb-r6-r15",
		concepts = { "r6", "r15", "rig" },
		patterns = { "r6 или r15", "разница между r6", "r6 vs r15", "какой риг" },
		title = { ru = "R6 или R15: что выбрать", en = "R6 or R15: which to choose" },
		answer = {
			ru = {
				"R6 — 6 частей и 5 суставов (Neck, два Shoulder, два Hip). Простой, стилизованный, дешёвый по производительности, анимировать быстро. Нет локтей и коленей, поэтому движения угловатые.",
				"R15 — 15 частей и 14 суставов: есть локти, колени, кисти, стопы и разделённый торс (UpperTorso / LowerTorso). Движения гораздо естественнее, работает IK, поддерживаются слоистые одежда и аксессуары.",
				"Анимации между ригами НЕ переносятся: имена суставов разные. Определитесь до начала работы.",
				"Тип рига задаётся в настройках игры: Game Settings → Avatar → Avatar Type (R6 / R15 / Player Choice).",
				"Практический совет: для новых проектов берите R15 — это стандарт платформы, под него больше готовых ассетов и он поддерживает современные фичи вроде IKControl и skinned mesh.",
			},
			en = {
				"R6 — 6 parts and 5 joints (Neck, two Shoulders, two Hips). Simple, stylized, cheap to run, fast to animate. No elbows or knees, so motion is blocky.",
				"R15 — 15 parts and 14 joints: elbows, knees, hands, feet and a split torso (UpperTorso / LowerTorso). Motion is far more natural, IK works, and layered clothing and accessories are supported.",
				"Animations do NOT transfer between rigs: the joint names differ. Decide before you start.",
				"The rig type is a place setting: Game Settings → Avatar → Avatar Type (R6 / R15 / Player Choice).",
				"Practical advice: use R15 for new projects — it is the platform standard, has more ready-made assets and supports modern features like IKControl and skinned meshes.",
			},
		},
		lesson = "1-1-what-is-animation",
	},

	{
		id = "kb-export",
		concepts = { "export", "assetid" },
		patterns = { "как экспортировать", "как опубликовать", "получить id", "how to export", "how to publish", "get the id" },
		title = { ru = "Экспорт анимации и получение ID", en = "Exporting an animation and getting its ID" },
		answer = {
			ru = {
				"В редакторе анимаций нажмите меню «...» (три точки) → Publish to Roblox. Укажите имя и описание.",
				"Ключевой момент — поле Creator в диалоге публикации. Владелец анимации должен совпадать с владельцем игры. Игра в группе → публикуйте анимацию от группы.",
				"После публикации ID берётся из того же меню (Copy Asset ID) или в Creator Dashboard → Development Items → Animations.",
				"В коде используйте полный формат: animation.AnimationId = \"rbxassetid://123456789\".",
				"Если вы переделали анимацию — публикуйте её ПОВЕРХ существующего ассета (Overwrite). Тогда ID не изменится и скрипты трогать не придётся.",
			},
			en = {
				"In the Animation Editor open the \"...\" menu → Publish to Roblox. Give it a name and description.",
				"The critical field is Creator in the publish dialog. The animation's owner must match the game's owner. Game in a group → publish the animation under that group.",
				"Afterwards grab the ID from the same menu (Copy Asset ID) or from Creator Dashboard → Development Items → Animations.",
				"In code use the full form: animation.AnimationId = \"rbxassetid://123456789\".",
				"If you rework the animation, publish it OVER the existing asset (Overwrite). The ID stays the same and no script changes are needed.",
			},
		},
		lesson = "1-5-export-publish",
	},

	{
		id = "kb-loop",
		concepts = { "looped" },
		patterns = { "зациклить", "цикл", "дёргается", "рывок при повторе", "loop", "looping", "pops" },
		title = { ru = "Зацикливание и рывок при повторе", en = "Looping and the pop at the wrap" },
		answer = {
			ru = {
				"Включить цикл: track.Looped = true в скрипте, либо галочка Loop в редакторе (сохраняется в ассете).",
				"Если в момент повтора виден рывок — первый и последний кадры не совпадают. Скопируйте первый кадр и вставьте его в самый конец таймлайна.",
				"Второй источник рывка — разное значение easing на стыке. Проверьте, что последний ключ не тормозит движение, если цикл должен быть непрерывным (например, у бега).",
				"Для одноразовых действий Looped обязательно должен быть false, иначе трек никогда не завершится и события Ended / Stopped не сработают.",
				"Чтобы дождаться конца одноразовой анимации: track.Stopped:Wait() или подписка на track.Ended.",
			},
			en = {
				"Enable looping with track.Looped = true in a script, or the Loop checkbox in the editor (stored in the asset).",
				"If you see a pop at the wrap, the first and last frames do not match. Copy the first keyframe and paste it at the very end of the timeline.",
				"The second cause is mismatched easing at the seam. Make sure the last key does not decelerate if the cycle must stay continuous (a run, for example).",
				"For one-shot actions Looped must be false, otherwise the track never finishes and the Ended / Stopped events never fire.",
				"To wait for a one-shot animation: track.Stopped:Wait() or connect to track.Ended.",
			},
		},
		lesson = "2-2-priority-looped",
	},

	{
		id = "kb-blend",
		concepts = { "weight", "animation" },
		patterns = { "смешать", "смешива", "плавный переход", "блендинг",
			"blend animation", "smooth transition", "adjustweight" },
		title = { ru = "Смешивание анимаций (веса)", en = "Blending animations (weights)" },
		answer = {
			ru = {
				"Смешивание работает только между треками с ОДИНАКОВЫМ приоритетом. При разном приоритете старший просто перекрывает младшего.",
				"Итоговая поза — взвешенное среднее всех играющих поз. Вес по умолчанию 1.",
				"AdjustWeight(weight, fadeTime) меняет вес плавно за fadeTime секунд: WeightCurrent едет к WeightTarget. Всегда давайте fadeTime хотя бы 0.1.",
				"Классический приём «ходьба → бег»: оба трека на Movement, оба играют, и вы считаете alpha от скорости персонажа. walk:AdjustWeight(1 - alpha), run:AdjustWeight(alpha).",
				"Чтобы ноги не «скользили», синхронизируйте темп: track:AdjustSpeed(humanoid.WalkSpeed / BASE_SPEED), где BASE_SPEED — скорость, под которую рисовалась анимация.",
			},
			en = {
				"Blending only happens between tracks at the SAME priority. With different priorities the higher one simply overrides.",
				"The result is the weighted average of every playing pose. The default weight is 1.",
				"AdjustWeight(weight, fadeTime) ramps the weight over fadeTime seconds: WeightCurrent glides to WeightTarget. Always pass at least 0.1.",
				"The classic walk → run recipe: both tracks on Movement, both playing, and you compute alpha from the character's speed. walk:AdjustWeight(1 - alpha), run:AdjustWeight(alpha).",
				"To stop foot sliding, sync the tempo: track:AdjustSpeed(humanoid.WalkSpeed / BASE_SPEED), where BASE_SPEED is the speed the animation was authored for.",
			},
		},
		snippet = "blend-weights",
		lesson = "2-4-weight-speed",
	},

	{
		id = "kb-events",
		concepts = { "event" },
		patterns = { "маркер", "событие анимации", "getmarkerreachedsignal", "animation event", "marker" },
		title = { ru = "События и маркеры анимации", en = "Animation events and markers" },
		answer = {
			ru = {
				"Маркеры нужны, чтобы привязать код к конкретному кадру: момент касания при ударе, момент шага, вылет снаряда.",
				"Создание: в редакторе включите Show Animation Events (шестерёнка справа от таймлайна), поставьте скраббер на кадр, Edit Animation Events → + Add Event, введите имя.",
				"В коде: track:GetMarkerReachedSignal(\"HitFrame\"):Connect(function(param) ... end). Имя должно совпадать точно, с учётом регистра.",
				"Поле Parameter передаёт произвольную строку в обработчик — удобно для урона (\"20\") или уточнений (\"left,heavy\").",
				"Почему это лучше task.wait(): маркер живёт внутри анимации. Поменяли тайминг — момент срабатывания сдвинулся вместе с ним, код править не нужно.",
				"После добавления или изменения маркеров анимацию нужно опубликовать заново поверх старого ассета.",
			},
			en = {
				"Markers bind code to a specific frame: the contact moment of a punch, a footstep, a projectile release.",
				"To create: enable Show Animation Events in the editor (the gear right of the timeline), place the scrubber, Edit Animation Events → + Add Event, type a name.",
				"In code: track:GetMarkerReachedSignal(\"HitFrame\"):Connect(function(param) ... end). The name must match exactly, case included.",
				"The Parameter field passes an arbitrary string to the handler — handy for damage (\"20\") or details (\"left,heavy\").",
				"Why this beats task.wait(): the marker lives inside the animation. Change the timing and the trigger moves with it — no code edits.",
				"After adding or editing markers you must republish the animation over the existing asset.",
			},
		},
		snippet = "events-markers",
		lesson = "2-3-events",
	},

	{
		id = "kb-non-humanoid",
		concepts = { "animationcontroller", "animation" },
		patterns = { "без humanoid", "без гуманоида", "дверь", "двери", "non-humanoid",
			"without humanoid", "animate a door", "animate a vehicle", "анимировать дверь",
			"анимация двери", "машину", "корабль" },
		title = { ru = "Анимация модели без Humanoid", en = "Animating a model without a Humanoid" },
		answer = {
			ru = {
				"Animator должен где-то жить. Нет Humanoid — создайте AnimationController и положите Animator внутрь него: Model → AnimationController → Animator.",
				"Дальше всё как обычно: animator:LoadAnimation(animation), track:Play().",
				"Уточнение: сам класс AnimationController не устарел, устарел только его метод LoadAnimation. Контроллер создавайте, а грузите через Animator.",
				"Модель обязана быть ригом: части соединены Motor6D, задан PrimaryPart. Без Motor6D редактор анимаций не покажет дорожек.",
				"Якорить нужно ТОЛЬКО корневую часть. Все остальные — Anchored = false, иначе суставы не смогут их двигать. CanCollide у движущихся частей лучше выключить.",
			},
			en = {
				"The Animator needs a home. No Humanoid — create an AnimationController and put the Animator inside it: Model → AnimationController → Animator.",
				"From there it is business as usual: animator:LoadAnimation(animation), track:Play().",
				"To be precise: the AnimationController class is not deprecated, only its LoadAnimation method is. Create the controller but load through the Animator.",
				"The model must be a rig: parts connected by Motor6D with a PrimaryPart set. Without Motor6D the editor shows no tracks.",
				"Anchor ONLY the root part. Everything else must be Anchored = false or the joints cannot move it. Turn CanCollide off on moving parts.",
			},
		},
		snippet = "non-humanoid",
		lesson = "3-1-non-humanoid",
	},

	{
		id = "kb-tool",
		concepts = { "tool" },
		patterns = { "анимация инструмента", "анимация оружия", "меч", "tool animation", "weapon animation" },
		title = { ru = "Анимация инструмента (Tool)", en = "Animating a Tool" },
		answer = {
			ru = {
				"Анимируется не сам Tool, а ПЕРСОНАЖ, который его держит. Трек грузится на Animator персонажа.",
				"Чтобы оружие двигалось с рукой, Handle должен быть присоединён: обычно через RightGrip, который Roblox создаёт автоматически при Equipped, либо через собственный Motor6D для полного контроля.",
				"Жизненный цикл: Equipped → загрузить и запустить idle-трек; Activated → проиграть удар; Unequipped → ОБЯЗАТЕЛЬНО остановить все треки, иначе поза зависнет.",
				"Приоритеты: idle инструмента — Enum.AnimationPriority.Idle, атака — Action. Тогда атака перекрывает удержание.",
				"Скрипт удобнее делать LocalScript внутри Tool: отклик мгновенный, а репликация произойдёт автоматически.",
			},
			en = {
				"You do not animate the Tool — you animate the CHARACTER holding it. The track loads onto the character's Animator.",
				"For the weapon to follow the hand the Handle must be attached: usually via RightGrip, which Roblox creates automatically on Equipped, or via your own Motor6D for full control.",
				"Lifecycle: Equipped → load and start the idle track; Activated → play the swing; Unequipped → you MUST stop every track or the pose sticks.",
				"Priorities: the tool idle on Enum.AnimationPriority.Idle, the attack on Action. The attack then overrides the hold.",
				"A LocalScript inside the Tool is the convenient choice: instant response and automatic replication.",
			},
		},
		snippet = "tool-animation",
		lesson = "3-2-tools-npc",
	},

	{
		id = "kb-ik",
		concepts = { "ik" },
		patterns = { "ikcontrol", "инверсная кинематика", "inverse kinematics", "рука тянется", "reach for" },
		title = { ru = "IKControl: инверсная кинематика", en = "IKControl: inverse kinematics" },
		answer = {
			ru = {
				"IKControl позволяет задать «где должна быть кисть», а движок сам посчитает углы плеча и локтя. Работает поверх обычной анимации.",
				"Кладётся внутрь Humanoid (или AnimationController). Обязательные свойства: Type (Position или Transform), EndEffector (например LeftHand), Target (объект с позицией, чаще Attachment), ChainRoot (например LeftUpperArm).",
				"ChainRoot определяет длину цепочки: LeftUpperArm — плечо и локоть, LeftLowerArm — только предплечье.",
				"Weight (0..1) нужен для плавного включения. Резкое Weight = 1 выглядит как рывок — нарастите его через TweenService.",
				"Чтобы локоть не выгибался в обратную сторону, добавьте HingeConstraint. Условие: аттачменты констрейнта должны стоять на тех же частях и в тех же относительных позициях, что C0/C1 у Motor6D, а констрейнт — лежать в той же модели.",
			},
			en = {
				"IKControl lets you state 'where the hand must be' and the engine solves the shoulder and elbow angles. It works on top of regular animation.",
				"Parent it to the Humanoid (or AnimationController). Required properties: Type (Position or Transform), EndEffector (e.g. LeftHand), Target (any object with a world position, usually an Attachment) and ChainRoot (e.g. LeftUpperArm).",
				"ChainRoot sets the chain length: LeftUpperArm covers shoulder and elbow, LeftLowerArm only the forearm.",
				"Weight (0..1) exists for fading in. Snapping to 1 looks like a jolt — ramp it with TweenService.",
				"To stop the elbow bending backwards, add a HingeConstraint. Requirement: the constraint's attachments must sit on the same parts and at the same relative positions as the Motor6D C0/C1, and the constraint must share the model.",
			},
		},
		snippet = "ik-control",
		lesson = "4-1-ik",
	},

	{
		id = "kb-procedural",
		concepts = { "procedural" },
		patterns = { "процедурная анимация", "поворот головы", "отдача", "procedural", "head look", "recoil" },
		title = { ru = "Процедурная анимация поверх ключевых кадров", en = "Procedural animation over keyframes" },
		answer = {
			ru = {
				"Механизм один: свойство Transform у Motor6D. Аниматор пишет туда позу каждый кадр, а вы добавляете своё смещение поверх.",
				"Ключевое правило — УМНОЖАЙТЕ, а не присваивайте: neck.Transform = myOffset * neck.Transform. Простое присваивание сотрёт анимацию для этого сустава.",
				"Делать это надо в RunService.RenderStepped (на клиенте) или PreSimulation — то есть после расчёта анимации.",
				"Всегда ограничивайте углы через math.clamp и сглаживайте через Lerp: current = current:Lerp(target, 0.2). Так появляется инерция.",
				"У Animator есть EvaluationThrottled: если движок пропустил расчёт для дальнего персонажа, ваш код будет бороться с устаревшей позой. Проверьте флаг и пропустите кадр.",
				"Считайте процедурную анимацию на клиенте: на сервере для каждого игрока это дорого и почти всегда не нужно.",
			},
			en = {
				"There is one mechanism: the Motor6D Transform property. The animator writes a pose there each frame and you add your offset on top.",
				"The key rule is MULTIPLY, do not assign: neck.Transform = myOffset * neck.Transform. A plain assignment erases the animation for that joint.",
				"Do it inside RunService.RenderStepped (on the client) or PreSimulation — that is, after animation evaluation.",
				"Always clamp with math.clamp and smooth with Lerp: current = current:Lerp(target, 0.2). That is where inertia comes from.",
				"The Animator exposes EvaluationThrottled: if the engine skipped evaluation for a distant character your code fights a stale pose. Check the flag and skip the frame.",
				"Compute procedural animation on the client: doing it server-side per player is expensive and rarely necessary.",
			},
		},
		snippet = "procedural-lookat",
		lesson = "4-2-procedural",
	},

	{
		id = "kb-optimization",
		concepts = { "optimization" },
		patterns = { "лагает", "тормозит", "оптимизировать", "рывок при первом", "lag", "stutter", "optimize" },
		title = { ru = "Оптимизация анимаций", en = "Animation optimization" },
		answer = {
			ru = {
				"Утечка треков — причина №1. Каждый LoadAnimation создаёт новый AnimationTrack. Вызов внутри обработчика клика за минуту накопит сотни треков. Загружайте один раз и кэшируйте в таблице.",
				"Рывок при первом проигрывании — ассет ещё не скачан. Создайте объекты Animation заранее, вызовите LoadAnimation при старте и передайте список в ContentProvider:PreloadAsync().",
				"На толпе NPC движок сам снижает частоту расчёта дальних персонажей. Это Animator.PreferLodEnabled (по умолчанию true) и Workspace.ClientAnimatorThrottlingMode. Отключайте LOD только для важных NPC.",
				"Не держите неиспользуемые треки играющими с нулевым весом — они всё равно вычисляются. Останавливайте их через Stop().",
				"Диагностика: animator:GetPlayingAnimationTracks() покажет всё активное, включая затухающие треки. Microprofiler (F6) покажет реальную стоимость расчёта поз.",
			},
			en = {
				"Track leaks are cause number one. Every LoadAnimation creates a new AnimationTrack. Calling it inside a click handler accumulates hundreds within a minute. Load once and cache in a table.",
				"A hitch on first play means the asset is not downloaded. Create the Animation objects up front, call LoadAnimation at startup and pass the list to ContentProvider:PreloadAsync().",
				"With NPC crowds the engine throttles evaluation for distant characters. That is Animator.PreferLodEnabled (true by default) and Workspace.ClientAnimatorThrottlingMode. Disable LOD only for important NPCs.",
				"Do not leave unused tracks playing at zero weight — they are still evaluated. Stop them.",
				"Diagnostics: animator:GetPlayingAnimationTracks() lists everything active including fading tracks. The Microprofiler (F6) shows the real cost of pose evaluation.",
			},
		},
		snippet = "preload",
		lesson = "4-3-optimization",
	},

	{
		id = "kb-deprecated",
		concepts = { "deprecated", "loadanimation" },
		patterns = { "deprecated", "устарел", "humanoid:loadanimation" },
		title = { ru = "Что устарело в API анимаций", en = "What is deprecated in the animation API" },
		answer = {
			ru = {
				"Humanoid:LoadAnimation() — устарел. Замена: animator:LoadAnimation(), где animator = humanoid:WaitForChild(\"Animator\").",
				"AnimationController:LoadAnimation() — тоже устарел. Сам класс AnimationController использовать МОЖНО и нужно (для моделей без Humanoid), но грузить анимацию надо через дочерний Animator.",
				"Функция wait() и spawn() считаются устаревшими в пользу task.wait() и task.spawn().",
				"KeyframeReached — работает, но для событий предпочтительнее GetMarkerReachedSignal(): он срабатывает только на нужный маркер и не требует фильтрации по имени.",
				"Если вы смотрите туториал старше 2021 года, скорее всего там humanoid:LoadAnimation — это главная причина, почему код из видео не работает.",
			},
			en = {
				"Humanoid:LoadAnimation() is deprecated. Use animator:LoadAnimation(), where animator = humanoid:WaitForChild(\"Animator\").",
				"AnimationController:LoadAnimation() is also deprecated. The AnimationController class itself is fine and necessary (for Humanoid-less models), but load through its child Animator.",
				"wait() and spawn() are discouraged in favour of task.wait() and task.spawn().",
				"KeyframeReached still works, but GetMarkerReachedSignal() is preferred: it fires only for the marker you asked for and needs no name filtering.",
				"If you are following a tutorial older than 2021 it almost certainly uses humanoid:LoadAnimation — that is the main reason the video's code fails.",
			},
		},
		lesson = "2-1-animator-track",
	},

	{
		id = "kb-easing",
		concepts = { "curve" },
		patterns = { "easing", "плавность", "кривые", "curve editor", "интерполяц" },
		title = { ru = "Easing и кривые: как сделать движение живым", en = "Easing and curves: making motion feel alive" },
		answer = {
			ru = {
				"Easing — это свойство КЛЮЧЕВОГО КАДРА, а не всей анимации. Оно задаёт форму перехода к следующему ключу.",
				"Easing Style: Linear (механически), Sine (мягко, хороший выбор по умолчанию), Quad/Cubic (сильнее разгон), Back (перелёт), Elastic (пружина), Bounce (отскок), Constant (мгновенный скачок без интерполяции).",
				"Easing Direction: In (медленно в начале), Out (медленно в конце), InOut (медленно с обеих сторон).",
				"Главный приём живой анимации — slow in / slow out: тела не стартуют и не останавливаются мгновенно. Для большинства человеческих движений Sine + InOut уже даёт отличный результат.",
				"Curve Editor нужен, когда пресетов мало: там видно значения как графики и можно двигать касательные руками. Например, резкий удар с долгим затуханием.",
				"Задать easing: правый клик по ключу на таймлайне → Easing Style / Easing Direction.",
			},
			en = {
				"Easing is a property of the KEYFRAME, not of the whole animation. It defines the shape of the transition to the next key.",
				"Easing Style: Linear (mechanical), Sine (soft, a great default), Quad/Cubic (stronger acceleration), Back (overshoot), Elastic (springy), Bounce, Constant (an instant jump, no interpolation).",
				"Easing Direction: In (slow at the start), Out (slow at the end), InOut (slow at both ends).",
				"The core trick of lifelike animation is slow in / slow out: bodies do not start or stop instantly. Sine + InOut already looks great for most human motion.",
				"Use the Curve Editor when presets are not enough: it shows values as graphs and lets you drag tangents by hand — a sharp hit with a long settle, for example.",
				"To set easing: right click a key on the timeline → Easing Style / Easing Direction.",
			},
		},
		lesson = "1-4-easing-curves",
	},

	{
		id = "kb-default-anim",
		concepts = { "default" },
		patterns = { "заменить стандартную", "своя ходьба", "поменять анимацию бега", "replace default", "custom walk" },
		title = { ru = "Заменить стандартные анимации персонажа", en = "Replace the default character animations" },
		answer = {
			ru = {
				"Внутри персонажа Roblox создаёт LocalScript Animate с вложенными Animation-объектами: run, walk, jump, idle, fall, climb, swim, swimidle.",
				"Чтобы поставить свою анимацию, перезапишите AnimationId у нужного объекта. Сам скрипт Animate переписывать не надо.",
				"Делайте это серверным Script в ServerScriptService и подписывайтесь на player.CharacterAppearanceLoaded — к этому моменту скрипт Animate уже точно на месте.",
				"Перед заменой остановите уже играющие треки: for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0) end.",
				"У idle две вариации (Animation1 и Animation2), выбираются случайно. Частота задаётся дочерним объектом Weight: шанс = вес / сумма весов состояния.",
				"Все заменяющие анимации должны быть того же типа рига, что и игра (обычно R15).",
			},
			en = {
				"Inside the character Roblox creates an Animate LocalScript with nested Animation objects: run, walk, jump, idle, fall, climb, swim, swimidle.",
				"To use your own animation, overwrite the AnimationId on the relevant object. There is no need to rewrite the Animate script.",
				"Do it from a server Script in ServerScriptService, hooked to player.CharacterAppearanceLoaded — by then the Animate script definitely exists.",
				"Stop the already playing tracks first: for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0) end.",
				"Idle has two variations (Animation1 and Animation2) chosen at random. A child Weight object sets the odds: chance = weight / the sum for that state.",
				"Every replacement animation must match the game's rig type (usually R15).",
			},
		},
		snippet = "replace-default",
		lesson = "2-5-default-animations",
	},

	{
		id = "kb-blender",
		concepts = { "blender", "skinning" },
		patterns = { "blender", "fbx", "импорт анимации", "skinned mesh", "moon animator" },
		title = { ru = "Внешние инструменты: Blender, Moon Animator, FBX", en = "External tools: Blender, Moon Animator, FBX" },
		answer = {
			ru = {
				"Встроенный редактор закрывает большинство задач. Начинайте с него.",
				"Moon Animator — сторонний плагин, силён в сценах с несколькими персонажами, работе с камерой и графиками. На выходе — обычный ассет анимации с ID.",
				"Blender нужен для skinned mesh: моделей с костями (Bone) и плавной деформацией вместо жёстких частей. Пайплайн: риг и анимация в Blender → экспорт FBX → Studio, вкладка Avatar → 3D Importer / Import Animation.",
				"При импорте FBX проверяйте имена костей и масштаб — единицы Roblox почти всегда требуют ручной коррекции.",
				"Animation Capture (вкладка Avatar) записывает мимику и движения через веб-камеру прямо в Studio. Хорошо для черновика, но ключи почти всегда нужно чистить руками.",
				"Порядок работы: блокинг (грубые позы, Constant) → тайминг (двигаем ключи) → полировка (easing и детали). Полировать до утверждения тайминга — потеря времени.",
			},
			en = {
				"The built-in editor covers most needs. Start there.",
				"Moon Animator is a third-party plugin, strong at multi-character scenes, camera work and graphs. The output is an ordinary animation asset with an ID.",
				"Blender is for skinned meshes: models with Bones and smooth deformation instead of rigid parts. Pipeline: rig and animate in Blender → export FBX → Studio, Avatar tab → 3D Importer / Import Animation.",
				"When importing FBX, verify bone names and scale — Roblox units almost always need a manual fix.",
				"Animation Capture (Avatar tab) records facial and body motion from a webcam inside Studio. Good for blocking, but the keys almost always need cleanup.",
				"Workflow order: blocking (rough poses, Constant) → timing (slide keys) → polish (easing and detail). Polishing before the timing is locked wastes time.",
			},
		},
		lesson = "4-4-pipeline",
	},

	{
		id = "kb-motor6d",
		concepts = { "motor6d" },
		patterns = { "motor6d", "сустав", "как сделать риг", "build a rig", "joint" },
		title = { ru = "Motor6D и устройство рига", en = "Motor6D and how a rig works" },
		answer = {
			ru = {
				"Motor6D соединяет две части: Part0 (родитель, остаётся на месте) и Part1 (потомок, который двигается). Анимация вращает именно сустав, а не часть.",
				"C0 и C1 — CFrame'ы, задающие положение точки вращения относительно каждой части. Ошибка в них — самая частая причина «сломанного» рига, где конечности смещены.",
				"Свойство Transform — это смещение поверх базовой позы. Именно в него пишет аниматор каждый кадр, и именно через него делают процедурную анимацию.",
				"Риг = набор частей, связанных Motor6D. Без них Animation Editor не покажет ни одной дорожки.",
				"Правило якорения: заякорена должна быть только корневая часть. Остальные — Anchored = false, иначе суставы не смогут их двигать.",
				"Для персонажей риг удобнее всего строить через Avatar → Rig Builder, а не руками.",
			},
			en = {
				"Motor6D connects two parts: Part0 (the parent, stays put) and Part1 (the child, which moves). Animation rotates the joint, not the part.",
				"C0 and C1 are CFrames placing the pivot relative to each part. Getting them wrong is the most common cause of a 'broken' rig with offset limbs.",
				"The Transform property is an offset on top of the base pose. That is what the animator writes each frame and what procedural animation hooks into.",
				"A rig is a set of parts joined by Motor6D. Without them the Animation Editor shows no tracks at all.",
				"Anchoring rule: only the root part should be anchored. The rest must be Anchored = false or the joints cannot move them.",
				"For characters, build rigs with Avatar → Rig Builder rather than by hand.",
			},
		},
		snippet = "build-rig-motor6d",
		lesson = "1-1-what-is-animation",
	},

	{
		id = "kb-npc",
		concepts = { "npc", "animation" },
		patterns = { "анимация нпс", "npc animation", "анимация моба", "enemy animation",
			"нпс ходил", "нпс ходит", "чтобы нпс", "моб ходил", "npc walk", "npc idle",
			"make an npc" },
		title = { ru = "Анимации NPC", en = "NPC animations" },
		answer = {
			ru = {
				"NPC с Humanoid анимируется точно так же, как игрок: humanoid → Animator → LoadAnimation → Play.",
				"Важное отличие: NPC принадлежит серверу, поэтому его анимации надо запускать серверным Script. Если запустить на клиенте, увидит только один игрок.",
				"Стройте машину состояний: одно активное состояние (idle / walk / attack) и переход только при смене. Подписывайтесь на humanoid.Running (даёт скорость) и humanoid.StateChanged.",
				"Главная ошибка — вызывать track:Play() каждый кадр в цикле. Трек перезапускается и анимация выглядит замершей на первом кадре. Всегда проверяйте, играет ли уже нужный трек.",
				"При переключении давайте fadeTime: current:Stop(0.2) и next:Play(0.2) — иначе переход будет рывком.",
				"Если NPC много, не отключайте LOD (Animator.PreferLodEnabled) массово — это ударит по производительности.",
			},
			en = {
				"An NPC with a Humanoid animates exactly like a player: humanoid → Animator → LoadAnimation → Play.",
				"The key difference: the NPC belongs to the server, so start its animations from a server Script. Started on a client, only that one player sees it.",
				"Build a state machine: one active state (idle / walk / attack) with transitions only on change. Hook humanoid.Running (gives speed) and humanoid.StateChanged.",
				"The classic mistake is calling track:Play() every frame in a loop. The track restarts and the animation looks frozen on frame one. Always check whether it is already playing.",
				"Give transitions a fade: current:Stop(0.2) and next:Play(0.2), otherwise the switch pops.",
				"With many NPCs, do not disable LOD (Animator.PreferLodEnabled) across the board — it will hurt performance.",
			},
		},
		snippet = "npc-state",
		lesson = "3-2-tools-npc",
	},

	{
		id = "kb-speed",
		concepts = { "speed" },
		patterns = { "скорость анимации", "быстрее", "медленнее", "animation speed", "adjustspeed", "скольз" },
		title = { ru = "Скорость воспроизведения и скольжение ног", en = "Playback speed and foot sliding" },
		answer = {
			ru = {
				"track:AdjustSpeed(speed): 1 — нормально, 2 — вдвое быстрее, 0.5 — вдвое медленнее, 0 — пауза, отрицательное значение — воспроизведение задом наперёд.",
				"Начальную скорость можно задать сразу: track:Play(fadeTime, weight, speed).",
				"track.Length — это длина при скорости 1. Реальная длительность = Length / Speed.",
				"«Скольжение ног» возникает, когда персонаж двигается быстрее или медленнее, чем предполагает анимация. Лечится синхронизацией: track:AdjustSpeed(humanoid.WalkSpeed / BASE_SPEED), где BASE_SPEED — скорость, под которую анимация рисовалась (обычно 16).",
				"Не меняйте скорость слишком резко — это заметно. Если нужен плавный разгон, интерполируйте значение сами.",
			},
			en = {
				"track:AdjustSpeed(speed): 1 is normal, 2 is twice as fast, 0.5 half speed, 0 pauses and a negative value plays backwards.",
				"You can set the initial speed directly: track:Play(fadeTime, weight, speed).",
				"track.Length is the length at speed 1. The real duration is Length / Speed.",
				"Foot sliding happens when the character moves faster or slower than the animation assumes. Fix it by syncing: track:AdjustSpeed(humanoid.WalkSpeed / BASE_SPEED), where BASE_SPEED is the speed the animation was authored for (usually 16).",
				"Do not snap the speed around — it reads badly. Interpolate the value yourself if you need a smooth ramp.",
			},
		},
		lesson = "2-4-weight-speed",
	},

	{
		id = "kb-stop",
		concepts = { "stop", "animation" },
		must = { "stop" },
		patterns = { "остановить анимац", "как остановить", "выключить анимац",
			"stop an animation", "stop the animation", "how to stop", "pause an animation" },
		title = { ru = "Как остановить или поставить анимацию на паузу", en = "Stopping or pausing an animation" },
		answer = {
			ru = {
				"track:Stop(fadeTime) — остановка с плавным затуханием. По умолчанию fadeTime = 0.1 с. Stop(0) обрезает движение мгновенно, это заметно рывком — используйте только когда нужен жёсткий срез.",
				"Пауза — это не Stop. Чтобы заморозить кадр, поставьте скорость в ноль: track:AdjustSpeed(0). Продолжить — track:AdjustSpeed(1).",
				"Остановить всё сразу: for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0.1) end. Это же нужно делать при Unequipped у Tool, иначе поза зависнет.",
				"Проверить состояние можно через track.IsPlaying. Учтите: GetPlayingAnimationTracks возвращает и те треки, которые сейчас затухают.",
				"После Stop трек не уничтожается — его можно проигрывать снова. Заново вызывать LoadAnimation не нужно.",
			},
			en = {
				"track:Stop(fadeTime) stops with a fade out. The default fadeTime is 0.1 s. Stop(0) cuts instantly and reads as a pop — use it only when you want a hard cut.",
				"Pausing is not stopping. To freeze on the current frame set the speed to zero: track:AdjustSpeed(0). Resume with track:AdjustSpeed(1).",
				"To stop everything: for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0.1) end. Do the same in a Tool's Unequipped or the pose sticks.",
				"Check state with track.IsPlaying. Note that GetPlayingAnimationTracks also returns tracks that are currently fading out.",
				"Stopping does not destroy the track — you can play it again. There is no need to call LoadAnimation a second time.",
			},
		},
		snippet = "track-lifecycle",
		lesson = "2-1-animator-track",
	},

	{
		id = "kb-walk-cycle",
		concepts = { "walk", "animation" },
		must = { "walk" },
		patterns = { "анимацию ходьбы", "цикл ходьбы", "анимацию бега", "походк",
			"walk cycle", "run cycle", "walking animation", "running animation" },
		title = { ru = "Как сделать цикл ходьбы или бега", en = "Building a walk or run cycle" },
		answer = {
			ru = {
				"Цикл ходьбы строится на четырёх опорных позах: контакт (нога касается земли), низшая точка, проход (одна нога проходит мимо другой) и высшая точка. Сделайте их первыми, остальное — уточнение.",
				"Обязательное условие цикла: последний кадр должен точно повторять первый, иначе на повторе будет рывок. Скопируйте первый ключ в конец.",
				"Руки двигаются противофазно ногам: левая рука вперёд вместе с правой ногой. Без этого походка выглядит неестественно.",
				"Не забывайте про вертикальное смещение HumanoidRootPart: тело слегка поднимается на проходе и опускается на контакте. Это придаёт вес.",
				"В коде цикл включается через track.Looped = true, а приоритет ставится Enum.AnimationPriority.Movement.",
				"Чтобы ноги не скользили, синхронизируйте темп со скоростью: track:AdjustSpeed(humanoid.WalkSpeed / 16), где 16 — скорость, под которую рисовалась анимация.",
				"Если нужно заменить стандартную ходьбу у всех игроков — это делается через скрипт Animate, см. отдельный вопрос про стандартные анимации.",
			},
			en = {
				"A walk cycle is built from four key poses: contact (foot lands), down, passing (one leg passes the other) and up. Block those first; everything else is refinement.",
				"The loop requirement: the last frame must exactly repeat the first or the wrap will pop. Copy the first key to the end.",
				"Arms swing opposite the legs: left arm forward with the right leg. Without that the walk looks wrong.",
				"Do not forget vertical motion on the HumanoidRootPart: the body rises slightly on the passing pose and drops on contact. That is what gives it weight.",
				"In code, enable the cycle with track.Looped = true and set the priority to Enum.AnimationPriority.Movement.",
				"To stop foot sliding, sync the tempo to the speed: track:AdjustSpeed(humanoid.WalkSpeed / 16), where 16 is the speed the animation was authored for.",
				"If you want to replace the default walk for every player, that goes through the Animate script — see the question about default animations.",
			},
		},
		lesson = "1-3-first-animation",
	},

	{
		id = "kb-speed-change",
		concepts = { "speed", "animation" },
		must = { "speed" },
		patterns = { "ускорить анимац", "замедлить анимац", "скорость анимац",
			"adjustspeed", "animation speed", "speed up the animation", "slow down the animation" },
		title = { ru = "Как изменить скорость анимации", en = "Changing animation speed" },
		answer = {
			ru = {
				"track:AdjustSpeed(speed) меняет темп прямо во время проигрывания: 1 — обычная скорость, 2 — вдвое быстрее, 0.5 — вдвое медленнее, 0 — пауза, отрицательное значение — воспроизведение задом наперёд.",
				"Задать скорость сразу при запуске можно третьим аргументом: track:Play(fadeTime, weight, speed).",
				"track.Length — это длина при скорости 1. Реальная длительность считается как Length / Speed.",
				"Частая задача — убрать «скольжение ног». Синхронизируйте темп с реальной скоростью персонажа: track:AdjustSpeed(humanoid.WalkSpeed / 16), где 16 — скорость, под которую рисовалась анимация.",
				"Резкие скачки скорости заметны. Если нужен плавный разгон, интерполируйте значение сами и вызывайте AdjustSpeed каждый кадр.",
			},
			en = {
				"track:AdjustSpeed(speed) changes the tempo during playback: 1 is normal, 2 twice as fast, 0.5 half speed, 0 pauses and a negative value plays it backwards.",
				"You can also set the speed as the third argument when starting: track:Play(fadeTime, weight, speed).",
				"track.Length is the length at speed 1. The real duration is Length / Speed.",
				"A common need is killing foot sliding. Sync the tempo to the actual character speed: track:AdjustSpeed(humanoid.WalkSpeed / 16), where 16 is the speed the animation was authored for.",
				"Sudden speed jumps are visible. For a smooth ramp, interpolate the value yourself and call AdjustSpeed each frame.",
			},
		},
		lesson = "2-4-weight-speed",
	},

	{
		id = "kb-respawn",
		concepts = { "humanoid", "notworking" },
		patterns = { "после смерти", "после респавна", "after respawn", "after dying", "characteradded" },
		title = { ru = "Анимация пропала после смерти персонажа", en = "The animation is gone after respawn" },
		answer = {
			ru = {
				"При респавне Roblox создаёт НОВУЮ модель персонажа, новый Humanoid и новый Animator. Все треки, загруженные на старый Animator, становятся бесполезными.",
				"Решение — загружать треки в обработчике CharacterAdded, а не один раз при старте скрипта.",
				"Шаблон: функция onCharacterAdded(character) грузит все нужные треки; вызовите её и для уже существующего player.Character, и подпишите на player.CharacterAdded.",
				"Проверьте также StarterPlayerScripts vs StarterCharacterScripts: скрипты из StarterCharacterScripts копируются в каждого нового персонажа заново, из StarterPlayerScripts — запускаются один раз за сессию.",
				"Если у вас таблица треков — не забудьте очищать её при респавне, иначе будете держать ссылки на мёртвые объекты.",
			},
			en = {
				"On respawn Roblox builds a NEW character model, a new Humanoid and a new Animator. Every track loaded on the old Animator is now useless.",
				"The fix is to load tracks inside a CharacterAdded handler rather than once at script start.",
				"Pattern: an onCharacterAdded(character) function that loads every track; call it for the existing player.Character and also connect it to player.CharacterAdded.",
				"Also mind StarterPlayerScripts vs StarterCharacterScripts: scripts in StarterCharacterScripts are copied into every new character, while StarterPlayerScripts runs once per session.",
				"If you keep a table of tracks, clear it on respawn or you will hold references to dead objects.",
			},
		},
		snippet = "reload-on-respawn",
		lesson = "2-1-animator-track",
	},
}

Knowledge.byId = {}
for _, entry in ipairs(Knowledge.entries) do
	Knowledge.byId[entry.id] = entry
end

return Knowledge
