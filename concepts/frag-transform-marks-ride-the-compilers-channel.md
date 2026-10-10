---
type: belief
id: frag-transform-marks-ride-the-compilers-channel
provenance: marks migration 2026-10 — koru merge `9f1dadf12` moved the
  transform runner's handled-witness from `.annotations` to `.marks`; the
  sqlite3 transform was an out-of-tree author the merge could not see
ts: 2026-10-10
---

# Transform marks ride the compiler's channel, never user annotations (belief)

koru-libs transforms are downstream authors on koru's marks contract, ruled
upstream in
`concepts/frag-the-at-namespace-is-the-compilers-side-channel.md` (koru):
compiler-internal `@...` strings — `@pass_ran` here — live on the invocation's
`.marks`, and `.annotations` belongs to user-authored annotation text alone.
This is not a new spelling; it is a ruled channel consumed from outside the
repo that rules it.

The marks merge migrated every producer inside koru's horizon — koru_std plus
the in-repo tests — and could not see this tree. A transform that keeps its
invocation's path while stamping the old field re-runs itself until
`TransformDidNotReplace`; one that changes the path escapes silently, which
makes the drift invisible to a green board that never needed the witness.

## The rule this file lands

When koru's marks architecture moves, every file in this tree that reads or
writes `@`-prefixed marker strings on AST nodes moves with it — read side and
write side together, `.annotations` passed through untouched.
