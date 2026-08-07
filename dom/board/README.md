# DOM_GAUNTLET — the board

**Computed only. Monotonic. In-tree.**

An autonomous loop is *watched*, not asked. This directory is how a rung-1
gauntlet earns the right to run without a human between rounds: the board is
readable mid-run by design, so Lars can glance at progress without stopping it.

## Per round, the board records four things

| field | meaning |
|---|---|
| **bar** | what the reference requires — operations conformant, out of N |
| **current** | what `koru/dom` achieves, measured this round |
| **delta** | current minus previous round |
| **what moved** | which operations changed verdict, and why |

Plus the two honesty numbers that gate everything:

- **`cant_tell`** — the closer's own unresolved fraction. If this is not small,
  no other number on the board means anything.
- **`js_escape`** — the fraction of the app that fell out to `|js` host lines.
  The second headline metric, and arguably the more valuable one: it is the
  feature-mining count, and it is what a stopwatch can never tell you.

## The rule

**Nothing here is written by hand. Ever.**

A hand-patched number is a corrupted instrument steering an unsupervised fleet.
Plateau must be *computed* from this history, never felt — which is only true if
every row got here the same way.

Same contract the hub holds: computed only, provenance visible, freshness
visible.

## Files

- `history.jsonl` — one object per round, append-only. The monotonic record.
- `latest.md` — rendered from the last line of `history.jsonl`. Human-readable.

Both are generated. If you find yourself editing either, the generator is the
thing that needs fixing.
