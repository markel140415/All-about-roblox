# Architecture

How AnimTeacher is put together, and why.

## Design constraints

1. **Fully offline.** No HTTP, no API keys. Everything the tutor "knows" ships
   inside the plugin.
2. **One installable file.** Studio local plugins are a single script, but a
   700-line monolith is unmaintainable — hence a module tree plus a bundler.
3. **Testable outside Studio.** There is no Roblox runtime in CI, so all logic
   modules avoid Roblox APIs and the Studio-facing layer is thin and injected.
4. **Bilingual by construction.** Language is data, never hardcoded strings in
   view code.

## Layers

```
Main.luau                  ← the only file that touches `plugin` / `game`
  └── UI/App               ← views, navigation, actions on the place
        ├── UI/Theme       ← Studio theme colours
        ├── UI/Components  ← Instance factories
        ├── Brain/Answer   ← question → answer ranking
        │     └── Brain/Text     ← Cyrillic-aware NLP
        ├── Brain/Checks   ← inspects the user's Workspace/scripts
        ├── Core/Progress  ← completion state + persistence
        └── Data/*         ← lessons, knowledge, snippets, strings
```

Dependencies point downward only. `Data/*` depends on nothing, `Brain/*`
depends on `Data/*`, `UI/*` depends on both, and `Main` wires in Studio.

## Why the text engine is hand-written

Luau has no stemmer, and `string.lower` is byte-based: it silently leaves
Cyrillic untouched, so `"АНИМАЦИЯ"` never matches `"анимация"`. `Brain/Text`
therefore implements case folding over raw UTF-8 bytes, a UTF-8 aware
tokenizer, and light suffix stripping for both languages.

The cross-language bridge is the **concept layer**. Rather than translating,
surface forms in either language map onto shared concept ids:

```
"анимаци…", "animat…"  → animation
"приоритет", "priorit…" → priority
```

A Russian question can therefore match an English knowledge entry, and adding a
language later means adding prefixes, not duplicating the knowledge base.

**Phrase rules** handle what token matching cannot: negation. `"не работает"`
and `"not playing"` are matched against the whole string, because the meaning
lives in the combination. Without this, *"how does X work"* scores the same as
*"X does not work"* — an early version of this plugin got exactly that wrong.

## Ranking and the confidence floor

`Brain/Answer` scores every knowledge entry by concept overlap (10), literal
phrase hits (14), `must`-concept confirmation (6) and keyword stems (4).
Entries may declare `must` concepts that gate them entirely — this is what stops
the troubleshooting article from firing on every question containing the word
"animation".

If the best score is below `MIN_CONFIDENT_SCORE`, the tutor **refuses to
answer** and offers suggestions instead. Being wrong is worse than admitting
ignorance when teaching. A sweep of 18 realistic questions answers all of them;
a sweep of 8 off-topic ones falls back on all 8. Both are locked in as tests.

## Studio-facing code and injection

`Brain/Checks` receives an `env` table of services rather than calling
`game:GetService` itself, and `Core/Progress` receives a `store` with `get`/`set`
rather than touching `plugin:SetSetting`. That is what lets the test suite feed
in a fake game tree and a fake settings store.

Instance property reads are wrapped in `pcall` because `Source` is not readable
for every script type and a permission error must not break a lesson check.

## The bundler

`tools/bundler.py` rewrites `require(script.Parent.Foo)` into
`__require("Data.Foo")` and is shared by the build script and the test harness,
so module resolution can never drift between what is tested and what ships.

`tools/build.py` emits each module as a factory function into a table with a
caching `__require` shim, preserving ModuleScript semantics (evaluated once,
result cached). A cyclic require fails loudly instead of hanging.

## Testing strategy

| File | Covers |
|---|---|
| `test_text.lua` | Case folding, tokenizing, stemming, concepts, language detection |
| `test_answer.lua` | Question routing in both languages, confidence floor, regression sweeps |
| `test_data.lua` | Curriculum integrity: bilingual completeness, valid quizzes, resolvable cross-references, **no deprecated APIs in taught code** |
| `test_progress.lua` | Progress state, persistence, module status, workspace checks |
| `test_plugin.lua` | End-to-end: boots the built bundle in a Roblox API mock and drives the UI |

`test_data.lua` is deliberately strict. A broken lesson reference or a
`Humanoid:LoadAnimation` in a sample would teach the wrong thing, which is worse
than a crash — so those are test failures, not review comments.

`tests/roblox_mock.lua` implements enough of `Instance`, `Enum`, `UDim2`,
`Color3`, signals and the `Plugin` API to run the real plugin. The mock's
Instance proxy intercepts `Parent` assignment to maintain a real tree and fires
property-changed signals, so `widget.Enabled = true` builds the UI exactly as it
does in Studio.

## Known limitations

- The stemmer is heuristic, not linguistically correct. It optimises recall for
  a fixed vocabulary; it would need rework for general-purpose text.
- The knowledge base is curated, so genuinely novel questions fall back by
  design rather than being answered speculatively.
- `tests/roblox_mock.lua` models only the API surface this plugin uses. It is a
  test fixture, not a general Roblox emulator.
