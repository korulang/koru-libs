# FRONTIER — `vaxis:run` as a transform

## `! <arm> <ident>` bindings are invisible to `! query` capture — CLOSED (2026-09-16)

`vaxis:run`'s generated `vaxis:step()` call carries the consumer's `!`
arms as continuations. A nested `std/store:query` subflow referencing an
outer arm binding emitted a bare name — `use of undeclared identifier
'k'` at backend build (KOPIUM `headed.k`).

**Diagnosis, narrower than first read.** The capture machinery already
threads arm bindings (`Cap.collectBindsOnPath`, store.qcaps.kz) — it
types them via `lookupBranch` on the PARENT invocation's event decl.
The transform pass runner is depth-first: inner transforms run BEFORE
outer ones, so `query` ran while the arm still hung on `run` — a
`[comptime|transform]` decl carrying the comptime ABI signature, not the
consumer's `! char` branch surface — and the lookup returned null. The
pre-transform run masked this because its event decl declared the arms.

**Fix:** `claims_descendants` on `run` — the designed
producer-before-consumer ordering. `run` now fires before descending
into its arm bodies; the next pass walks the rehomed tree and `query`'s
parent is `vaxis:step()`, whose decl carries `! char koru/vaxis:KeyData`.
One annotation, zero compiler changes. Repro `run_arm_capture.k` is now
a passing pin; `headed.k` builds clean.

**Still open:** wildcard-payload arms (`for`'s `! each *`) cannot be
typed by `lookupBranch` at all — the payload type isn't in the decl. An
`! each i` binding under a nested query still won't capture. Different
mechanism needed there (element-type inference), not blocking anything
today.
