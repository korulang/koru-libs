---
type: belief
id: frag-a-service-variant-is-a-slot-redefinition
provenance: implementing per-build services in stack — the choice was between
  variant-as-patch (merge over base) and variant-as-redefinition (the decl IS
  the service under its build)
ts: 2026-10-05
tags: [stack, variants, decl-grammar]
---

# A `service(name)|build` variant is a full redefinition of the slot, not a patch (belief)

`service(db)|dev` does not merge fields over `service(db)` — under
`--build=dev` the variant decl IS the db service, whole spec. A partial body
is not an override that inherits the base's `image`; it is an incomplete
service and refuses for missing fields like any other decl.

Three consequences fall out:

- **The unmarked decl is the base for every build without a matching
  variant** — base + `|dev` + `|prod` means prod and dev each take their own
  spec; any other flag takes base.
- **Two decls sharing `(name, variant)` refuse** — the slot is claimed
  twice; there is no merge order to arbitrate.
- **A name whose decls all carry variants and none match the active build is
  absent** — `{{ db.x }}` on it refuses as gated-out, not undeclared.

The compiler-side enabling ruling: `|variant` on a `[norun]` decl is
declaration metadata, not proc dispatch (koru `310_138`, frag
`frag-a-norun-decls-variant-is-metadata`) — without it the call site emits a
`handler__dev` nobody declared.

Pinned by `stack/tests/variant_probe.k`, `dup_variant.k`,
`ref_gated_variant.k`.
