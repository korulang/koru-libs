// main.k — the first playable slice of Koru Asteroids.
//
// One ship in a 800x600 field: rotate (A/D + arrows), thrust (W/up), drag,
// wrap. State is a one-row grid; every rule lives in sim.k and is bound here
// before the single `stored` write (tor calls are not expressions, KORU104).
// The frame step is a FIXED 1/60 — deterministic, and the honest way to run
// physics against a 60fps raylib loop.

import std/io
import std/grid
import libs/raylib
import sim

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
        |> std/grid:stored { ship[0].rotation: ship[0].rotation + drot, ship[0].vx: dvx, ship[0].vy: dvy, ship[0].x: nx, ship[0].y: ny }
        |> sim:facing(rotation: ship[0].rotation): face
        |> sim:facing(rotation: ship[0].rotation + 2.5): face_left
        |> sim:facing(rotation: ship[0].rotation - 2.5): face_right
        |> libs/raylib:color(r: 8, g: 10, b: 16): bg |> libs/raylib:draw.clear(f, col: bg)
        |> libs/raylib:color(r: 235, g: 235, b: 250): white
        |> libs/raylib:draw.triangle.lines(f, x1: ship[0].x + face.x * 20.0, y1: ship[0].y + face.y * 20.0, x2: ship[0].x + face_left.x * 20.0, y2: ship[0].y + face_left.y * 20.0, x3: ship[0].x + face_right.x * 20.0, y3: ship[0].y + face_right.y * 20.0, col: white)
    | done w2 |> libs/raylib:window.close(win: w2) |> std/io:print.ln("asteroids: ship flew 900 fixed-step frames")
| err e |> std/io:print.ln("asteroids init failed: {{ e:s }}")