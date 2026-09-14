---
type: belief
id: frag-store-columns-should-be-typed-as-their-domain
provenance: asteroids game-store review, 2026-09 — `lives: f32` questioned; i32 probe in a scratch clone compiled clean and ran death.k byte-identical
ts: 2026-09-05
---

# Store columns should be typed as their domain — counters and flags are i32, measures are f32 (belief)

`std/store` accepts typed columns (`i64/i32/f64/f32`, `char[N]`, owned
strings — the KORU161 diagnostic pins the set). The asteroids `game` row was
declared all-`f32` anyway: `score`, `lives`, `over`, `wave`, `rocks`,
`pending`, `seed` — seven counters and flags wearing float literals
(`lives: 3.0`, `g.over == 1.0`). The tell that this was drift and not a
decision: `bodies.seed` was `i32` while `game.seed`, the same concept in the
same file, was `f32`.

The conversion cost nothing and paid twice. Same-file `stored`/`query`
arithmetic on `i32` fields compiles and runs `death.k` byte-identical; the
shell loses three `@as(i32, @intFromFloat(...))` casts at the draw sites
because `draw.int` already wants what the column now holds. `bool` is not a
column type — flags stay `i32` 0/1, which is the honest ceiling the
diagnostic itself names.

The practice: when a store row mixes types, type each field by what it
holds — positions, velocities, timers, radii stay `f32`; counts, flags,
discriminants, and LCG seeds are `i32`. All-`f32` is a default that
accumulates, not a constraint. Cross-module `sim:KIND_SHIP` refs do not
resolve inside query guards (they leak literally into the emit), so kind
discriminants stay int literals at the shell and named constants inside the
sim.

One sharp edge worth pinning: an `if`-expression whose branches are all
comptime ints (`if (r > 40.0) 20 else 100`) needs an explicit
`@as(i32, ...)` when the result feeds an `i32` column — the emitter passes
the comptime_int through and Zig refuses it at runtime control flow.
