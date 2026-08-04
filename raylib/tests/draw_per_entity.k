// PER-ENTITY DRAWING, which bounce.k says is not available yet. It is — the
// state just has to live in a `std/grid` and the loop has to be a counted
// `for`, not a store sweep.
//
// bounce.k's header attributes the gap to the ambient-context wall on standing
// RULES (koru 690_006), and for rules that is correct. But the wall is wider
// than rules and narrower than "sweeps": what actually fails is a phantom-typed
// borrow crossing into a `std/store:query` arm, because a store sweep body is
// lifted into a DETACHED EVENT HANDLER and an outer binding can only reach it
// as a declared input — which a phantom-typed one has no way to be. Written as
// a query, this exact program is refused:
//
//     error[KORU030]: Phantom state mismatch: argument 'f' has no tracked
//     phantom state, but this event requires state '<frame>'.
//
// A `for` body is emitted as an INLINE BLOCK instead, referencing `f` straight
// out of the enclosing scope, so the frame borrow survives. A grid is
// positionally addressed and cannot remove a row, so it needs no sweep to walk
// — `boids[bi]` is a direct cell read. The two facts compose into the thing
// that was reported missing.
//
// The store-side defect is pinned upstream as koru
// `690_252_phantom_borrow_crosses_into_a_query_arm`. When it goes green, the
// same program can be written over a store with `! query`, and entities will be
// able to come and go. Until then, fixed-population rendering works.
//
// NOTE the loop binding is `bi`, not `i`: the emitted frame loop already has an
// `i` in scope and `! each i` produces "local constant 'i' shadows local
// variable from outer scope" from the Zig backend.
//
// RUNNING IT: raylib needs an unlocked display even for a HIDDEN window. On a
// locked screen GLFW cannot resolve a monitor and init fails with "Failed to
// determine Monitor to center Window" / "Failed to initialize platform". The
// library handles that correctly — the `| err` arm fires and the process exits
// 0 — so a locked screen looks like a clean failure rather than a crash, and is
// easy to misread as a code regression. It is not one.
import libs/raylib
import std/io
import std/grid

std/grid:new(boids, size: 4) { x: 0[i64], y: 0[i64] }

std/grid:stored { boids[0].x: 10, boids[0].y: 10 }
std/grid:stored { boids[1].x: 60, boids[1].y: 40 }
std/grid:stored { boids[2].x: 120, boids[2].y: 80 }
std/grid:stored { boids[3].x: 200, boids[3].y: 120 }

libs/raylib:window.open.hidden(width: 320, height: 200, title: "per-entity draw")
| win w |> libs/raylib:frames(win: w, count: 2)
    ! frame f |> libs/raylib:color(r: 20, g: 20, b: 30): bg |> libs/raylib:draw.clear(f, col: bg) |> libs/raylib:color(r: 240, g: 200, b: 80): fg |> for(0..4)
        ! each bi |> libs/raylib:draw.rect(f, x: @as(i32, @intCast(boids[bi].x)), y: @as(i32, @intCast(boids[bi].y)), w: 6, h: 6, col: fg)
    | done w2 |> libs/raylib:window.close(win: w2) |> std/io:print.ln("drew from a grid")
| err e2 |> std/io:print.ln("init failed: {{ e2:s }}")
