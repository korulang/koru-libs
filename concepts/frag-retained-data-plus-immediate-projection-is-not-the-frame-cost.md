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
declare + solve, command drain — costs 0.087 ms per frame (lowest median,
`std/benchmarking:climb`). nanoui's build + layout + paint for the same
frame: 0.066 ms. Same machine, ReleaseFast both: we are behind, 1.32x, and
that binary did no paint at all (the drain phase measures 0). With real
paint through metal's offscreen surface (`clay/tests/bench_boxes_paint.k`,
pixel-gated against the window path), the whole CPU frame is 0.132 vs
nanoui's 0.079 including encode (1.67x), and GPU is 0.606 vs 0.424 (1.43x).
A frame number that leaves out a phase the competitor pays is not a
smaller deficit; it is an unmeasured one.

The composition, measured per phase (`clay/tests/bench_boxes_split1.k`):
the retained model's own work, spec query + colour derivation, is ~0.020
ms. Clay is ~0.067: handing it the tree costs ~0.034 and solving costs
~0.033, and both match raw C Clay, so the binding is free. nanoui's
build (tree + colours) is 0.035 and its solve is 0.015. The largest
component of our frame is still the shared layout library, but it costs
**twice** over: once to declare a tree the store already holds, once to
solve it. A solver that reads the rows replaces both halves. The lever on
*idle* cost is the pump (nanoui pauses its display link and pays 0.00% CPU
idle; our `frames` poll unconditionally — a different, already-known gap).

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
