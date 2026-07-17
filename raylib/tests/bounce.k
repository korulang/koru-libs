// STORE-AS-GAME-STATE, round 2 — the O13-coherent shape, all landed:
// entities in a plural store; MOVEMENT is a top-level standing rule
// ([name(movement)]); REPORT depends_on(movement); the ! frame body fires
// one std/store:stripe(sprites) per frame — rules run in depends_on topo
// order (movement advances positions, then report prints them). Integer
// state, fixed velocities: fully deterministic.
//
// Rung note: per-entity DRAW rules need the frame borrow inside a rule
// body, which the ambient-context wall (koru 690_006) correctly forbids —
// rule context / parameterized stripe is the named next design step. This
// round proves the state half; the frame body draws only the clear.

import libs/raylib
import std/io
import std/store

std/store:new(sprites) { x: i64, y: i64, vx: i64, vy: i64 }

std/store:insert(sprites) { x: 10, y: 10, vx: 3, vy: 2 }
| row _ |> _
| full |> _
std/store:insert(sprites) { x: 50, y: 20, vx: 4, vy: 1 }
| row _ |> _
| full |> _
std/store:insert(sprites) { x: 30, y: 40, vx: 1, vy: 5 }
| row _ |> _
| full |> _

// Chained single-field writes — one atomic unit per the chain-envelope
// ruling. (A single multi-field stored block through the cursor is pinned
// red as koru 690_038: `unknown store '<s>[__koru_qrow]'`.)
[name(movement)]std/store:query(sprites)
! query { entity.x, entity.y, entity.vx, entity.vy } |> std/store:stored { entity.x: entity.x + entity.vx } |> std/store:stored { entity.y: entity.y + entity.vy }

[name(report)|depends_on(movement)]std/store:query(sprites)
! query { entity.x, entity.y } |> std/io:print.ln("sprite at {{ x:d }},{{ y:d }}")

libs/raylib:window.open.hidden(width: 320, height: 200, title: "bounce round 2")
| win w |> libs/raylib:frames(win: w, count: 4)
    ! frame f |> libs/raylib:color(r: 20, g: 20, b: 30): bg |> libs/raylib:draw.clear(f, col: bg) |> std/store:stripe(sprites)
    | done w2 |> libs/raylib:window.close(win: w2) |> std/io:print.ln("ran 4 frames of movement stripes")
| err e |> std/io:print.ln("init failed: {{ e:s }}")
