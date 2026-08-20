// main.k — Koru Asteroids, slice two: the field is alive.
//
// Ship (rotate/thrust/drag/wrap) + three asteroids that drift at constant
// velocity and wrap. Every rule lives in sim.k, bound here per frame (tor
// calls are not expressions, KORU104). State is grids; no conditional
// writes yet (the surface doesn't prove them — bullets/impacts are the next
// pass).
//
// Claim: 900 no-input frames leave the ship exactly centered and the
// asteroids exactly where constant-velocity + wrap puts them. The close-out
// prints every position — the run itself is the receipt. Numbers in the
// prints are deterministic (`:f` rounded), so humans can eyeball drift.

import std/io
import std/grid
import libs/raylib
import sim

std/grid:new(astro, size: 3) {
    x: 0.0[f32], y: 0.0[f32], dx: 0.0[f32], dy: 0.0[f32], r: 0.0[f32]
}

for(0..3)
! each a |> std/grid:stored {
    astro[a].x: if (a == 0) 600.0 else (if (a == 1) 150.0 else 400.0),
    astro[a].y: if (a == 0) 150.0 else (if (a == 1) 400.0 else 550.0),
    astro[a].dx: if (a == 0) -40.0 else (if (a == 1) 35.0 else -25.0),
    astro[a].dy: if (a == 0) 25.0 else (if (a == 1) -20.0 else -30.0),
    astro[a].r: if (a == 0) 45.0 else (if (a == 1) 35.0 else 55.0)
}

std/grid:new(ship, size: 1) {
    x: 400.0[f32], y: 300.0[f32],
    vx: 0.0[f32], vy: 0.0[f32], rotation: 0.0[f32]
}

libs/raylib:window.open(width: 800, height: 600, title: "koru asteroids")
| win w |> libs/raylib:window.fps(win: w, fps: 60) |> libs/raylib:frames(win: w, count: 900)
    ! frame f
        |> libs/raylib:input.key.down(key: 263): left_held
        |> libs/raylib:input.key.down(key: 262): right_held
        |> libs/raylib:input.key.down(key: 87): thrusting
        |> sim:thrust-dx(vx: ship[0].vx, rotation: ship[0].rotation, thrusting, dt: 0.016666): tvx
        |> sim:drag-x(vx: tvx, dt: 0.016666): dvx
        |> sim:thrust-dy(vy: ship[0].vy, rotation: ship[0].rotation, thrusting, dt: 0.016666): tvy
        |> sim:drag-y(vy: tvy, dt: 0.016666): dvy
        |> sim:rotation-delta(left: left_held, right: right_held, dt: 0.016666): drot
        |> sim:wrap-x(x: ship[0].x + dvx * 0.016666, width: 800.0): nx
        |> sim:wrap-y(y: ship[0].y + dvy * 0.016666, height: 600.0): ny
        |> sim:bullet-tick(x: astro[0].x, y: astro[0].y, dx: astro[0].dx, dy: astro[0].dy, t: 0.0, dt: 0.016666): a0t
        |> sim:wrap-x(a0t.x, width: 800.0): a0x
        |> sim:wrap-y(a0t.y, height: 600.0): a0y
        |> sim:bullet-tick(x: astro[1].x, y: astro[1].y, dx: astro[1].dx, dy: astro[1].dy, t: 0.0, dt: 0.016666): a1t
        |> sim:wrap-x(a1t.x, width: 800.0): a1x
        |> sim:wrap-y(a1t.y, height: 600.0): a1y
        |> sim:bullet-tick(x: astro[2].x, y: astro[2].y, dx: astro[2].dx, dy: astro[2].dy, t: 0.0, dt: 0.016666): a2t
        |> sim:wrap-x(a2t.x, width: 800.0): a2x
        |> sim:wrap-y(a2t.y, height: 600.0): a2y
        |> std/grid:stored { ship[0].rotation: ship[0].rotation + drot, ship[0].vx: dvx, ship[0].vy: dvy, ship[0].x: nx, ship[0].y: ny }
        |> std/grid:stored { astro[0].x: a0x, astro[0].y: a0y }
        |> std/grid:stored { astro[1].x: a1x, astro[1].y: a1y }
        |> std/grid:stored { astro[2].x: a2x, astro[2].y: a2y }
        |> libs/raylib:color(r: 8, g: 10, b: 16): bg
        |> libs/raylib:color(r: 235, g: 235, b: 250): white
        |> libs/raylib:draw.clear(f, col: bg)
        |> libs/raylib:draw.circle.lines(f, x: @as(i32, @intFromFloat(ship[0].x)), y: @as(i32, @intFromFloat(ship[0].y)), r: 12.0, col: white)
        |> libs/raylib:draw.circle.lines(f, x: @as(i32, @intFromFloat(a0x)), y: @as(i32, @intFromFloat(a0y)), astro[0].r, col: white)
        |> libs/raylib:draw.circle.lines(f, x: @as(i32, @intFromFloat(a1x)), y: @as(i32, @intFromFloat(a1y)), astro[1].r, col: white)
        |> libs/raylib:draw.circle.lines(f, x: @as(i32, @intFromFloat(a2x)), y: @as(i32, @intFromFloat(a2y)), astro[2].r, col: white)
    | done w2 |> libs/raylib:window.close(win: w2) |> std/io:print.ln("900 frames: ship {{ ship[0].x:f }},{{ ship[0].y:f }} | a0 {{ astro[0].x:f }},{{ astro[0].y:f }} | a1 {{ astro[1].x:f }},{{ astro[1].y:f }} | a2 {{ astro[2].x:f }},{{ astro[2].y:f }}")
| err e |> std/io:print.ln("asteroids init failed: {{ e:s }}")