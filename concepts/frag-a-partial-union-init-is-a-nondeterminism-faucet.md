---
type: belief
id: frag-a-partial-union-init-is-a-nondeterminism-faucet
provenance: clay percent-sizing fix, 2026-10-20 — the differential gate's
  only divergences traced to uninitialized union bytes in the binding
ts: 2026-10-20
---

# A partial union init at a cImport boundary is a nondeterminism faucet (belief)

When a binding constructs a C union by writing only the member it means,
the bytes it skips are not dead — they are live state for every C reader
that looks at the union through a different member. `sizing()` built
percent axes as `.{ .size = .{ .percent = f } }`: 4 bytes written into an
8-byte union, and Clay's height-propagation pass later clamped content
through `size.minMax.max` — reading whatever stack bytes happened to sit
there. Percent elements contributed garbage-capped heights to FIT parents;
the clamp bound was 68, 56, 38, or 0 depending on the stack, and the bug
was invisible until a second implementation disagreed deterministically.

The fix is byte-complete construction: `.{ .size = .{ .minMax = .{
.min = f, .max = 0 } } }` — `.percent` still reads `f` at offset 0, and
`minMax` reads a defined `{f, 0}` so `CloseElement`'s `max<=0 -> MAXFLOAT`
reset always fires instead of sometimes firing. The rule at every cImport
boundary: initialize the union's storage, not the union's spelling — count
bytes, not intent. Where the C side can only ever read member A, partial
init of member A is still wrong the day member B grows a reader.
