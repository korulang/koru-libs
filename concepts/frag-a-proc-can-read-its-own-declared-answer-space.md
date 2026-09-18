---
type: belief
id: frag-a-proc-can-read-its-own-declared-answer-space
provenance: odds — the Jev `criteria` map is built by enumerating the
  return union's f64-payload fields at comptime (2026-09-21)
ts: 2026-09-21
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

- This is **emergent, not ratified.** Nothing in the koru suite says a
  proc body may use `@This()`; it works because of how the emitter
  splices bodies today. A pin belongs in koru's regression suite — if
  the splice ever changes, every consumer breaks silently.
- The reflectable surface is **field names + payload types only.** What
  it cannot carry is per-branch metadata (a criteria *description*),
  because the union has no slot for it — the place descriptions want to
  live does not exist in the type yet.

## Instance

`koru/odds` `writeCriteria(Out, w)` + `@unionInit(Out, f.name, p)`:
criteria keys out, winning branch tagged back in — both driven by the
same comptime field list. Verified live: the inbox example's
`bug`/`feature`/`other` branches reached the Decisions API verbatim and
returned `probabilities` keyed by the same names.
