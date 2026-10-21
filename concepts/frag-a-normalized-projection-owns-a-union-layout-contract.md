---
type: belief
id: frag-a-normalized-projection-owns-a-union-layout-contract
provenance: session
ts: 2026-10-20
---

A normalized projection is not just a list of fields — it is a contract
about which union members each field is allowed to read. When the oracle
packs heterogeneous payloads into a C union (Clay's renderData), reading
the wrong member's slot is not a type error; it silently reinterprets live
bytes. Some misreads are harmlessly deterministic (zeroed tails), and some
are nondeterministic faucets (reading `rectangle.cornerRadius` on a TEXT
command lands mid-`stringContents` — pointer bits, ASLR-stable within a
run, garbage across runs and impossible for the candidate to match).

So the rule when the projection grows: (1) add the field on both sides of
the gate at once — emitter AND comparator — a capability the comparator
cannot parse is unverified no matter what the solvers do; (2) declare,
per command kind, which reads are real payloads versus zeroed slots versus
guarded-to-zero misreads, and let the comparator compare only the real
kinds; (3) treat accidental union alignments as discovered contracts, not
luck — `overlayColor.color` aliasing `rectangle.backgroundColor` turned
"no projection change needed" into "kind 7's color is now a compared
field."

The cheap audit when adding a field: for every command kind, ask what
bytes sit at that offset in each union member — real, zero, or noise.
Noise means the emitter needs a guard.
