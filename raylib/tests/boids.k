// BOIDS, on screen.
//
// State lives in a std/grid: fixed population, positionally addressed, no
// removal — which is exactly a flock, and which is what lets a counted `for`
// walk it inside the frame arm. A store sweep cannot, because the frame borrow
// does not survive into one (koru 690_252); see draw_per_entity.k.
//
// THE DRAW COMES BEFORE THE WRITE, AND IT HAS TO. A `std/grid:stored` silently
// discards the rest of its chain (koru 697_012), so `stored {..} |> draw.rect`
// renders a black window and reports nothing — which is exactly how this file
// looked on the first run. With the draw first, the write is the last link and
// swallows nothing. The cost is that the screen shows the position from before
// this frame's step, which at 60fps is invisible.
//
// INTEGRATE AND WRAP ARE ONE BLOCK, not two chained writes, for the same
// reason. It is also the better shape: a `stored` block is a single write whose
// right-hand sides all read pre-state, so the wrap sees the pre-move position
// exactly once.
import libs/raylib
import std/io
import std/grid

std/grid:new(flock, size: 160) { x: 0.0[f32], y: 0.0[f32], vx: 0.0[f32], vy: 0.0[f32] }

// Deterministic scatter — a cheap integer spread over the window, so the
// opening frame already looks like a flock rather than a line.
for(0..160)
! each s |> std/grid:stored { flock[s].x: @as(f32, @floatFromInt((s * 71) % 620)) + 10.0, flock[s].y: @as(f32, @floatFromInt((s * 137) % 440)) + 10.0, flock[s].vx: (@as(f32, @floatFromInt(s % 7)) - 3.0) * 0.5 + 0.15, flock[s].vy: (@as(f32, @floatFromInt(s % 5)) - 2.0) * 0.5 + 0.15 }

libs/raylib:window.open(width: 640, height: 460, title: "koru boids")
| win w |> libs/raylib:window.fps(win: w, fps: 60) |> libs/raylib:frames(win: w, count: 600)
    ! frame f |> libs/raylib:color(r: 12, g: 14, b: 22): bg |> libs/raylib:draw.clear(f, col: bg) |> libs/raylib:color(r: 235, g: 205, b: 120): fg |> for(0..160)
        ! each bi |> libs/raylib:draw.rect(f, x: @as(i32, @intFromFloat(flock[bi].x)), y: @as(i32, @intFromFloat(flock[bi].y)), w: 3, h: 3, col: fg)
            |> std/grid:stored { flock[bi].x: if (flock[bi].x + flock[bi].vx < 0.0) 639.0 else (if (flock[bi].x + flock[bi].vx > 640.0) 1.0 else flock[bi].x + flock[bi].vx), flock[bi].y: if (flock[bi].y + flock[bi].vy < 0.0) 459.0 else (if (flock[bi].y + flock[bi].vy > 460.0) 1.0 else flock[bi].y + flock[bi].vy) }
    | done w2 |> libs/raylib:window.close(win: w2) |> std/io:print.ln("flock done")
| err e2 |> std/io:print.ln("init failed: {{ e2:s }}")
