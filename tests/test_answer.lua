--[[ Tests for Brain/Answer: does the tutor pick the right answer? ]]

local Answer = _require("Brain.Answer")
local H = (function()
	local f = io.open(ROOT_DIR .. "/tests/helpers.lua", "r")
	local src = f:read("*a")
	f:close()
	return load(src, "@helpers.lua")()
end)()

local function askId(question, language)
	local result = Answer.ask(question, language)
	if result.kind == "knowledge" then
		return result.entry.id, result
	elseif result.kind == "lesson" then
		return "lesson:" .. result.lesson.id, result
	end
	return "fallback", result
end

H.section("Russian questions route to the right entry")
H.equal(askId("Почему моя анимация не работает?"), "kb-not-playing", "not working (ru)")
H.equal(askId("Анимация не проигрывается, что делать"), "kb-not-playing", "not playing (ru)")
H.equal(askId("Как проиграть анимацию из скрипта?"), "kb-how-to-play", "how to play (ru)")
H.equal(askId("Что такое приоритет анимации?"), "kb-priority", "priority (ru)")
H.equal(askId("Другие игроки не видят мою анимацию"), "kb-replication", "replication (ru)")
H.equal(askId("Чем отличается R6 от R15?"), "kb-r6-r15", "rig comparison (ru)")
H.equal(askId("Как опубликовать анимацию и получить id"), "kb-export", "export (ru)")
H.equal(askId("Как смешать две анимации плавно?"), "kb-blend", "blending (ru)")
H.equal(askId("Как добавить маркер события в анимацию"), "kb-events", "events (ru)")
H.equal(askId("Как анимировать дверь без Humanoid"), "kb-non-humanoid", "non-humanoid (ru)")
H.equal(askId("Как сделать анимацию меча в руках"), "kb-tool", "tool (ru)")
H.equal(askId("Как работает инверсная кинематика"), "kb-ik", "IK (ru)")
H.equal(askId("Игра лагает из-за анимаций"), "kb-optimization", "optimization (ru)")
H.equal(askId("Анимация пропала после смерти персонажа"), "kb-respawn", "respawn (ru)")

H.section("English questions route to the same entries")
H.equal(askId("My animation is not playing"), "kb-not-playing", "not working (en)")
H.equal(askId("How do I play an animation from a script?"), "kb-how-to-play", "how to play (en)")
H.equal(askId("What is animation priority?"), "kb-priority", "priority (en)")
H.equal(askId("Other players cannot see the animation"), "kb-replication", "replication (en)")
H.equal(askId("How to blend animations smoothly"), "kb-blend", "blending (en)")
H.equal(askId("How to export an animation and get the id"), "kb-export", "export (en)")
H.equal(askId("inverse kinematics IKControl setup"), "kb-ik", "IK (en)")

H.section("Deprecated API question")
H.equal(askId("humanoid:LoadAnimation deprecated что использовать"), "kb-deprecated", "deprecated API")

H.section("Language of the answer follows the question")
local _, ruResult = askId("Почему анимация не работает?")
H.equal(ruResult.language, "ru", "russian question -> ru answer")
local _, enResult = askId("Why is my animation not working?")
H.equal(enResult.language, "en", "english question -> en answer")

H.section("Explicit language override wins")
local _, forced = askId("Почему анимация не работает?", "en")
H.equal(forced.language, "en", "override respected")

H.section("Confident answers carry a lesson and score")
local _, playResult = askId("Как проиграть анимацию?")
H.ok(playResult.lesson ~= nil, "answer links to a lesson")
H.ok(playResult.score >= Answer.MIN_CONFIDENT_SCORE, "score above the confidence floor")
H.equal(playResult.snippet, "play-basic", "answer offers the right snippet")

H.section("Realistic phrasings that are not verbatim patterns")
-- These came from an evaluation sweep; they guard against regressions in the
-- concept rules, which are easy to break when adding new keywords.
H.equal(askId("как остановить анимацию"), "kb-stop", "stopping (ru)")
H.equal(askId("how to stop an animation"), "kb-stop", "stopping (en)")
H.equal(askId("как ускорить анимацию"), "kb-speed-change", "speed (ru)")
H.equal(askId("как сделать анимацию ходьбы"), "kb-walk-cycle", "walk cycle (ru)")
H.equal(askId("how to make a walk cycle"), "kb-walk-cycle", "walk cycle (en)")
H.equal(askId("как сделать чтобы нпс ходил"), "kb-npc", "npc movement (ru)")
H.equal(askId("my npc animation is frozen"), "kb-npc", "npc frozen (en)")
H.equal(askId("how to animate a door"), "kb-non-humanoid", "door (en)")
H.equal(askId("нужен ли Animator для двери"), "kb-non-humanoid", "door (ru)")
H.equal(askId("почему персонаж не анимируется"), "kb-not-playing", "not animating (ru)")
H.equal(askId("что такое Motor6D"), "kb-motor6d", "what is Motor6D")

H.section("Questions that route to a lesson rather than a KB entry")
H.equal(askId("animation looks robotic"), "lesson:1-4-easing-curves", "robotic -> easing lesson")
H.equal(askId("how do I sync footstep sounds"), "lesson:2-3-events", "footsteps -> events lesson")

H.section("No fallbacks on a realistic question sweep")
local sweep = {
	"как сделать анимацию ходьбы", "почему персонаж не анимируется",
	"как остановить анимацию", "анимация меча не видна другим",
	"что такое Motor6D", "как зациклить анимацию",
	"как сделать чтобы нпс ходил", "как ускорить анимацию",
	"нужен ли Animator для двери", "у меня лагает игра много нпс",
	"как импортировать из блендера", "не могу опубликовать анимацию",
	"how to stop an animation", "my npc animation is frozen",
	"how to make a walk cycle", "how to animate a door",
	"animation looks robotic", "how do I sync footstep sounds",
}
local fallbacks = 0
for _, question in ipairs(sweep) do
	if Answer.ask(question).kind == "fallback" then
		print("       fell back: " .. question)
		fallbacks = fallbacks + 1
	end
end
H.equal(fallbacks, 0, "all " .. #sweep .. " realistic questions answered")

H.section("Unrelated questions fall back instead of guessing")
local pizzaId, pizzaResult = askId("Какая погода завтра в Москве?")
H.equal(pizzaId, "fallback", "off-topic -> fallback")
H.equal(pizzaResult.kind, "fallback", "kind is fallback")

H.section("render() produces displayable lines")
local strings = { fallbackTitle = "T", fallbackBody = "B" }
local _, r = askId("Что такое приоритет анимации?")
local lines = Answer.render(r, strings)
H.ok(#lines > 1, "renders multiple lines")
H.equal(lines[1].kind, "title", "first line is the title")

local fbLines = Answer.render(select(2, askId("абракадабра")), strings)
H.equal(fbLines[1].text, "T", "fallback renders provided strings")

return H.summary()
