---
type: belief
id: frag-regressions-runner-gates-the-instrument-layer
provenance: koru/regressions v4 — output pins, ledger history, selection; 13/13 suite on koruc 0.1.7
ts: 2026-09-02
---

# koru-libs verification belongs in the language — the instrument layer gates on koruc (belief)

koru-libs packages exist to surface toolchain gaps, so a red suite that names
the compiler is a legitimate verdict there — not a harness failure. The
instrument layer's verification therefore belongs in-language:
`koru/regressions` runs the suite through `koruc suite.k test` and gates
(output pins, ledger history, exit-1 regression detection, selection).

The bootstrapping hazard that blocks the same move for the language's own
ground truth — the runner is compiled by the compiler it tests, so a compiler
break could take down the verification layer exactly when it is needed — is
contained at the instrument layer, where the fallback (the koru repo's bash
harness) is always intact and independent. That containment is the reason the
leap is safe here and must be staged there.

Staging is the ruling: koru-libs proves the runner; the koru repo follows only
after demonstrated parity, with its harness kept as the oracle for
differential testing of the runner itself. The production precedent already
exists — `koruc site.k deploy` runs korulang.org — so the machinery is the
product's own pattern, not a bespoke bet.

Open: fingerprinting (transitive import closure) vs last-run ledger; whether
the koru repo's accreted walls (the 223/227 negative wall) can be reproduced
by runner predicates without drift; exact-output snapshots + autoupdate land
together (v2); the runner must stay on koru's stable core so a last-known-good
koruc always builds it.
