---
challenge: fuzz
kind: frame
status: standing
yields: one pristine-emission wall — a shape that makes the toolchain emit garbage, or a refusal that happens after emission instead of before it
family: compiler-surface
created: 2026-09-02
---

# FUZZ_CHALLENGE — hunt the emissions that aren't pristine

A standing **generative frame**, not a task and not a backlog — its output
drains into the koru codebase as pins and fixes; it accumulates no artifact
catalog here. You run it from zero, it hands back one **wall** — a shape whose
treatment by the toolchain is not pristine — plus its census rows, and it is
never used up. **Self-ground first:** read `challenges/fuzz/CATALOG.md` — the
ledger of cleared corners and census rows — and generate from a slice of the
shape grammar no prior replay has cleared.

**Singular contestant is the default.** One sealed contestant per replay;
variance accumulates across replays, not inside a fleet.

## The product is the pristine binary — the diagnostic is the messenger

We are not making a language for humans. We are making a language for
**pristine binaries**. The toolchain's contract: for every program, it either
refuses **before emitting**, or it emits an artifact that compiles clean and
runs correctly. Anything else is a wall.

- **PRIMARY — pristine emission.** A generated program that makes the compiler
  emit garbage Zig, a wrong binary, a crashing binary, a leaking binary, or a
  binary that answers wrong = **wall**. The wall is the deliverable. It is
  acceptable — required — to dig into the emitter to clear it.
- **SECONDARY — Koru-level refusal.** Ideally a refusal carries a Koru
  diagnostic. A clean refusal via a raw Zig error is tolerated — the refusal
  happened before emission, the artifact never existed. Improving the
  diagnostic is polish, never the gate. We are not grading the messenger.

## Why it exists now — the void-consumer corner (2026-09-02)

The `|>` / `=>` / `->` arm space was probed by hand and produced **two
emissions of garbage**: `=> void-sink()` and `=> err _` made koruc emit
`backend_output_emitted.zig` that did not compile ("expected ',' after
initializer", "'_' used as an identifier"). Invalid programs, correct outcome
(no binary shipped) — but the emitted artifact was garbage, and the refusal
should have happened before emission ever ran. Both now refuse at parse
(koru 210_213, 210_214; chip 194ca102).

The generator exists so the NEXT garbage emission is found by the replay, not
by a long session.

## The check — the artifact is the oracle

For every generated program, run the pipeline and grade the artifact:

1. **Pristine emission (the gate).** Either the compiler refused before
   emission, or the emitted artifact compiles clean and the binary runs
   correctly — right output, exit 0, no leaks, no crashes, no UB. Any garbage
   or wrong artifact = wall.
2. **Refusal cleanliness (secondary, ideal-not-required).** Refusals ideally
   carry `error[KORUnnn]` and say something true about the source. A clean
   raw-zig refusal is a census row, not a wall; a refusal with a lying message
   is a polish note, not a gate.

## The replay loop

shape grammar → generate one program → run the pipeline → grade the artifact →
**wall** (pin a koru regression, float the finding, dig into the emitter as
needed) or **census row** (pristine: accepted with behavior pinned, or refused
cleanly before emission).

### Shape grammar (v1 — the arm/chain space)

- branch names: plain, quoted `[pattern]`, backtick, payloadless, payload-carrying
- binders: named, `_` discard, none
- arrows: `|>` continuation, `=>` construct, `->` produce
- RHS kinds: call, literal, identifier, discard, re-raise, record constructor
- chain forms: point-free, nested (arrow), mixed
- tors: void, payload, obligation-carrying, effect resumes (`!`)

Seeded by the void-consumer corner; widen one axis per cleared replay.

## The harness seam

The koru/regressions runner reserves the fire-off seam in its design doc:
"can fire off external engines (mutation / AST-rewrite fuzzing) as jobs." The
generator is that engine: it emits programs; the runner grades the artifacts.

## The honest boundary — what fuzzing cannot find

- **Design gaps that refuse consistently.** F3 (nested-form propagation,
  pinned 220_029) — the compiler refuses every spelling with KORU022. A fuzzer
  sees a stable, clean refusal — no artifact ever exists, which under this
  doctrine is *correct behavior*. Finding it required the design intent.
  Design review's, not the fuzzer's.
- **Designed-diagnostic pre-emption.** A chip that changes a known shape's
  refusal code is invisible to artifact grading. Catching it needs a
  designed-diagnostic registry — a registry, not a fuzzer.

The division is the point: the fuzzer keeps the emitted artifacts pristine, so
design review sees only what only it can see.

## Yield law

One wall per replay — a shape that made the toolchain emit something
non-pristine, pinned as a koru regression and cleared in the emitter. A replay
that finds no wall still writes its census rows. A pinned hole beats a demo
that compiled by dodging.
