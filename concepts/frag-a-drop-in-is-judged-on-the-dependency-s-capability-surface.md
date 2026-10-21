---
type: belief
id: frag-a-drop-in-is-judged-on-the-dependency-s-capability-surface
provenance: nativelayout vs clay decision, 2026-10-20 — a gate-verified
  faster candidate evaluated first on the reachable vocabulary, then
  correctly on the full declaration surface
ts: 2026-10-20
---

# A drop-in is judged on the dependency's capability surface, not the caller's exercised subset (belief)

When a home-grown replacement races a library, the denominator is the
library's *capability* surface — everything its declaration grammar can
express — never the subset the caller currently exercises. "We only use
four of its ten features" is a snapshot of today's call sites, not a bound
on tomorrow's requirements, and switching on that basis is premature
optimization with a lock-in tail: the day the dialect wants the fifth
feature, the swap was already made.

The wrong frame is easy to fall into because the evidence looks rigorous:
nl's stream was bit-identical to Clay's over every vocabulary item the
fuzz gate could generate — and that was *exactly* the trap. The generator
generates the dialect's reachable vocabulary, so bit-parity proved "nl
does what we do today," which is a weaker claim than "nl can do what Clay
can do." Those are different theorems and only the second justifies a
switch.

The right instrument is a capability ledger, not a corpus: enumerate the
dependency's full declaration surface (Clay's `ElementDeclaration` —
borders, aspectRatio, the 9x9 attach matrix, ELEMENT_WITH_ID attachment,
transitions, internal scroll state, element IDs), and classify each gap
as *additive port* (a field, a branch, a command kind — gate-verifiable
the day it lands) or *structural* (cross-frame state: IDs, transitions,
scroll momentum — where the replacement model may be deliberately
different, not deficient). nl measured ~2/3 of Clay's surface, all
additive except cross-frame state — so the ruling was: stay on Clay, keep
nl as a gate-verified candidate that grows feature-by-feature, flip a
flag later rather than hold a funeral now.

Relates to [[frag-a-gate-cheaper-than-the-benchmark-it-mirrors-is-green-by-construction]]
— a gate proving the exercised subset is green by construction on the
unexercised surface, same shape, different instrument.
