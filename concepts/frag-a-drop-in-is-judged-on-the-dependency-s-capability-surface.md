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

Evolution (2026-10-21, after the additive surface completed and the ui
census ran): the denominator is not one surface — it is layered by
entry point. ui's dialect path reaches a strict subset of Clay (no
element ids, no hover, no clip, floating only ATTACH_TO_ROOT +
LEFT_TOP/LEFT_TOP): through that path nl's absent-reachable set is
ZERO — every feature the dialect can spell is ported and gated cold
and warm. The raw `el.*` bracket reaches nearly everything and is the
gated dev/test surface. Clay APIs with no binding at all (PointerOver,
GetElementData, transitions, query scroll offset) are unreachable from
either path — they are the true remaining denominator, and porting the
binding would precede porting the solver support. The census also
collapsed the last correctness caveat: ui's floating always resolves
against the root container's constant box, so even the evolving-tree
staleness class is unreachable through the dialect. The doctrine
stands — judge on capability, not the exercised subset — but the
capability surface is what the BINDINGS can spell, not what the
vendored library contains.

Relates to [[frag-a-gate-cheaper-than-the-benchmark-it-mirrors-is-green-by-construction]]
— a gate proving the exercised subset is green by construction on the
unexercised surface, same shape, different instrument.
