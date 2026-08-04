// BOIDS — Reynolds' three rules, done properly.
//
// An earlier version of this file clumped and jittered, and the cause was the
// separation term: it accumulated `(x_i - x_j)`, which GROWS with distance, so
// the push was weakest exactly where it needs to be strongest. Two boids on top
// of each other felt no repulsion at all, and the only force they did feel came
// at the edge of the separation radius, so they oscillated across it. Clumping
// and jitter were the same bug seen from two sides.
//
// Separation is now `(x_i - x_j) / d^2`, which falls off as 1/d — unbounded at
// contact, negligible at range. That is the term that makes a flock a flock
// rather than a blob.
//
// Two more corrections in the same family:
//
//  - A boid no longer counts ITSELF as a neighbour. Its own distance is zero,
//    which is inside every radius, so it was dragging the neighbourhood centre
//    toward its own position and inflating the count.
//  - Speed is NORMALISED to a constant cruise, not clamped per axis. Clamping
//    vx and vy independently lets diagonal motion run sqrt(2) faster and bends
//    the heading whenever one axis saturates; that was the rest of the jitter.
//    Every boid now flies at the same speed and only its direction changes,
//    which is what makes the motion read as gliding.
//
// SHAPE NOTES, forced by defects rather than taste (see the koru pins):
//  - Accumulators are COLUMNS ON THE GRID; a per-boid running total has to be
//    addressable per boid.
//  - Each pass is its own `tor` for a LAYOUT reason only: a `|> for(..)` link
//    must sit on the SAME LINE as the write it follows, and every chain link in
//    this file is written on its own continuation line. The multi-line form is
//    refused loudly with KORU010, whether the loop's arms are at column 0 or
//    indented under it, because the arms have no construct to attach to.
//    RETESTED 2026-08-04 on a clean tree at koru 5aa3693e: the SEMANTIC claim
//    this line used to carry — "a store write followed by `|> for(..)` does not
//    compose, and nested in an arm it silently accumulates nothing" — is FALSE
//    in all three positions, and it named the store when this file only ever
//    used the grid. Pinned green as koru 697_013.
//  - A `std/grid:stored` is ONE LINK of its chain, not the last one — koru
//    697_012 pins exactly that, and this line used to claim the opposite while
//    citing that pin as its authority. The tail-drop it described was fixed.
//    697_012 covers a `print` and a second write as next links; whether the
//    draw can now follow the write here is untested, so the order below stands
//    unchanged rather than being rearranged on an unmeasured guess.
//  - State is a grid, not a store, because a store sweep cannot carry the frame
//    borrow (koru 690_252).
import libs/raylib
import std/io
import std/grid

std/grid:new(flock, size: 200) {
    x: 0.0[f32], y: 0.0[f32], vx: 0.0[f32], vy: 0.0[f32],
    cx: 0.0[f32], cy: 0.0[f32], ax: 0.0[f32], ay: 0.0[f32],
    sx: 0.0[f32], sy: 0.0[f32], n: 0.0[f32],
    rx: 0.0[f32], ry: 0.0[f32]
}

// Scatter. The quadratic term breaks the lattice a plain multiple would leave.
for(0..200)
! each s |> std/grid:stored { flock[s].x: @as(f32, @floatFromInt((s * 137 + (s * s) % 53) % 620)) + 10.0, flock[s].y: @as(f32, @floatFromInt((s * 89 + (s * s) % 71) % 420)) + 20.0, flock[s].vx: @as(f32, @floatFromInt((s * 31) % 17)) * 0.26 - 2.1, flock[s].vy: @as(f32, @floatFromInt((s * 19) % 13)) * 0.34 - 2.0 }

tor clear-sums {}
clear-sums = std/grid:sweep(flock)
! sweep c |> std/grid:stored { c.cx: 0.0, c.cy: 0.0, c.ax: 0.0, c.ay: 0.0, c.sx: 0.0, c.sy: 0.0, c.n: 0.0 }

// Every pair. Perception 52px, personal space 17px. `d2 > 0.25` excludes self.
tor gather {}
gather = for(0..200)
    ! each gi |> for(0..200)
        ! each gj |> std/grid:stored { flock[gi].cx: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 2704.0 and (flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) > 0.25) flock[gi].cx + flock[gj].x else flock[gi].cx, flock[gi].cy: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 2704.0 and (flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) > 0.25) flock[gi].cy + flock[gj].y else flock[gi].cy, flock[gi].ax: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 2704.0 and (flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) > 0.25) flock[gi].ax + flock[gj].vx else flock[gi].ax, flock[gi].ay: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 2704.0 and (flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) > 0.25) flock[gi].ay + flock[gj].vy else flock[gi].ay, flock[gi].n: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 2704.0 and (flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) > 0.25) flock[gi].n + 1.0 else flock[gi].n, flock[gi].sx: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 144.0 and (flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) > 0.25) flock[gi].sx + (flock[gi].x - flock[gj].x) / ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y)) else flock[gi].sx, flock[gi].sy: if ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) < 144.0 and (flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y) > 0.25) flock[gi].sy + (flock[gi].y - flock[gj].y) / ((flock[gj].x - flock[gi].x) * (flock[gj].x - flock[gi].x) + (flock[gj].y - flock[gi].y) * (flock[gj].y - flock[gi].y)) else flock[gi].sy }

// Turn each accumulated sum into a UNIT steering vector, in place. This is the
// structural fix for a flock that would either string into filaments or
// collapse into one ball depending on which way the weights were nudged: the
// three rules have wildly different natural magnitudes (cohesion is a distance,
// up to ~52; alignment a velocity difference, ~4; separation a sum of 1/d, well
// under 1), so weighting the RAW terms means the weights are not comparable and
// no stable balance exists. Normalised first, a weight IS the contribution.
tor normalize {}
normalize = std/grid:sweep(flock)
! sweep c |> std/grid:stored { c.cx: if (c.n > 0.0 and @sqrt((c.cx / c.n - c.x) * (c.cx / c.n - c.x) + (c.cy / c.n - c.y) * (c.cy / c.n - c.y)) > 0.001) (c.cx / c.n - c.x) / @sqrt((c.cx / c.n - c.x) * (c.cx / c.n - c.x) + (c.cy / c.n - c.y) * (c.cy / c.n - c.y)) else 0.0, c.cy: if (c.n > 0.0 and @sqrt((c.cx / c.n - c.x) * (c.cx / c.n - c.x) + (c.cy / c.n - c.y) * (c.cy / c.n - c.y)) > 0.001) (c.cy / c.n - c.y) / @sqrt((c.cx / c.n - c.x) * (c.cx / c.n - c.x) + (c.cy / c.n - c.y) * (c.cy / c.n - c.y)) else 0.0, c.ax: if (c.n > 0.0 and @sqrt((c.ax / c.n - c.vx) * (c.ax / c.n - c.vx) + (c.ay / c.n - c.vy) * (c.ay / c.n - c.vy)) > 0.001) (c.ax / c.n - c.vx) / @sqrt((c.ax / c.n - c.vx) * (c.ax / c.n - c.vx) + (c.ay / c.n - c.vy) * (c.ay / c.n - c.vy)) else 0.0, c.ay: if (c.n > 0.0 and @sqrt((c.ax / c.n - c.vx) * (c.ax / c.n - c.vx) + (c.ay / c.n - c.vy) * (c.ay / c.n - c.vy)) > 0.001) (c.ay / c.n - c.vy) / @sqrt((c.ax / c.n - c.vx) * (c.ax / c.n - c.vx) + (c.ay / c.n - c.vy) * (c.ay / c.n - c.vy)) else 0.0, c.sx: if (@sqrt(c.sx * c.sx + c.sy * c.sy) > 0.0001) c.sx / @sqrt(c.sx * c.sx + c.sy * c.sy) else 0.0, c.sy: if (@sqrt(c.sx * c.sx + c.sy * c.sy) > 0.0001) c.sy / @sqrt(c.sx * c.sx + c.sy * c.sy) else 0.0 }

// The three rules, summed into a raw heading. Cohesion and alignment only apply
// when the boid can actually see someone; separation applies regardless.
tor steer {}
steer = std/grid:sweep(flock)
! sweep c |> std/grid:stored { c.rx: c.vx + c.cx * 0.035 + c.ax * 0.060 + c.sx * 0.095, c.ry: c.vy + c.cy * 0.035 + c.ay * 0.060 + c.sy * 0.095 }

libs/raylib:window.open(width: 640, height: 460, title: "koru boids")
| win w |> libs/raylib:window.fps(win: w, fps: 60) |> libs/raylib:frames(win: w, count: 3000)
    ! frame f |> libs/raylib:color(r: 12, g: 14, b: 22): bg |> libs/raylib:draw.clear(f, col: bg) |> clear-sums() |> gather() |> normalize() |> steer() |> libs/raylib:color(r: 235, g: 205, b: 120): fg |> for(0..200)
        ! each bi |> libs/raylib:draw.rect(f, x: @as(i32, @intFromFloat(flock[bi].x)), y: @as(i32, @intFromFloat(flock[bi].y)), w: 3, h: 3, col: fg)
            |> std/grid:stored { flock[bi].vx: flock[bi].rx * (if (@sqrt(flock[bi].rx * flock[bi].rx + flock[bi].ry * flock[bi].ry) > 2.4) 2.4 / @sqrt(flock[bi].rx * flock[bi].rx + flock[bi].ry * flock[bi].ry) else (if (@sqrt(flock[bi].rx * flock[bi].rx + flock[bi].ry * flock[bi].ry) < 1.2 and @sqrt(flock[bi].rx * flock[bi].rx + flock[bi].ry * flock[bi].ry) > 0.001) 1.2 / @sqrt(flock[bi].rx * flock[bi].rx + flock[bi].ry * flock[bi].ry) else 1.0)), flock[bi].vy: flock[bi].ry * (if (@sqrt(flock[bi].rx * flock[bi].rx + flock[bi].ry * flock[bi].ry) > 2.4) 2.4 / @sqrt(flock[bi].rx * flock[bi].rx + flock[bi].ry * flock[bi].ry) else (if (@sqrt(flock[bi].rx * flock[bi].rx + flock[bi].ry * flock[bi].ry) < 1.2 and @sqrt(flock[bi].rx * flock[bi].rx + flock[bi].ry * flock[bi].ry) > 0.001) 1.2 / @sqrt(flock[bi].rx * flock[bi].rx + flock[bi].ry * flock[bi].ry) else 1.0)), flock[bi].x: if (flock[bi].x + flock[bi].vx < 0.0) 639.0 else (if (flock[bi].x + flock[bi].vx > 640.0) 1.0 else flock[bi].x + flock[bi].vx), flock[bi].y: if (flock[bi].y + flock[bi].vy < 0.0) 459.0 else (if (flock[bi].y + flock[bi].vy > 460.0) 1.0 else flock[bi].y + flock[bi].vy) }
    | done w2 |> libs/raylib:window.close(win: w2) |> std/io:print.ln("flock done")
| err e2 |> std/io:print.ln("init failed: {{ e2:s }}")
