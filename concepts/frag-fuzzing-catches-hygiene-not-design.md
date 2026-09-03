---
type: belief
id: frag-fuzzing-catches-hygiene-not-design
provenance: FUZZ_CHALLENGE re-ranked after Lars — the product is pristine binaries, not diagnostics (2026-09-02)
ts: 2026-09-02
---

# Fuzzing the language surface catches emission hygiene, not design — the division is deliberate (belief)

The product is the **pristine binary**; the diagnostic is the messenger. The
language surface is fuzzable by a primary property whose oracle is the artifact
itself: **pristine emission** — for every program, the toolchain either refuses
*before emitting*, or emits an artifact that compiles clean and runs correctly
(right output, exit 0, no leaks, no crashes, no UB). Any shape that makes the
compiler emit garbage Zig or a wrong binary is the wall — and clearing it may
require digging into the emitter, which is the point, not a reason to avoid the
shape.

Koru-level refusal is **ideal and secondary**: a clean raw-zig refusal that
happened before emission is a census row, not a wall; a lying diagnostic is
polish, never a gate. The void-consumer corner proved the ranking: the two
primary findings were emissions of garbage Zig (`=> void-sink()`, `=> err _`),
and the diagnostic lies were notes.

What fuzzing cannot find, and why the boundary is a feature: a design gap that
refuses *consistently and cleanly* (F3, nested-form propagation — KORU022 in
every spelling, no artifact ever exists, which under this doctrine is correct
behavior) is invisible to a generator; only the design intent marks it a
defect. A chip that pre-empts a *designed* diagnostic reads as "refused before
emission" — catching it needs a designed-diagnostic registry, not a fuzzer. So
the generator keeps the emitted artifacts pristine, and design review sees only
what only it can see. The division is the point, not a limitation to apologize
for.

The deliverable is the pinned wall — a shape that made the toolchain emit
something non-pristine, refused and pinned as a koru regression. A replay that
finds no wall still writes its census rows.

Open: the shape grammar's widening order (one axis per cleared replay); the
designed-diagnostic registry as the complement to the fuzzer; whether the
koru/regressions runner's fire-off seam becomes the generator's harness.
