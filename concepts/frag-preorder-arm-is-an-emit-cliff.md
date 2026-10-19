---
type: belief
id: frag-preorder-arm-is-an-emit-cliff
provenance: gallery_comp handles-as-identity refactor — bisected compile times across five probes (2026-10-19)
ts: 2026-10-19
---

# The preorder arm's own continuation list is an emit cliff

The backend's `emitSubflowContinuationsWithDepth` +
`valueReferencesBinding` rescans binding references per continuation step
per depth. In a program whose `! frame` handler already carries a large
subflow, the `! preorder` arm's *own* continuation list sits at the knee
of that curve: adding `[id]h` to the arm destructure, or an `insert`
step at the arm's top level, took the backend past 30 minutes versus a
~13s baseline compile.

The granularity matters — not everything inside the arm is hot. A plain
`stored` step at arm top compiled in 13s. `[id]ih` on a *nested* `! query`
arm *inside* the preorder arm's subflow compiled in 12.5s. A `query` arm
on a different handler arm entirely — free. So the pathology tracks the
preorder arm's own continuation list and destructure, not nested arms
and not sibling arms on other handlers.

Working shape: write substructure that needs to add sites or bindings
*outside* the preorder arm — a sibling top-level `query` arm can tag
rows into a membership store; seed-chain `| row h` bindings are already
row handles and can be captured into world fields or written into a
self-handle column (`spec[h].hid: h`) so later passes read identity as a
plain field.

Open: the same cliff presumably guards `rule` arms and any standing
arm whose continuation list is long — unmeasured. The fix is in the
emitter, not the consumer: `valueReferencesBinding`'s rescan should be
proportional to value size, not multiplied by steps × depth.
