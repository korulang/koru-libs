---
challenge: fuzz
kind: generator
status: standing
yields: one pinned compiler wall — a koru regression refusing a shape the toolchain can't yet refuse in its own terms
catalog: challenges/fuzz/CATALOG.md
family: compiler-surface
created: 2026-09-02
---

# FUZZ_CHALLENGE — stress the language surface until it breaks in Koru terms

A **replayable generator**, not a task and not a backlog. You run it from zero,
it hands back one **pinned compiler wall** — plus its census rows — and it is
never used up.

**Singular contestant is the default.** One sealed contestant per replay;
variance accumulates across replays, not inside a fleet.

## Purpose — explicit, and it is NOT a prettier todo

COMPONENT and COMPOSITION stress the **vaxis substrate**. This generator stresses
the substrate every package sits on — the parser / checker / emitter surface
itself. Two deliverables, in order of importance:

1. **Make the toolchain's refusals honest.** Every refusal must be a Koru
   diagnostic that is true about the source it names. A raw Zig error, a panic,
   a crash, or a claim the source contradicts is a wall.
2. **Census the language surface.** Every generated shape is either
   accepted-and-cataloged (with its runtime behavior pinned) or
   refused-and-pinned (a koru regression). No silent unmeasured corners.

A pinned hole beats a demo that compiled by dodging. That rule is the family's;
the fuzz family just applies it to the language instead of the widget.

## Why it exists now — the void-consumer corner (2026-09-02)

The `|>` / `=>` / `->` arm space was probed by hand and produced three hygiene
failures a shape-fuzzer with three cheap properties would have caught in
minutes:

- `=> void-sink()` and `=> err _` were refused only by the **emitted Zig**
  ("expected ',' after initializer", "'_' used as an identifier") — no Koru
  diagnostic at all.
- `| ok v |> void-sink()` was refused with "unused binding 'v'" while `v`
  appears in the source — a diagnostic that lies about its own file.

All three are now fixed and pinned (koru 210_211-217, 220_029; compiler chips
194ca102, 018922c8, 944d9cc9). The fuzz family exists so the NEXT corner is
found by the generator, not by a long session.

## The three properties — the check is cheap, the oracle is the source

1. **Refusal hygiene.** If koruc refuses, stderr must carry `error[KORUnnn]`
   (or a declared Koru error code). Raw Zig errors, panics, crashes = wall.
2. **Diagnostic truthfulness.** A diagnostic's claim must be consistent with
   the source it names — "unused binding 'v'" where `v` appears in the file is
   provably wrong from the generated source alone. No semantic oracle needed:
   the oracle is the program the fuzzer just wrote.
3. **Acceptance census.** A shape that compiles is a catalog row, not silence.
   Its runtime behavior gets pinned (exit code, output) or it is floated as
   needing a ruling.

## The replay loop

shape grammar → generate one program → `koruc` → check the three properties →
**wall** (pin a koru regression, float the finding, ship nothing fake) or
**catalog row** (accepted, with behavior). One sealed contestant per replay.

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
generator is that engine: it emits programs; the runner scores the properties.

## The honest boundary — what fuzzing cannot find

- **Design gaps that refuse consistently.** F3 (nested-form propagation,
  pinned 220_029) — the compiler refuses every spelling with KORU022. A fuzzer
  sees a stable refusal, not a defect; finding it required the pyramid post's
  design intent. Design review's, not the fuzzer's.
- **Designed-diagnostic pre-emption.** A chip that changes a known shape's
  refusal from its intended code (KORU102 → PARSE003) is invisible to hygiene
  checks. Catching it needs a designed-diagnostic registry pinning known shapes
  to their intended refusals — a registry, not a fuzzer.

The division is the point: the fuzzer makes the cheap surface airtight so the
expensive review only sees what only it can see.

## Yield law

One pinned wall per replay; a replay that finds no wall still writes its census
rows. The catalog is the long-running artifact; the walls are the deliverable.
