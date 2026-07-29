--[[ Tests for Brain/Text: case folding, tokenizing, stemming, concepts. ]]

local Text = _require("Brain.Text")
local H = (function()
	local f = io.open(SRC_DIR .. "/../tests/helpers.lua", "r")
	local src = f:read("*a")
	f:close()
	return load(src, "@helpers.lua")()
end)()

H.section("lower() handles Cyrillic and ASCII")
H.equal(Text.lower("АНИМАЦИЯ"), "анимация", "uppercase RU -> lowercase")
H.equal(Text.lower("Ключевой Кадр"), "ключевой кадр", "mixed RU")
H.equal(Text.lower("LoadAnimation"), "loadanimation", "ASCII")
H.equal(Text.lower("Ёлка"), "ёлка", "letter Yo")
H.equal(Text.lower("Р15 Риг"), "р15 риг", "letters in the R..Ya range")
H.equal(Text.lower("Приоритет"), "приоритет", "P is in the first range")
H.equal(Text.lower("Ярость"), "ярость", "Ya is in the second range")

H.section("tokenize() splits on punctuation and keeps words")
local t1 = Text.tokenize("Animator:LoadAnimation(anim)")
H.contains(t1, "animator", "method owner token")
H.contains(t1, "loadanimation", "method name token")
H.equal(#Text.tokenize("Как сделать анимацию ходьбы?"), 4, "RU sentence -> 4 tokens")
H.equal(Text.tokenize("")[1], nil, "empty string -> no tokens")
H.contains(Text.tokenize("R15 рига"), "r15", "alphanumeric token kept")

H.section("stem() strips inflection but keeps a usable root")
H.equal(Text.stem("анимации"), Text.stem("анимация"), "RU noun cases converge")
H.equal(Text.stem("running"), "runn", "EN -ing")
H.equal(Text.stem("keyframes"), "keyframe", "EN plural")
H.ok(Text.utf8Length(Text.stem("код")) >= 3, "short RU word not destroyed")
H.equal(Text.stem("ход"), "ход", "3-letter RU word untouched")

H.section("concepts() bridges RU and EN")
-- analyze() is the real entry point: it supplies both tokens and the raw
-- string, so phrase rules (negations) are evaluated too.
local function conceptsOf(s)
	return Text.analyze(s).concepts
end
H.contains(conceptsOf("как проиграть анимацию скриптом"), "animation", "RU -> animation")
H.contains(conceptsOf("how do I play an animation"), "animation", "EN -> animation")
H.contains(conceptsOf("как проиграть анимацию"), "play", "RU -> play")
H.contains(conceptsOf("анимация не работает"), "notworking", "RU -> notworking")
H.contains(conceptsOf("приоритет анимации"), "priority", "RU -> priority")
H.contains(conceptsOf("animation priority"), "priority", "EN -> priority")
H.contains(conceptsOf("R15 риг"), "r15", "rig version detected")
H.contains(conceptsOf("другие игроки не видят анимацию"), "replication", "replication concept")
H.contains(conceptsOf("IKControl настройка"), "ik", "IK concept")

H.section("concepts() avoids false positives")
H.notContains(conceptsOf("более сложный вопрос"), "attack", "'более' is not an attack")
H.notContains(conceptsOf("это идея"), "idle", "'идея' is not idle")

H.section("detectLanguage()")
H.equal(Text.detectLanguage("как сделать анимацию"), "ru", "RU detected")
H.equal(Text.detectLanguage("how to animate"), "en", "EN detected")
H.equal(Text.detectLanguage("R15"), "en", "latin only -> en")

H.section("analyze() removes stop words")
local a = Text.analyze("Как мне сделать анимацию бега?")
H.notContains(a.stems, "как", "stop word removed")
H.ok(#a.stems > 0, "stems produced")
H.contains(a.concepts, "animation", "concepts present in analyze()")

return H.summary()
