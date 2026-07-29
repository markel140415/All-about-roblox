--[[
	Data/Strings
	All UI text, in Russian and English. Nothing user-visible should be
	hardcoded anywhere else in the plugin.
]]

local Strings = {}

Strings.languages = { "ru", "en" }

Strings.data = {
	ru = {
		languageName = "Русский",
		pluginTitle = "ИИ-Учитель Анимации",
		toolbarName = "AnimTeacher",
		buttonTitle = "Учитель анимации",
		buttonTooltip = "Открыть ИИ-учителя по анимации Roblox",

		tabCourse = "Курс",
		tabChat = "Вопрос",
		tabProgress = "Прогресс",

		greetingTitle = "Привет! Я научу вас анимации в Roblox.",
		greetingBody = "Слева — курс из 17 уроков: от первого рига до IK и оптимизации. Не знаете, с чего начать — нажмите «Продолжить обучение». Есть конкретный вопрос — вкладка «Вопрос», спрашивайте своими словами по-русски или по-английски.",

		continueLearning = "Продолжить обучение",
		startCourse = "Начать курс",
		lessonList = "Все уроки",
		back = "Назад",
		nextLesson = "Следующий урок",
		markDone = "Отметить пройденным",
		markedDone = "Урок пройден",
		reopen = "Пройти заново",

		sectionGoal = "Цель урока",
		sectionTheory = "Теория",
		sectionSteps = "Что делать в Studio",
		sectionPractice = "Задание",
		sectionQuiz = "Проверь себя",
		sectionCode = "Пример кода",

		insertCode = "Вставить код в игру",
		copyHint = "Код вставлен: ",
		checkWork = "Проверить мою работу",

		quizCorrect = "Верно!",
		quizWrong = "Не совсем.",
		quizTryAgain = "Попробуйте ещё раз",

		askPlaceholder = "Спросите про анимацию…",
		askButton = "Спросить",
		thinking = "Думаю…",
		relatedLesson = "Связанный урок: ",
		alsoSee = "Смотрите также:",
		openLesson = "Открыть урок",

		fallbackTitle = "Не понял вопрос",
		fallbackBody = "Я знаю только про анимацию в Roblox Studio. Попробуйте спросить конкретнее: «почему анимация не работает», «как проиграть анимацию скриптом», «что такое приоритет», «как смешать анимации», «как сделать IK».",

		progressTitle = "Ваш прогресс",
		progressLessons = "Пройдено уроков",
		progressQuiz = "Правильных ответов в тестах",
		progressModule = "Модуль",
		resetProgress = "Сбросить прогресс",
		resetConfirm = "Нажмите ещё раз, чтобы подтвердить",
		notStarted = "не начат",
		inProgress = "в процессе",
		completed = "пройден",

		minutes = "мин",
		lesson = "Урок",
		of = "из",

		checkPass = "Отлично! ",
		checkFail = "Пока нет. ",
		checkRigFound = "Нашёл риг в Workspace с суставами Motor6D.",
		checkRigMissing = "В Workspace нет модели с Motor6D. Вставьте риг: вкладка Avatar → Rig Builder.",
		checkScriptFound = "Нашёл скрипт, который использует Animator:LoadAnimation.",
		checkScriptMissing = "Не нашёл скрипт с Animator:LoadAnimation. Создайте LocalScript в StarterPlayerScripts и вставьте пример кода.",
		checkDeprecated = "Внимание: найден устаревший вызов Humanoid:LoadAnimation. Замените на Animator:LoadAnimation.",

		languageToggle = "English",
	},

	en = {
		languageName = "English",
		pluginTitle = "AI Animation Teacher",
		toolbarName = "AnimTeacher",
		buttonTitle = "Animation Teacher",
		buttonTooltip = "Open the AI Roblox animation tutor",

		tabCourse = "Course",
		tabChat = "Ask",
		tabProgress = "Progress",

		greetingTitle = "Hi! I will teach you animation in Roblox.",
		greetingBody = "On the left is a 17-lesson course: from your first rig to IK and optimization. Not sure where to start? Press \"Continue learning\". Got a specific question? Use the \"Ask\" tab and write in your own words, in English or Russian.",

		continueLearning = "Continue learning",
		startCourse = "Start the course",
		lessonList = "All lessons",
		back = "Back",
		nextLesson = "Next lesson",
		markDone = "Mark as done",
		markedDone = "Lesson completed",
		reopen = "Study again",

		sectionGoal = "Goal",
		sectionTheory = "Theory",
		sectionSteps = "Do this in Studio",
		sectionPractice = "Exercise",
		sectionQuiz = "Check yourself",
		sectionCode = "Code sample",

		insertCode = "Insert code into the place",
		copyHint = "Code inserted: ",
		checkWork = "Check my work",

		quizCorrect = "Correct!",
		quizWrong = "Not quite.",
		quizTryAgain = "Try again",

		askPlaceholder = "Ask about animation…",
		askButton = "Ask",
		thinking = "Thinking…",
		relatedLesson = "Related lesson: ",
		alsoSee = "See also:",
		openLesson = "Open lesson",

		fallbackTitle = "I did not get that",
		fallbackBody = "I only know Roblox Studio animation. Try something more specific: \"why is my animation not working\", \"how to play an animation from a script\", \"what is priority\", \"how to blend animations\", \"how does IK work\".",

		progressTitle = "Your progress",
		progressLessons = "Lessons completed",
		progressQuiz = "Correct quiz answers",
		progressModule = "Module",
		resetProgress = "Reset progress",
		resetConfirm = "Click again to confirm",
		notStarted = "not started",
		inProgress = "in progress",
		completed = "completed",

		minutes = "min",
		lesson = "Lesson",
		of = "of",

		checkPass = "Nice! ",
		checkFail = "Not yet. ",
		checkRigFound = "Found a rig in the Workspace with Motor6D joints.",
		checkRigMissing = "No model with Motor6D in the Workspace. Insert a rig: Avatar tab → Rig Builder.",
		checkScriptFound = "Found a script using Animator:LoadAnimation.",
		checkScriptMissing = "No script with Animator:LoadAnimation found. Create a LocalScript in StarterPlayerScripts and insert the code sample.",
		checkDeprecated = "Heads up: found a deprecated Humanoid:LoadAnimation call. Switch it to Animator:LoadAnimation.",

		languageToggle = "Русский",
	},
}

function Strings.get(language)
	return Strings.data[language] or Strings.data.en
end

function Strings.other(language)
	return language == "ru" and "en" or "ru"
end

return Strings
