# FUZZ_CHALLENGE catalog

Pinned compiler walls and census rows from `FUZZ_CHALLENGE.md` — the language
surface's measured behavior. Each wall is a koru regression plus a finding; each
census row is an accepted shape with its runtime behavior pinned.

The catalog is the long-running artifact; each replay is one slice through the
shape grammar.

## The properties (the check every replay runs)

1. **Refusal hygiene** — refusal ⇒ stderr carries `error[KORUnnn]`. Raw Zig,
   panics, crashes = wall.
2. **Diagnostic truthfulness** — a diagnostic's claim must be consistent with
   the source it names.
3. **Acceptance census** — every compiled shape is a row, never silence.

## Walls

| Pin | Shape | Wall | Status |
|-----|-------|------|--------|
| koru `210_213` | `=> void-sink()` (call-shaped construct RHS) | refused only by emitted Zig ("expected ',' after initializer"), no Koru diagnostic | **cleared** — now PARSE003 invalid branch constructor name (194ca102) |
| koru `210_214` | `=> err _` (discard re-raise) | refused only by emitted Zig ("'_' used as an identifier") | **cleared** — now PARSE003 cannot construct from a discard (194ca102) |
| koru `210_211` | `=> print.ln(f)` (call-shaped choke RHS) | KORU100 from choke replication — accidental refusal, wrong category | **cleared** — now PARSE003, same rule (194ca102) |
| koru `210_215` | `\| ok v \|> void-sink()` (bind-into-void) | KORU100 "unused binding" while `v` appears in the source — a lie about its own file | **cleared** — now names the cause: "binding 'v' has nowhere to go — the continuation target 'void-sink' takes no input" (018922c8) |

## Census — accepted, behavior pinned

| Pin | Shape | Behavior |
|-----|-------|----------|
| koru `210_216` | `\| ok _ \|> void-sink()` (discard-into-void, terminal) | compiles, runs, prints `sink` — the `_` discards, the void runs as a statement, nothing expects a return |
| koru `210_217` | `\| ok _ \|> void-sink() \|> value-sink(x: "z")` (void mid-chain) | compiles, runs, prints `sink` and nothing else — after a void the thread is dropped, the chain continues on explicit args |

## Non-walls — found, not fuzz-findable (design review's)

| Item | Why the fuzzer can't see it |
|------|----------------------------|
| F3 — nested-form propagation (`220_029`): the `=>` claim and the `|>` continuation both fail to claim inner branches in a nested chain (KORU022) | the compiler refuses **consistently**; only the pyramid post's design intent marks it a gap |
| Designed-diagnostic pre-emption (KORU102 → PARSE003 when the first chip over-reached) | hygiene checks see "still refused"; needs a designed-diagnostic registry, not a fuzzer |

## Replays

| Replay | Sweep | Yield | Outcome |
|--------|-------|-------|---------|
| 01 (2026-09-02) | the void-consumer corner — `\|>` / `=>` arm space, void tors | 4 walls + 2 census rows + 3 compiler chips | walls cleared, board byte-identical to baseline, +8 green pins. Seed replay — done by hand, which is exactly what the generator exists to stop repeating |
