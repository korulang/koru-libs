---
type: belief
id: frag-retained-data-plus-immediate-projection-is-not-the-frame-cost
provenance: nanoui hillclimb boxes port, 2026-10 — gate-verified geometry, then measurement
ts: 2026-10-20
---

# Retained data plus immediate projection is not the frame cost (belief)

The easy story is that a retained spec store pays for what immediate-mode
view construction gets free — that re-deriving the projection from stored
rows must lose to rebuilding a flat tree of decls. Measured, it does not.
On nanoui's own hillclimb `boxes` scene (600 rounded, shadowed, moving
boxes — geometry proven identical instance-for-instance by
`clay/tests/bench_boxes_gate.k` against nanoui's painted dump before any
timing ran), the full koru path — spec query, row/leaf emission, Clay
solve, command drain — costs 0.089 ms per pass. nanoui's build + layout +
paint for the same frame: 0.067 ms. Same machine, ReleaseFast both, ~1.33x.

The composition matters more than the headline. Upstream Clay alone, racing
the same scene through nanoui's own twin, costs 0.058 ms — meaning the
dialect overhead the retained model actually adds (query + emission +
drain dispatch) is ~0.03 ms, and the single largest component in our frame
is the *shared* layout library. nanoui's own layout pass does the same
work in 0.018 ms — purpose-built flexbox beats vendored Clay roughly
threefold. The lever on frame CPU is the layout engine, not the data
model; the lever on *idle* cost is the pump (nanoui pauses its display
link and pays 0.00% CPU idle; our `frames` poll unconditionally — a
different, already-known gap).

Two disciplines this instance reinforces. The gate preceded the meter: the
same comparator that passed the real candidate failed a `gr`/`gc`-swapped
seed with 2247 divergences — a number only spoken after the oracle proved
it could say no. And the retained/immediate distinction is per-layer, not
per-system: nanoui rebuilds its element tree every frame too; what it
retains is below the tree (atlases, caches, a paused display link), what
we retain is above it (the spec store). "Retained vs immediate" is not a
verdict on an architecture — it is a question about which layer holds
what.

Relates to
[[frag-a-gate-cheaper-than-the-benchmark-it-mirrors-is-green-by-construction]]
— the gate's parameters are a claim about the reference's parameters; here
the gate's parameter is the painted instance stream itself, checked
element-for-element, not a weaker mirror of it.
