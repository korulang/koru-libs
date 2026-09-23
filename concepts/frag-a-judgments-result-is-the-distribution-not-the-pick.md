---
type: belief
id: frag-a-judgments-result-is-the-distribution-not-the-pick
provenance: koru/odds ask/decode split, 2026-09-21 — pick() iterated the full
  probabilities map to argmax or sample, then unionInit'd only the winner's p;
  the map that produced the verdict was thrown away at the same line that
  consumed it
ts: 2026-09-21
---

# A judgment's result is the distribution, not the pick (belief)

A System One answer is a *distribution over the answer space* — that is what
the API returns, and it is the honest unit. Decoding it (argmax, sample) is a
second, separate act that is pure, free, and repeatable. Fusing the two in one
tor call discards the map at the moment it is consumed: a `yes` at 0.51 with
the runner-up at 0.49 and a `yes` at 0.99 return the same shape, and the
margin — the very thing a gate wants to abstain on — is unrecoverable.

The corrected ontology: the ask (`*.map`) is the obligation — network, fuel,
the single judgment surface — and returns the whole distribution as a
synthesized struct (`DistOf(Space)`), confidence fields included. The decode
(`*.pick` argmax / `*.draw` sample) is a pure function over that struct: no
fuel, no network, and repeatable — argmax *and* sample from one ask, where the
fused shape needed two calls. The phantom decode policy (`greedy`/`chaotic`)
belongs on the decode, where it always semantically lived; the ask is
mode-agnostic.

The grammar pin that shaped the carrier is measured, not chosen: a tor cannot
derive a payload from its own `@This().Output` (Zig circularity), a sibling
tor's Output dead-strips when uninvoked, and `-> NamedUnion` produce is a
bare return — `| branch` arms don't dispatch on its tag (KORU021). So the
canonical answer space is a module-level union (`FeelsSpace`), decode tors
re-spell the branches for continuation matching, and `pick`/`draw` assert the
two spellings agree at comptime — drift is a compile error, not silence.

**Open:** the one language change that dissolves the re-spelling — a
union-typed produce dispatching `| branch` arms on its tag — is a floated
compiler finding, unbuilt.
