---
type: belief
id: frag-oshun-is-the-named-markup-layer
provenance: naming session 2026-10-20 — Lars ruled the stack's layer names; the markup language extracts from libs/ui into its own package
ts: 2026-10-20
---

# Oshun is the named markup layer; the layer split is the architecture

The naming ruling (Lars, 2026-10-20): **OMNI** is the OS-layer — the
workspace where the resource bridge's contents show (fleet/bridge-native,
no new name needed). **ORISHA** is the web layer — already iconic via the
deploy reactor. **OSHUN** is the markup/design layer — the orisha of
aesthetics and beauty; the name carries the goal, not just the grammar.

The name lands as a package boundary, following the `libs/ctx` extraction
precedent (`60b20a3`): `component` moves from `ui/index.kz` to
`oshun/index.kz`, call sites read `libs/oshun:component(seed, spec) { … }`.
The boundary is load-bearing, not ornamental — the transform emits plain
`std.store` inserts and has no solver dependency, so markup-only consumers
stop dragging ui's Clay `@cImport` (and its `compiler:requires` include
path) into their backends. The four probes now import `libs/oshun` alone;
`gallery_comp` imports both — Oshun authors the spec, ui renders it.

Division of labor: **oshun** owns MARKUP → spec-row seeds; **ui** owns the
OMNI WORDS → solver numerics; **clay** owns the solver.

2026-10-20, first real-tree witness: `clay/tests/spec_tree.k` converted
its 25-row hand-seeded `[tree]` spec to markup and renders
pixel-identical (frame-30 BMP `cmp`-clean against the pre-conversion
snapshot; the original binary re-ran deterministic). The conversion
caught two dormant bugs the probes never could: `[tree]` was read off
`inv.annotations` when the declaration carries it on
`flow.annotations`, so tree-edge emission never ran at all — and once
it ran, `parseNodes` read `open.items.len - 1` (stack depth) as the
parent index instead of the stack's entry value, which is only right
down a left spine. Lesson the frags already know, sharpened: a probe
family can pin a dialect's surface while a real consumer with a
deterministic oracle is still needed to prove the semantics.

Open path: `libs/ctx` promoted to `std/ctx` with call sites unchanged
(`dd42801`). If Oshun settles, `libs/oshun:component` promotes the same
way — the `libs/` qualifier is provisional by design.

Related:
[[frag-component-prop-is-a-reference-not-a-literal]] — the prop/literal
value ruling the extracted transform still enforces.
[[frag-ctx-is-a-scope-stack-resolved-once]] — the sibling extraction.
