---
type: belief
id: frag-preorder-arm-is-an-emit-cliff
provenance: gallery_comp handles-as-identity refactor — bisected compile times across five probes (2026-10-19); cliff fixed at the root same day
ts: 2026-10-19
---

# The preorder arm's own continuation list was an emit cliff — fixed

The backend's `emitSubflowContinuationsWithDepth` used to rescan each
continuation subtree per (binding, group) pair at every nesting level —
`valueReferencesBinding` re-tokenizing nested arms' values once per
ancestor. In a program whose `! frame` handler already carries a large
subflow, the `! preorder` arm's *own* continuation list sat at the knee
of that curve: adding `[id]h` to the arm destructure, or an `insert`
step at the arm's top level, took the backend past 22 minutes versus a
~13s baseline compile.

The granularity mattered — not everything inside the arm was hot. A
plain `stored` step at arm top compiled in 13s. `[id]ih` on a *nested*
`! query` arm inside the preorder arm's subflow compiled in 12.5s. A
`query` arm on a different handler arm entirely — free.

Fixed in koru `5f3caac15`: the needs_binding question is answered from
per-continuation referenced-name sets built bottom-up once per
`emitSubflowContinuations` entry — filtered through the same
`valueReferencesBinding` acceptance, so emitted output is unchanged
(gallery_comp's output_emitted.zig is byte-identical pre/post). The
cliff reproducer now compiles in ~17s.

The workaround shapes this belief introduced remain valid, merely
unforced: seed-chain `| row h` bindings as captured spec handles and
the `spec[h].hid: h` self-handle column are how gallery_comp carries
identity — they read fine on their own terms. What the fix removes is
the obligation: `[id]` on the preorder arm or an in-arm `insert` is no
longer a compile-time promise.

Open (smaller now): whether the same pattern still lurks in
`collectBoundNames`, which also walks each level's subtree per
recursion depth — pointer-walking, not string-scanning, so unmeasured
rather than alarming.
