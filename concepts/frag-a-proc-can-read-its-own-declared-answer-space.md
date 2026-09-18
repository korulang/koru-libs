---
type: belief
id: frag-a-proc-can-read-its-own-declared-answer-space
provenance: odds — the Jev `criteria` map is built by enumerating the
  return union's f64-payload fields at comptime (2026-09-18)
ts: 2026-09-18
---

# A proc can read its own declared answer space (belief)

A `~proc` body splices into the event struct's `handler`, which means
`@This()` inside the body names the event struct and
`@typeInfo(@This().Output)` enumerates the union declared in the event
signature — at comptime, in Zig, inside the proc that produces it.

The consequence: **the answer space needs exactly one declaration.** A
judgment tor declares `| bug f64 | feature f64 | other f64` and its proc
reflects those names into the API request — the Jev `criteria` map is
the branch set, never spelled twice. Rename a branch and the wire
format follows; non-f64 payloads (`exhausted`, `err Err`) are excluded
by type, not by naming convention, so control branches and category
branches are the same declaration distinguished by payload.

Two corollaries worth holding:

- This is **pinned** — `200_COMPILER_FEATURES/230_EMITTER/230_019` in
  koru's suite runs a proc that enumerates its own f64-payload
  branches and `@unionInit`s the winner by reflected name. It was
  emergent when this frag was written; the splice contract is now
  ratified, and a change to it breaks a test, not a consumer.
- The reflectable surface is **field names + payload types** — and the
  field name *is* the metadata slot. The emitter quotes a bracketed
  branch name verbatim into the union field (`@"bug: Bug reports"`), so
  a `[tag: description]` pattern name carries both halves of a
  criterion: split on the first `:` and the key and its description
  come out of the same declared string. The "missing slot" was the
  name itself; `350_012` in koru's suite pins the round-trip and the
  name-equality dispatch.

## Instance

`koru/odds` `writeCriteria(Out, w)` + `pick`/`@unionInit(Out, f.name, p)`:
the tor declares `| [bug: Bug reports] f64` and the proc splits `f.name`
on `:` — `bug` becomes the criteria key Jev answers with, `Bug reports`
the description it reads. The returned `probabilities` arrive keyed by
tag, `pick` matches the tag against `branchKey(f.name)`, and the union
is init'd by the full pattern name. Verified by probe against the same
comptime path: the criteria map builds as `{"bug":"Bug reports",...}`
and a `[bug: Bug reports]` arm dispatches by name equality.
