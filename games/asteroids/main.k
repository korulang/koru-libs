// main.k — Koru Asteroids: the real game.
//
// The sim owns the world — one kind-tagged `bodies` store (1 ship · 2 rock ·
// 3 bullet), a `game` row for score/lives/over + the wave machinery, and
// every rule: kernel:self integrates, kernel:pairwise flags contacts, query
// arms harvest. This file is the shell: it opens the window, maps keys onto
// sim tors, and paints.
//
// The ship is the classic wedge (sim:ship-verts -> draw.triangle.lines);
// every rock is a deterministic jagged polygon (sim:rock-vert -> draw.line,
// seed-folded so the same rock draws the same silhouette every frame).

import std/io
import std/store
import libs/raylib
import sim

tor paint-ship { f: *libs/raylib:Frame<frame> }
paint-ship = std/store:query(bodies)
    ! query e when e.kind == 1.0 and e.dead == 0.0
        |> sim:ship-visible(e.inv): vis
        |> if (vis)
            | then |> sim:ship-verts(e.x, e.y, rotation: e.rot): v
                |> libs/raylib:color(r: 235, g: 235, b: 250): white
                |> libs/raylib:draw.triangle.lines(f, v.x1, v.y1, v.x2, v.y2, v.x3, v.y3, col: white)
            | else |> _

tor paint-rocks { f: *libs/raylib:Frame<frame> }
paint-rocks = std/store:query(bodies)
    ! query e when e.kind == 2.0
        |> for(0..9)
            ! each i |> sim:rock-vert(cx: e.x, cy: e.y, e.r, e.seed, i: @as(i32, @intCast(i))): v1
                |> sim:rock-vert(cx: e.x, cy: e.y, e.r, e.seed, i: @as(i32, @intCast(i + 1))): v2
                |> libs/raylib:color(r: 170, g: 170, b: 195): rock_col
                |> libs/raylib:draw.line(f, x1: v1.x, y1: v1.y, x2: v2.x, y2: v2.y, thickness: 1.5, col: rock_col)

tor paint-shots { f: *libs/raylib:Frame<frame> }
paint-shots = std/store:query(bodies)
    ! query e when e.kind == 3.0
        |> libs/raylib:color(r: 235, g: 235, b: 250): shot
        |> libs/raylib:draw.circle(f, e.x, e.y, r: 2.0, col: shot)

tor paint-hud { f: *libs/raylib:Frame<frame> }
paint-hud = std/store:query(game)
    ! query g |> libs/raylib:color(r: 140, g: 140, b: 160): dim
        |> libs/raylib:draw.text(f, text: "score", x: 12, y: 10, size: 18, col: dim)
        |> libs/raylib:draw.int(f, n: @as(i32, @intFromFloat(g.score)), x: 76, y: 10, size: 18, col: dim)
        |> libs/raylib:draw.text(f, text: "lives", x: 160, y: 10, size: 18, col: dim)
        |> libs/raylib:draw.int(f, n: @as(i32, @intFromFloat(g.lives)), x: 220, y: 10, size: 18, col: dim)
        |> libs/raylib:draw.text(f, text: "wave", x: 290, y: 10, size: 18, col: dim)
        |> libs/raylib:draw.int(f, n: @as(i32, @intFromFloat(g.wave)), x: 350, y: 10, size: 18, col: dim)

tor paint-over { f: *libs/raylib:Frame<frame> }
paint-over = std/store:query(game)
    ! query g when g.over == 1.0
        |> libs/raylib:color(r: 235, g: 235, b: 250): white
        |> libs/raylib:draw.text(f, text: "game over — enter to restart", x: 230, y: 290, size: 24, col: white)

std/store:insert(bodies) { x: 400.0, y: 300.0, dx: 0.0, dy: 0.0, kind: 1.0, r: 12.0, t: 0.0, seed: 0, hit: 0.0, dead: 0.0, rot: 0.0, inv: 2.0, cd: 0.0 }
std/store:insert(game) { score: 0.0, lives: 3.0, over: 0.0, wave: 0.0, rocks: 0.0, pending: 0.0, rt: 0.0, seed: 7.0 }

libs/raylib:window.open(width: 800, height: 600, title: "koru asteroids")
| win w |> libs/raylib:window.fps(win: w, fps: 60) |> libs/raylib:frames(win: w, count: 7200)
    ! frame f
        |> libs/raylib:input.key.down(key: 263): kl
        |> libs/raylib:input.key.down(key: 65): ka
        |> sim:either(a: kl, b: ka): left_held
        |> libs/raylib:input.key.down(key: 262): kr
        |> libs/raylib:input.key.down(key: 68): kd
        |> sim:either(a: kr, b: kd): right_held
        |> libs/raylib:input.key.down(key: 265): ku
        |> libs/raylib:input.key.down(key: 87): kw
        |> sim:either(a: ku, b: kw): thrusting
        |> libs/raylib:input.key.down(key: 32): firing
        |> libs/raylib:input.key.pressed(key: 257): restarting
        |> sim:control(left: left_held, right: right_held, thrusting)
        |> sim:fire(pressed: firing)
        |> sim:tick()
        |> sim:harvest()
        |> sim:harvest-rocks()
        |> sim:respawn-ship()
        |> sim:respawn-tick()
        |> sim:maybe-revive()
        |> sim:wave-check()
        |> sim:spawn-tick()
        |> sim:reset(pressed: restarting)
        |> libs/raylib:color(r: 8, g: 10, b: 16): bg
        |> libs/raylib:draw.clear(f, col: bg)
        |> paint-ship(f)
        |> paint-rocks(f)
        |> paint-shots(f)
        |> paint-hud(f)
        |> paint-over(f)
    | done w2 |> libs/raylib:window.close(win: w2)
| err e |> std/io:print.ln("asteroids init failed: {{ e:s }}")
