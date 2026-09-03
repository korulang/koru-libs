---
type: belief
id: frag-fuzzing-catches-hygiene-not-design
provenance: FUZZ_CHALLENGE planted after the void-consumer corner (2026-09-02) — four hygiene failures found by hand
ts: 2026-09-02
---

# Fuzzing the language surface catches hygiene, not design — the division is deliberate (belief)

The language surface is fuzzable by three cheap properties whose oracle is the
source the fuzzer just wrote: **refusal hygiene** (a refusal must be a Koru
diagnostic, never raw Zig), **diagnostic truthfulness** (a diagnostic's claim
must be consistent with the file it names), and **acceptance census** (every
compiled shape is a catalog row, never silence). The void-consumer corner
proved all three findable by hand in minutes — two zig-garbage refusals, one
lying "unused binding" whose target visibly appears in the source.

What fuzzing cannot find, and why the boundary is a feature: a design gap that
refuses *consistently* (F3, nested-form propagation — KORU022 in every
spelling) is invisible to a generator; only the design intent marks it a
defect. A chip that pre-empts a *designed* diagnostic (KORU102 → PARSE003)
reads as "still refused" — catching it needs a designed-diagnostic registry,
not a fuzzer. So the generator makes the cheap surface airtight, and design
review sees only what only it can see. The division is the point, not a
limitation to apologize for.

The deliverable is the pinned wall — a koru regression refusing a shape the
toolchain can't yet refuse in its own terms. A replay that finds no wall still
writes its census rows.

Open: the shape grammar's widening order (one axis per cleared replay); the
designed-diagnostic registry as the complement to the fuzzer; whether the
koru/regressions runner's fire-off seam becomes the generator's harness.
