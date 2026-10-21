---
type: belief
id: frag-the-gates-walk-must-drive-the-raw-surface
provenance: fuzz_gate REF walk moved off ui:* words onto raw clay:el.*,
  2026-10-20 — per-side padding was one tor-call away and unreachable
ts: 2026-10-20
---

# The gate's walk must drive the raw surface

A differential gate that walks the oracle through the convenience dialect
can only verify what the dialect can currently spell. When the dialect's
words are narrower than the solver's declaration surface, the gate's reach
is bounded by the *words*, not the *solver* — a perfectly capable candidate
sits unverifiable behind a convenience layer that happens to be thin.

The failure mode is silent: the corpus looks rich (every construct the
dialect exercises), while features one tor-call away — per-side padding,
floating images, userData on raw paths — remain permanently outside
generation because no word exists to say them.

The fix is architectural, not additive: the oracle's walk must speak the
raw declaration bracket directly, pre-computing whatever the convenience
layer used to fold in (dock→sizing overrides, word→code maps). The
convenience layer keeps its own test path; the gate verifies *solvers*,
not words.

Measured 2026-10-20: koru-libs fuzz_gate's REF walk moved off `ui:panelx`
et al onto raw `clay:el.*` (el.cfg/el.clip/el.img/el.text), immediately
exposing that the raw bracket itself was narrower than the dialect —
el.cfg couldn't stamp userData, el.img couldn't float, el.text didn't
exist. Widening the raw surface WAS the capability growth; the per-side
padding feature rode in on it.

Open question: when the dialect gains asymmetric-pad words, the *word*
layer gets its own equivalence check (word → decl) separate from the
solver gate — two oracles, two courts.
