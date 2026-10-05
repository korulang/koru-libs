---
type: belief
id: frag-a-decls-primary-name-is-positional
provenance: Lars pull on stack's spelling — service(web, image:…) over service(name: "web", …); store:new(rows) already ruled it (2026-10-04)
ts: 2026-10-04
---

# A declaration's primary name is positional, and the parameter is `expr: Expression`

When a decl has one thing that is not optional — the name — it is the first
positional argument, not a `name:` kwarg. `std/store:new(rows, capacity:
16384)` set the convention; `koru/stack:service(db, image: "postgres:16")`
follows it. Bare identifier text, or a quoted string when the name isn't an
identifier — both land on the `expr` param.

The mechanism that makes it legal is the param type: `expr: Expression`
carries the captured expression *text* to the callee — the emitted call site
transports `"db"`, never a raw identifier splice — so `service(db, …)` does
not demand that `db` resolve as a binding. A `name: string` param is the
bug: it asks the emitter to emit `db` as a live expression.
