---
type: belief
id: frag-a-part-elaborates-into-every-consumer
provenance: nativelayout package split, 2026-10-20 — gallery_comp blew the
  6144MB compile-mem budget with `~part native` and passed without it
ts: 2026-10-20
---

# A ~part elaborates into every consumer — it splits source, not compile cost (belief)

`~part name` merges the part file into the module at load — the part's
declarations elaborate eagerly for **every consumer of the module**,
whether or not anything references them. A consumer that never names the
part's tors still pays the full frontend cost: `gallery_comp` (no `nl.*`
anywhere) exceeded the 6144MB compile-memory budget with `~part native`
in `libs/clay` and compiled normally without it, with byte-identical
backend output — the part's ~970 lines were elaborated, then dead-code
eliminated. Pure frontend tax.

So a `~part` is a source-organization device only. Heavy machinery that is
conditionally wanted — an alternate implementation, a candidate under a
differential gate, anything a consumer should opt into — belongs in its
own package where `import` is the cost gate. The nativelayout solver moved
from `clay/index.native.kz` (a part) to `nativelayout/index.kz` (its own
package): clay consumers pay zero, the gate imports it directly, nothing
else changed.
