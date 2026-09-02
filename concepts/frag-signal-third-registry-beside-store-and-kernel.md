---
type: belief
id: frag-signal-third-registry-beside-store-and-kernel
provenance: koru/signal v0 land — breath_demo.k, suite pins, codegen oracle parity, korulang journal ep1
ts: 2026-09-02
---

# koru/signal is the third std-shaped registry — store, kernel, signal (belief)

Koru already names **collections** (`std/store`) and **compute over collections**
(`std/kernel`). **koru/signal** names **stateful models on typed wires** that
you tick on **your clock**.

The design move is the same in all three:

- declare a shape
- cross a compile boundary (`:init`)
- operate by name on a registered instance

Store owns entity lifetime; kernel owns fused iteration; signal owns carried filter
state while the host owns time. That is WMFX-shaped event-rate emit (init/block,
`@unit` wires, no sample transport) with a Koru host surface — not a JSFX plugin
host, though the opcode belt descends from the JSFX/EEL2 → Zig transpiler.

v0 is honest about the seam: the **host contract** (`:shape`, `const`, `:init`,
`:tick`, bind-first wiring) is Koru that compiles today. **Model tick bodies**
ship pre-emitted until host syntax for `block` closes the weld. The bet is
correctness and wiring first — oracle parity across emit paths, suite pins,
selective link — not throughput marketing.

The aspiration is narrow and load-bearing: **wire and tick a named model in
seconds now**; **author new physics in the same surface** once the weld closes.
Audio-rate DSP remains on the same emit belt when needed; the ULP=0 sweep is
inherited machinery, not the product definition.

Open: dynamic registry (third model without editing `index.kz`); graph surface
at event rate; model bodies as real Koru host syntax.
