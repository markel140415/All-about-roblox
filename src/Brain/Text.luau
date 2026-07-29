--[[
	Brain/Text
	Bilingual (Russian + English) text processing for the offline tutor.

	Roblox's `string.lower` is byte based and does not touch Cyrillic, and there
	is no stemmer available in Luau, so everything here is implemented from
	scratch on top of raw UTF-8 bytes:

	  * `lower`     - ASCII + Cyrillic (including Ё) case folding
	  * `tokenize`  - UTF-8 aware word splitting
	  * `stem`      - light suffix stripping for RU and EN
	  * `concepts`  - maps surface forms in either language onto shared
	                  "concept" ids, so a Russian question can match an English
	                  knowledge entry and vice versa.

	Pure Lua, no Roblox API: unit tested in tests/.
]]

local Text = {}

----------------------------------------------------------------------
-- Case folding
----------------------------------------------------------------------

--[[
	Cyrillic in UTF-8:
	  А..П = D0 90 .. D0 9F      -> а..п = D0 B0 .. D0 BF   (+0x20)
	  Р..Я = D0 A0 .. D0 AF      -> р..я = D1 80 .. D1 8F   (lead byte changes)
	  Ё    = D0 81               -> ё    = D1 91
]]
function Text.lower(s)
	local out = {}
	local i = 1
	local n = #s
	while i <= n do
		local b = string.byte(s, i)
		if b == 0xD0 and i < n then
			local b2 = string.byte(s, i + 1)
			if b2 >= 0x90 and b2 <= 0x9F then
				out[#out + 1] = string.char(0xD0, b2 + 0x20)
			elseif b2 >= 0xA0 and b2 <= 0xAF then
				out[#out + 1] = string.char(0xD1, b2 - 0x20)
			elseif b2 == 0x81 then -- Ё
				out[#out + 1] = string.char(0xD1, 0x91)
			else
				out[#out + 1] = string.char(b, b2)
			end
			i = i + 2
		elseif b >= 0xC0 then
			-- Any other multi-byte sequence: copy verbatim.
			local len = 2
			if b >= 0xF0 then
				len = 4
			elseif b >= 0xE0 then
				len = 3
			end
			out[#out + 1] = string.sub(s, i, i + len - 1)
			i = i + len
		else
			if b >= 65 and b <= 90 then
				out[#out + 1] = string.char(b + 32)
			else
				out[#out + 1] = string.char(b)
			end
			i = i + 1
		end
	end
	return table.concat(out)
end

----------------------------------------------------------------------
-- Tokenizer
----------------------------------------------------------------------

--[[
	Splits text into lowercase word tokens. ASCII letters/digits and any
	multi-byte (Cyrillic) sequence count as word characters; everything else is
	a separator. Underscore and `:` are separators so `Animator:LoadAnimation`
	becomes two useful tokens.
]]
function Text.tokenize(s)
	if type(s) ~= "string" then
		return {}
	end
	local lowered = Text.lower(s)
	local tokens = {}
	local buffer = {}

	local function flush()
		if #buffer > 0 then
			tokens[#tokens + 1] = table.concat(buffer)
			buffer = {}
		end
	end

	local i = 1
	local n = #lowered
	while i <= n do
		local b = string.byte(lowered, i)
		if b >= 0x80 then
			local len = 2
			if b >= 0xF0 then
				len = 4
			elseif b >= 0xE0 then
				len = 3
			end
			buffer[#buffer + 1] = string.sub(lowered, i, i + len - 1)
			i = i + len
		elseif (b >= 97 and b <= 122) or (b >= 48 and b <= 57) then
			buffer[#buffer + 1] = string.char(b)
			i = i + 1
		else
			flush()
			i = i + 1
		end
	end
	flush()
	return tokens
end

----------------------------------------------------------------------
-- Stemming
----------------------------------------------------------------------

-- Longest-first so that "ациями" is stripped before "ми".
local RU_SUFFIXES = {
	"иваниями", "ованиями", "ированием",
	"ированию", "ированный", "ирование", "ированы",
	"ациями", "ациям", "ациях", "ации", "ацию", "ация",
	"ениями", "ениям", "ениях", "ения", "ением", "ению", "ение",
	"остями", "остям", "остях", "ости", "остью", "ость",
	"ыми", "ими", "ого", "его", "ому", "ему", "ых", "их",
	"ами", "ями", "ов", "ев", "ей", "ий", "ая", "яя", "ое", "ее",
	"ые", "ие", "ой", "ей", "ым", "им", "ом", "ем", "ах", "ях",
	"ешь", "ете", "ели", "ила", "ило", "или", "ать", "ять", "ить",
	"ся", "сь", "ла", "ло", "ли", "ет", "ут", "ют", "ит", "ат", "ят",
	"у", "ю", "а", "я", "ы", "и", "е", "о", "ь", "й",
}

local EN_SUFFIXES = {
	"izations", "ization", "ational", "iveness", "fulness",
	"ations", "ation", "ings", "ing", "ers", "er",
	"ed", "ly", "s",
}

local function utf8Length(s)
	local n = 0
	for i = 1, #s do
		local b = string.byte(s, i)
		if b < 0x80 or b >= 0xC0 then
			n = n + 1
		end
	end
	return n
end

Text.utf8Length = utf8Length

local function isCyrillic(token)
	local b = string.byte(token, 1)
	return b ~= nil and b >= 0x80
end

--[[
	Light stemmer. The goal is recall (matching "анимации" with "анимация"),
	not linguistic correctness, so it deliberately keeps stems >= 3 characters.
]]
function Text.stem(token)
	if #token == 0 then
		return token
	end
	local suffixes = isCyrillic(token) and RU_SUFFIXES or EN_SUFFIXES
	local minLength = isCyrillic(token) and 4 or 3

	-- English "-ies" -> "-y" so that "properties" and "property" converge.
	if not isCyrillic(token) and #token > 4 and string.sub(token, -3) == "ies" then
		return string.sub(token, 1, #token - 3) .. "y"
	end

	for _, suffix in ipairs(suffixes) do
		local sLen = #suffix
		if #token > sLen and string.sub(token, -sLen) == suffix then
			local candidate = string.sub(token, 1, #token - sLen)
			if utf8Length(candidate) >= minLength then
				return candidate
			end
		end
	end
	return token
end

----------------------------------------------------------------------
-- Stop words
----------------------------------------------------------------------

local STOP_WORDS = {}
for _, w in ipairs({
	-- Russian
	"и", "в", "во", "не", "что", "он", "на", "я", "с", "со", "как", "а", "то",
	"все", "она", "так", "его", "но", "да", "ты", "к", "у", "же", "вы", "за",
	"бы", "по", "ее", "мне", "было", "вот", "от", "меня", "еще", "нет",
	"о", "из", "ему", "теперь", "когда", "даже", "ну", "вдруг", "ли", "если",
	"уже", "или", "быть", "был", "него", "до", "вас", "нибудь", "опять", "уж",
	"вам", "ведь", "там", "потом", "себя", "ничего", "ей", "может", "они",
	"тут", "где", "есть", "надо", "ней", "для", "мы", "тебя", "их", "чем",
	"была", "сам", "чтоб", "без", "будто", "чего", "раз", "тоже", "себе",
	"под", "будет", "ж", "тогда", "кто", "этот", "того", "потому", "этого",
	"какой", "совсем", "ним", "здесь", "этом", "один", "почти", "мой", "тем",
	"чтобы", "нее", "были", "куда", "зачем", "всех", "никогда", "можно",
	"при", "наконец", "два", "об", "другой", "хоть", "после", "над", "больше",
	"тот", "через", "эти", "нас", "про", "всего", "них", "какая", "много",
	"разве", "три", "эту", "моя", "впрочем", "хорошо", "свою", "этой", "перед",
	"иногда", "лучше", "чуть", "том", "нельзя", "такой", "им", "более",
	"всегда", "конечно", "всю", "между", "пожалуйста", "привет", "спасибо",
	-- English
	"the", "a", "an", "and", "or", "but", "if", "then", "than", "so", "of",
	"to", "in", "on", "at", "by", "for", "with", "about", "into", "from",
	"is", "are", "was", "were", "be", "been", "being", "am", "do", "does",
	"did", "doing", "have", "has", "had", "having", "i", "you", "he", "she",
	"it", "we", "they", "me", "him", "her", "us", "them", "my", "your", "his",
	"its", "our", "their", "this", "that", "these", "those", "there", "here",
	"what", "which", "who", "whom", "when", "where", "why", "how", "all",
	"any", "both", "each", "few", "more", "most", "other", "some", "such",
	"no", "nor", "not", "only", "own", "same", "too", "very", "can", "will",
	"just", "should", "now", "please", "hello", "hi", "thanks",
}) do
	STOP_WORDS[w] = true
end

function Text.isStopWord(token)
	return STOP_WORDS[token] == true
end

----------------------------------------------------------------------
-- Concept mapping (cross-language bridge)
----------------------------------------------------------------------

--[[
	Each entry is { concept, prefix1, prefix2, ... }.
	A token maps to a concept when it starts with one of the listed prefixes.
	Prefixes are matched against the lowercased *raw* token (before stemming),
	which handles Russian inflection robustly ("анимации", "анимацию", ...).
]]
local CONCEPT_RULES = {
	{ "animation", "анимац", "анимир", "анимк", "animat", "anim" },
	{ "rig", "риг", "скелет", "rig", "skeleton", "armature" },
	{ "r6", "r6", "р6" },
	{ "r15", "r15", "р15" },
	{ "keyframe", "ключев", "кадр", "keyfram", "frame", "поза", "поз" },
	{ "editor", "редактор", "editor", "аниматор редактор" },
	{ "curve", "кривая", "кривых", "кривые", "curve", "график", "graph", "easing", "изинг",
	  "плавн", "робот", "robot", "механич", "mechanic", "деревян", "stiff", "естествен",
	  "натурал", "natural", "живо", "смотрится", "выглядит" },
	{ "motor6d", "motor6d", "мотор", "joint", "сустав", "сочленен", "шарнир" },
	{ "animator", "animator", "аниматор" },
	{ "animationcontroller", "animationcontroller", "контроллер", "дверь", "двер", "door",
	  "машин", "ship", "корабл", "платформ", "turret", "турел" },
	{ "track", "animationtrack", "трек", "track", "дорожк" },
	{ "priority", "приоритет", "priorit" },
	{ "weight", "вес", "весов", "weight", "блендинг", "blend", "смеш", "микш" },
	{ "speed", "скорост", "speed", "быстр", "медлен", "темп", "ускор", "замедл", "slow", "fast" },
	{ "looped", "цикл", "loop", "зациклен", "повтор" },
	{ "fade", "fadetime", "фейд", "затухан", "переход", "transition" },
	{ "event", "событ", "event", "маркер", "marker", "getmarkerreachedsignal", "footstep",
	  "шаг", "звук", "sound", "урон", "damage", "момент", "синхрон", "sync", "попадан", "hit" },
	{ "export", "экспорт", "export", "публик", "опубл", "publish", "upload", "загруз",
	  "сохран", "save" },
	{ "assetid", "assetid", "айди", "rbxassetid", "ассет" },
	{ "script", "скрипт", "script", "код", "code", "localscript" },
	-- "=word" means an exact token match, so "players" does not become "play".
	{ "play", "играт", "проигр", "воспроизв", "запуст", "запуск", "старт", "start",
	  "=play", "=plays", "=playing", "=played" },
	{ "stop", "останов", "стоп", "stop", "выключ", "пауз", "pause", "прерв", "cancel", "отмен" },
	-- Only unambiguous failure words here; negated phrases are handled by
	-- PHRASE_RULES below so that "как работает X" is not read as "X is broken".
	{ "notworking", "ошибк", "error", "broken", "fail", "сломал", "глюч",
	  "проблем", "issue", "problem", "баг", "bug", "неправильно", "wrong" },
	{ "replication", "реплик", "replicat", "сервер", "server", "клиент", "client", "видят", "видно",
	  "остальны", "другие игроки", "мультиплеер", "multiplayer" },
	{ "tool", "tool", "инструмент", "оруж", "weapon", "предмет", "меч", "sword", "gun" },
	{ "ik", "ik", "ikcontrol", "инверсн", "кинематик", "inverse" },
	{ "skinning", "скин", "skin", "bone", "кост", "меш", "mesh", "деформац" },
	{ "npc", "npc", "нпс", "моб", "враг", "enemy", "монстр" },
	{ "idle", "idle", "айдл", "стоян", "покой", "дыхан" },
	{ "walk", "ходьб", "walk", "шаг", "походк", "run", "бег" },
	{ "jump", "прыж", "jump", "падени", "fall" },
	{ "attack", "атак", "удар", "attack", "combat", "combo", "комбо", "punch" },
	{ "optimization", "оптимиз", "optimiz", "performance", "производител", "лаг", "lag", "fps",
	  "тормоз", "memory", "памят", "preload", "предзагруз" },
	{ "procedural", "процедурн", "procedural", "runservice", "transform", "динамическ" },
	{ "capture", "capture", "захват", "камер", "webcam", "video", "видео", "mocap", "мокап" },
	{ "default", "стандартн", "дефолт", "default", "встроен", "замен", "replace", "animate" },
	{ "learn", "учит", "учеб", "обуч", "урок", "lesson", "изуч", "начат", "learn", "teach", "start",
	  "курс", "course", "tutorial", "туториал" },
	{ "progress", "прогресс", "progress", "статус", "status", "достижен", "результат" },
	{ "help", "помог", "помощ", "help", "подскаж", "объясн", "explain", "расскаж", "покажи", "show" },
	{ "example", "пример", "example", "sample", "шаблон", "snippet", "сниппет" },
	{ "install", "установ", "install", "плагин", "plugin", "setup", "настро" },
	{ "moonanimator", "moon", "мун" },
	{ "blender", "blender", "блендер", "fbx", "фбх", "import", "импорт" },
	{ "loadanimation", "loadanimation" },
	{ "humanoid", "humanoid", "гуманоид", "персонаж", "character", "чар" },
	{ "layered", "layered", "слой", "слоя", "layer" },
	{ "deprecated", "deprecated", "устарел", "депрекейт" },
}

--[[
	Phrase rules run against the whole lowercased string rather than single
	tokens. They exist for negations and multi-word intents, where the meaning
	lives in the combination and not in any one word.
]]
local PHRASE_RULES = {
	{ "notworking", "не работает", "не работают", "не заработал", "не пашет",
		"не играет", "не проигрывается", "не воспроизводится", "не запускается",
		"не двигается", "не видно", "не показывает", "ничего не происходит",
		"not working", "doesn't work", "does not work", "not playing",
		"doesn't play", "does not play", "won't play", "will not play",
		"nothing happens", "not animating", "isn't playing", "is not playing",
		"не анимир", "не оживает", "не реагирует", "перестала работать",
		"не могу заставить", "can't get it to", "cannot get it to" },
	{ "replication", "не видят", "не видит", "другие игроки", "остальные игроки",
		"видно только мне", "вижу только я", "только я вижу",
		"other players", "cannot see", "can't see", "only i can see",
		"nobody else", "everyone else" },
	{ "weight", "смешать анимац", "смешивание анимац", "плавный переход",
		"blend animation", "blending animation", "smooth transition" },
}

--[[ Returns an array of concept ids triggered by the given raw tokens. ]]
function Text.concepts(tokens, raw)
	local found = {}
	local order = {}

	local function add(concept)
		if not found[concept] then
			found[concept] = true
			order[#order + 1] = concept
		end
	end

	for _, token in ipairs(tokens) do
		for _, rule in ipairs(CONCEPT_RULES) do
			local concept = rule[1]
			if not found[concept] then
				for i = 2, #rule do
					local pattern = rule[i]
					if string.sub(pattern, 1, 1) == "=" then
						-- Exact token match.
						if token == string.sub(pattern, 2) then
							add(concept)
							break
						end
					elseif #token >= #pattern and string.sub(token, 1, #pattern) == pattern then
						add(concept)
						break
					end
				end
			end
		end
	end

	if raw then
		for _, rule in ipairs(PHRASE_RULES) do
			local concept = rule[1]
			for i = 2, #rule do
				if string.find(raw, rule[i], 1, true) then
					add(concept)
					break
				end
			end
		end
	end

	return order
end

----------------------------------------------------------------------
-- Public analysis entry point
----------------------------------------------------------------------

--[[
	Analyses a piece of text once and returns everything downstream code needs.
	  raw      - lowercase original string
	  tokens   - raw word tokens
	  stems    - stemmed, stop-word filtered tokens
	  concepts - cross-language concept ids
]]
function Text.analyze(input)
	local raw = Text.lower(input or "")
	local tokens = Text.tokenize(raw)
	local stems = {}
	for _, token in ipairs(tokens) do
		if not Text.isStopWord(token) and utf8Length(token) > 1 then
			stems[#stems + 1] = Text.stem(token)
		end
	end
	return {
		raw = raw,
		tokens = tokens,
		stems = stems,
		concepts = Text.concepts(tokens, raw),
	}
end

--[[ Detects the dominant language of a string: "ru" or "en". ]]
function Text.detectLanguage(input)
	local cyrillic, latin = 0, 0
	local i = 1
	local n = #input
	while i <= n do
		local b = string.byte(input, i)
		if b == 0xD0 or b == 0xD1 then
			cyrillic = cyrillic + 1
			i = i + 2
		elseif (b >= 65 and b <= 90) or (b >= 97 and b <= 122) then
			latin = latin + 1
			i = i + 1
		else
			i = i + 1
		end
	end
	if cyrillic > latin then
		return "ru"
	elseif latin > 0 then
		return "en"
	end
	return nil
end

return Text
