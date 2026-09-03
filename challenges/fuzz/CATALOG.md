# FUZZ_CHALLENGE catalog

Pristine-emission walls and census rows from `FUZZ_CHALLENGE.md`. The product
is the pristine binary: **primary** walls are shapes that made the toolchain
emit garbage or a wrong artifact; **secondary** notes are diagnostic polish.
Each wall is a koru regression plus a finding; each census row is a pristine
outcome with its behavior pinned.

The catalog is the long-running artifact; each replay is one slice through the
shape grammar.

## The gate (what every replay grades)

1. **Pristine emission** — refusal before emission, or an emitted artifact that
   compiles clean and runs correctly (right output, exit 0, no leaks, no
   crashes, no UB). Anything else = wall.
2. **Refusal cleanliness** (secondary, ideal-not-required) — refusals ideally
   carry `error[KORUnnn]` and tell the truth; a clean raw-zig refusal is a row.

## Walls — primary (pristine violations)

| Pin | Shape | Violation | Status |
|-----|-------|-----------|--------|
| koru `210_213` | `=> void-sink()` (call-shaped construct RHS) | koruc **emitted garbage Zig** — "expected ',' after initializer" — instead of refusing before emission | **cleared** — now PARSE003 at parse; no artifact ever emitted (194ca102) |
| koru `210_214` | `=> err _` (discard re-raise) | koruc **emitted garbage Zig** — "'_' used as an identifier" | **cleared** — now PARSE003 at parse (194ca102) |

## Notes — secondary (diagnostic polish, not gates)

| Pin | Shape | Note |
|-----|-------|------|
| koru `210_211` | `=> print.ln(f)` (call-shaped choke RHS) | refusal was clean (KORU100, frontend — no artifact) but the code was accidental; now PARSE003, the right category |
| koru `210_215` | `\| ok v \|> void-sink()` (bind-into-void) | clean refusal (KORU100) but the message lied about its own file; now names the cause ("has nowhere to go — takes no input") |

## Census — pristine, behavior pinned

| Pin | Shape | Outcome |
|-----|-------|---------|
| koru `210_216` | `\| ok _ \|> void-sink()` (discard-into-void, terminal) | pristine binary: compiles, runs, prints `sink` — the `_` discards, the void runs as a statement, nothing expects a return |
| koru `210_217` | `\| ok _ \|> void-sink() \|> value-sink(x: "z")` (void mid-chain) | pristine binary: compiles, runs, prints `sink` and nothing else — after a void the thread is dropped, the chain continues on explicit args |

## Non-walls — found, not fuzz-findable (design review's)

| Item | Why the fuzzer can't see it |
|------|----------------------------|
| F3 — nested-form propagation (`220_029`): the `=>` claim and the `|>` continuation both fail to claim inner branches in a nested chain (KORU022) | the compiler refuses **consistently and cleanly** — no artifact ever exists, which under this doctrine is correct behavior; only the design intent marks it a gap |
| Designed-diagnostic pre-emption (KORU102 → PARSE003 when the first chip over-reached) | artifact grading sees "refused before emission"; needs a designed-diagnostic registry, not a fuzzer |

## Replays

| Replay | Sweep | Yield | Outcome |
|--------|-------|-------|---------|
| 01 (2026-09-02) | the void-consumer corner — `\|>` / `=>` arm space, void tors | 2 pristine walls + 2 secondary notes + 2 census rows + 1 chip | primary walls cleared at parse (no artifact ever emitted); board byte-identical to baseline, +8 green pins. Seed replay — done by hand, which is exactly what the generator exists to stop repeating |
