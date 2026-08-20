// smoke.k — determinism is the point. Two halves:
//
//   1. DIRECT SIM CHECKS — bind each rule and print its value (these are the
//      receipts the koru regression suite pins from the other side of the
//      toolchain). A change to any rule shows up here as a changed number
//      before it ever reaches pixels. NOTE: value bindings can't be consumed
//      by template interpolation alone (KORU100) — so each result is moved
//      into the `check` grid (a real argument use), and the prints read the
//      grid cells.
//   2. RENDERED LOOP — a hidden window, 120 fixed-step frames with NO input:
//      the ship must not move, not rotate, not accelerate. Proves the
//      update path and the draw path both run and the ship stays centered.

import std/io
import std/grid
import libs/raylib
import sim

std/grid:new(check, size: 1) {
    dx: 0.0[f32], d_both: 0.0[f32], d_right: 0.0[f32],
    wneg: 0.0[f32], wov: 0.0[f32], fx: 0.0[f32], fy: 0.0[f32],
    r0: 0[u32], r0v: 0[u32], r331: 0[u32], hit1: false[bool], hit2: false[bool],
    bx: 0.0[f32], by: 0.0[f32], cr2: 0.0[f32], cnt: 0[i32]
}

sim:rotation-delta(left: true, right: false, dt: 0.016666): d_left
|> std/grid:stored { check[0].dx: d_left }
sim:rotation-delta(left: true, right: true, dt: 0.016666): d_both
|> std/grid:stored { check[0].d_both: d_both }
sim:rotation-delta(left: false, right: true, dt: 0.016666): d_right
|> std/grid:stored { check[0].d_right: d_right }
sim:wrap-x(x: -10.0, width: 800.0): wrap_neg
|> std/grid:stored { check[0].wneg: wrap_neg }
sim:wrap-x(x: 805.0, width: 800.0): wrap_over
|> std/grid:stored { check[0].wov: wrap_over }
sim:facing(rotation: 0.0): face
|> std/grid:stored { check[0].fx: face.x, check[0].fy: face.y }
sim:rand(s: 0): r0
|> std/grid:stored { check[0].r0: r0.s2, check[0].r0v: r0.v }
sim:rand-under(s: 0, n: 360): r331
|> std/grid:stored { check[0].r331: r331.v }
sim:collide(ax: 0.0, ay: 0.0, ar: 10.0, bx: 18.0, by: 0.0, br: 10.0): c1
|> sim:collide(ax: 0.0, ay: 0.0, ar: 10.0, bx: 22.0, by: 0.0, br: 10.0): c2
|> std/grid:stored { check[0].hit1: c1, check[0].hit2: c2 }
sim:bullet-tick(x: 100.0, y: 200.0, dx: 300.0, dy: 100.0, t: 0.5, dt: 0.016666): bt
|> std/grid:stored { check[0].bx: bt.x, check[0].by: bt.y }
sim:child-r(r: 60.0): cr
|> sim:split-count(r: 60.0): n60
|> sim:split-count(r: 14.0): n14
|> std/grid:stored { check[0].cr2: cr, check[0].cnt: n60 + n14 }

std/io:print.ln("rotation-delta: left({{ check[0].dx:f }}, expect -0.0583) both({{ check[0].d_both:f }}, expect 0) right({{ check[0].d_right:f }}, expect +0.0583)")
std/io:print.ln("wrap-x: -10({{ check[0].wneg:f }}, expect 790) 805({{ check[0].wov:f }}, expect 5)")
std/io:print.ln("facing(0)=({{ check[0].fx:f }},{{ check[0].fy:f }}) expect (0,-1)")
std/io:print.ln("rand(0): s2={{ check[0].r0:any }} v={{ check[0].r0v:any }} | rand-under(0,360)={{ check[0].r331:any }}")
std/io:print.ln("collide d=18 {{ check[0].hit1:any }} (expect true) d=22 {{ check[0].hit2:any }} (expect false)")
std/io:print.ln("bullet-tick(100,200,300,100,0.5): ({{ check[0].bx:f }},{{ check[0].by:f }})")
std/io:print.ln("child-r(60)={{ check[0].cr2:f }} splits 60/14 => {{ check[0].cnt:any }} (expect 2)")

std/grid:new(ship, size: 1) {
    x: 400.0[f32], y: 300.0[f32],
    vx: 0.0[f32], vy: 0.0[f32], rotation: 0.0[f32]
}

libs/raylib:window.open.hidden(width: 800, height: 600, title: "koru asteroids smoke")
| win w |> libs/raylib:window.fps(win: w, fps: 60) |> libs/raylib:frames(win: w, count: 120)
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
        |> libs/raylib:color(r: 8, g: 10, b: 16): bg |> libs/raylib:draw.clear(f, col: bg)
        |> libs/raylib:color(r: 235, g: 235, b: 250): white
        |> libs/raylib:draw.circle.lines(f, x: @as(i32, @intFromFloat(ship[0].x)), y: @as(i32, @intFromFloat(ship[0].y)), r: 12.0, col: white)
    | done w2
        |> libs/raylib:window.close(win: w2)
        |> std/io:print.ln("no-input after 120 frames: x={{ ship[0].x:f }} y={{ ship[0].y:f }} vx={{ ship[0].vx:f }} vy={{ ship[0].vy:f }} rot={{ ship[0].rotation:f }}")
| err e |> std/io:print.ln("asteroids smoke init failed: {{ e:s }}")