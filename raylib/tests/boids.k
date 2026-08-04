// BOIDS — actual flocking, on screen.
//
// Each boid looks at every other boid within a radius and steers three ways:
// COHESION toward the neighbourhood's centre, ALIGNMENT toward its average
// heading, SEPARATION away from anyone too close. That third term is what stops
// the flock collapsing into a point, and the interaction between the three is
// what makes the motion look alive rather than scheduled.
//
// O(N^2) per frame — 160 boids is 25,600 pair tests, which at 60fps is nothing.
// The benchmark port in koru does this properly with a spatial grid; here the
// point is legibility, not throughput.
//
// SHAPE NOTES, all forced by things that do not work yet:
//
//  - The accumulators are COLUMNS ON THE GRID, not a store singleton, because a
//    per-boid running total has to be addressable per boid.
//  - Each pass is its own `tor`. Chaining `for` after `for` inside one arm, or
//    a `for` after a write, does not compose today — a store write followed by
//    `|> for(..)` is rejected outright (KORU022) and the same shape nested in an
//    arm silently accumulates nothing.
//  - The grid write is always the LAST link of its chain, because a
//    `std/grid:stored` discards whatever is piped after it (koru 697_012). That
//    is why the draw precedes the write in `steer-draw`.
//  - The state lives in a grid rather than a store because a store sweep cannot
//    carry the frame borrow (koru 690_252).
import libs/raylib
import std/io
import std/grid

std/grid:new(flock, size: 160) {
    x: 0.0[f32], y: 0.0[f32], vx: 0.0[f32], vy: 0.0[f32],
    cx: 0.0[f32], cy: 0.0[f32], ax: 0.0[f32], ay: 0.0[f32],
    sx: 0.0[f32], sy: 0.0[f32], n: 0.0[f32]
}

// A cheap deterministic scatter. The multipliers are coprime with the window
// dimensions so the start positions do not fall on a lattice, which the first
// version of this file did — 160 dots in visible rows, moving in parallel.
for(0..160)
! each s |> std/grid:stored { flock[s].x: @as(f32, @floatFromInt((s * 137 + (s * s) % 53) % 620)) + 10.0, flock[s].y: @as(f32, @floatFromInt((s * 89 + (s * s) % 71) % 420)) + 20.0, flock[s].vx: @as(f32, @floatFromInt((s * 31) % 17)) * 0.14 - 1.2, flock[s].vy: @as(f32, @floatFromInt((s * 19) % 13)) * 0.18 - 1.1 }

// Pass 1 — clear last frame's neighbourhood sums.
tor clear-sums {}
clear-sums = for(0..160)
    ! each ci |> std/grid:stored { flock[ci].cx: 0.0, flock[ci].cy: 0.0, flock[ci].ax: 0.0, flock[ci].ay: 0.0, flock[ci].sx: 0.0, flock[ci].sy: 0.0, flock[ci].n: 0.0 }

// Pass 2 — every pair. Within 44px a boid counts as a neighbour and feeds
// cohesion and alignment; within 14px it also pushes back. The separation term
// is scaled by how close it is, so it grows sharply at contact.
tor gather {}
gather = for(0..160)
    ! each gi |> for(0..160)
        ! each gj |> std/grid:stored { flock[gi].cx: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 1936.0) flock[gi].cx + flock[gj].x else flock[gi].cx, flock[gi].cy: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 1936.0) flock[gi].cy + flock[gj].y else flock[gi].cy, flock[gi].ax: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 1936.0) flock[gi].ax + flock[gj].vx else flock[gi].ax, flock[gi].ay: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 1936.0) flock[gi].ay + flock[gj].vy else flock[gi].ay, flock[gi].n: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 1936.0) flock[gi].n + 1.0 else flock[gi].n, flock[gi].sx: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 196.0) flock[gi].sx + (flock[gi].x - flock[gj].x) else flock[gi].sx, flock[gi].sy: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 196.0) flock[gi].sy + (flock[gi].y - flock[gj].y) else flock[gi].sy }

libs/raylib:window.open(width: 640, height: 460, title: "koru boids")
| win w |> libs/raylib:window.fps(win: w, fps: 60) |> libs/raylib:frames(win: w, count: 3000)
    ! frame f |> libs/raylib:color(r: 12, g: 14, b: 22): bg |> libs/raylib:draw.clear(f, col: bg) |> clear-sums() |> gather() |> libs/raylib:color(r: 235, g: 205, b: 120): fg |> for(0..160)
        ! each bi |> libs/raylib:draw.rect(f, x: @as(i32, @intFromFloat(flock[bi].x)), y: @as(i32, @intFromFloat(flock[bi].y)), w: 3, h: 3, col: fg)
            |> std/grid:stored { flock[bi].vx: @min(@max(flock[bi].vx + (if (flock[bi].n > 0.0) (flock[bi].cx / flock[bi].n - flock[bi].x) * 0.0009 + (flock[bi].ax / flock[bi].n - flock[bi].vx) * 0.045 else 0.0) + flock[bi].sx * 0.011, -2.6), 2.6), flock[bi].vy: @min(@max(flock[bi].vy + (if (flock[bi].n > 0.0) (flock[bi].cy / flock[bi].n - flock[bi].y) * 0.0009 + (flock[bi].ay / flock[bi].n - flock[bi].vy) * 0.045 else 0.0) + flock[bi].sy * 0.011, -2.6), 2.6), flock[bi].x: if (flock[bi].x + flock[bi].vx < 0.0) 639.0 else (if (flock[bi].x + flock[bi].vx > 640.0) 1.0 else flock[bi].x + flock[bi].vx), flock[bi].y: if (flock[bi].y + flock[bi].vy < 0.0) 459.0 else (if (flock[bi].y + flock[bi].vy > 460.0) 1.0 else flock[bi].y + flock[bi].vy) }
    | done w2 |> libs/raylib:window.close(win: w2) |> std/io:print.ln("flock done")
| err e2 |> std/io:print.ln("init failed: {{ e2:s }}")
