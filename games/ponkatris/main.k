// main.k — koru ponkatris shell: window + frame loop over sim/.
//
// Kernel scope is closed (only kernel ops inside `| kernel k`), so the tick
// is a named tor the frame chain calls — one `step(0..1)` per rendered
// frame at fixed DT=1/120. Painting is a set of guarded `! query` arms over
// sim's `bodies` store — cross-module store access is plain: the query names
// the store, codegen resolves it to koru_sim's scope.
//
// The level seeds the world via an explicit spawn() call. Movement deltas
// are the oracle's defaults (no `Movement:` line in rubicon):
// 1000 / 1000 / 3000 / 0 px/s² — the 3x up-thrust is Boost — × DT.

import std/io
import std/store
import std/fmt
import libs/raylib
import sim
import level/rubicon

// Paint every body, keyed on kind: one query flow per class, each with a
// guarded `! query` arm (the one-arm-per-flow shape the store grammar gives).
tor paint-ball { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }
tor paint-bumper { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }
tor paint-wall { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }
tor paint-crystal { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }
tor paint-killzone { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }
tor paint-diamond { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }

paint-ball = std/store:query(bodies)
    ! query e when e.kind == 0
        |> libs/raylib:draw.circle(f, x: @as(f32, @floatCast(e.x)), y: @as(f32, @floatCast(e.y)), r: @as(f32, @floatCast(e.radius)), col)

paint-bumper = std/store:query(bodies)
    ! query e when e.kind == 1
        |> libs/raylib:draw.circle(f, x: @as(f32, @floatCast(e.x)), y: @as(f32, @floatCast(e.y)), r: @as(f32, @floatCast(e.radius)), col)

paint-wall = std/store:query(bodies)
    ! query e when e.kind == 2
        |> libs/raylib:draw.rect(f, x: @as(i32, @intFromFloat(e.x - e.hw)), y: @as(i32, @intFromFloat(e.y - e.hh)), w: @as(i32, @intFromFloat(e.hw * 2.0)), h: @as(i32, @intFromFloat(e.hh * 2.0)), col)

// crystals are sensor circles now (the oracle's SensorCrystal x y r)
paint-crystal = std/store:query(bodies)
    ! query e when e.kind == 3
        |> libs/raylib:draw.circle(f, x: @as(f32, @floatCast(e.x)), y: @as(f32, @floatCast(e.y)), r: @as(f32, @floatCast(e.radius)), col)

paint-killzone = std/store:query(bodies)
    ! query e when e.kind == 4
        |> libs/raylib:draw.rect(f, x: @as(i32, @intFromFloat(e.x - e.hw)), y: @as(i32, @intFromFloat(e.y - e.hh)), w: @as(i32, @intFromFloat(e.hw * 2.0)), h: @as(i32, @intFromFloat(e.hh * 2.0)), col)

// solid diamonds: a square spun 45 degrees, center pivot
paint-diamond = std/store:query(bodies)
    ! query e when e.kind == 5
        |> libs/raylib:draw.rect.rot(f, x: @as(f32, @floatCast(e.x)), y: @as(f32, @floatCast(e.y)), w: @as(f32, 17.0), h: @as(f32, 17.0), deg: @as(f32, 45.0), col)

// HUD: the game row formatted through std/fmt, drawn via the bounded text
// proc. One arm per flow, so end banners are their own tors.
tor paint-hud { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }

paint-hud = std/store:query(game)
    ! query g |> std/fmt:ln("{{ g.elapsed:d:.4 }}s   {{ g.score:d }}/{{ g.total:d }}"): l
        |> libs/raylib:draw.text(f, l.text, x: 16, y: 12, size: 24, col)

tor paint-end-won { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }

paint-end-won = std/store:query(game)
    ! query g when g.won == 1
        |> std/fmt:ln("CLEAR in {{ g.elapsed:d:.4 }}s — R to restart"): l
        |> libs/raylib:draw.text(f, l.text, x: 190, y: 320, size: 30, col)

level/rubicon:spawn()

libs/raylib:window.open(width: 620, height: 680, title: "koru ponkatris — rubicon")
| win w |> libs/raylib:window.fps(win: w, fps: 120) |> libs/raylib:frames(win: w)
    ! frame f
        |> libs/raylib:input.key.down(key: 263): left_held
        |> libs/raylib:input.key.down(key: 262): right_held
        |> libs/raylib:input.key.down(key: 265): up_held
        |> libs/raylib:input.key.down(key: 65): a_held
        |> libs/raylib:input.key.down(key: 68): d_held
        |> libs/raylib:input.key.down(key: 87): w_held
        |> libs/raylib:input.key.pressed(key: 82): r_pressed
        |> sim:thrust(
            left: (if (left_held or a_held) @as(f64, 8.3333) else @as(f64, 0.0)),
            right: (if (right_held or d_held) @as(f64, 8.3333) else @as(f64, 0.0)),
            up: (if (up_held or w_held) @as(f64, 25.0) else @as(f64, 0.0)),
            down: @as(f64, 0.0))
        |> sim:tick()
        |> sim:collect()
        |> sim:respawn()
        |> sim:stopwatch()
        |> sim:reset(pressed: r_pressed)
        |> level/rubicon:spawn-crystals(pressed: r_pressed)
        |> sim:reset-ball(pressed: r_pressed)
        |> sim:reset-game(pressed: r_pressed)
        |> libs/raylib:color(r: 8, g: 10, b: 16): bg
        |> libs/raylib:color(r: 120, g: 200, b: 255): ball_col
        |> libs/raylib:color(r: 255, g: 80, b: 170): bump_col
        |> libs/raylib:color(r: 90, g: 90, b: 110): wall_col
        |> libs/raylib:color(r: 120, g: 255, b: 160): crys_col
        |> libs/raylib:color(r: 255, g: 60, b: 80): kill_col
        |> libs/raylib:color(r: 235, g: 235, b: 245): hud_col
        |> libs/raylib:draw.clear(f, col: bg)
        |> paint-ball(f, col: ball_col)
        |> paint-bumper(f, col: bump_col)
        |> paint-wall(f, col: wall_col)
        |> paint-crystal(f, col: crys_col)
        |> paint-diamond(f, col: crys_col)
        |> paint-killzone(f, col: kill_col)
        |> paint-hud(f, col: hud_col)
        |> paint-end-won(f, col: crys_col)
    | done w2 |> libs/raylib:window.close(win: w2)
        |> sim:dump()
        |> sim:dump-game()
| err e |> std/io:print.ln("ponkatris init failed: {{ e:s }}")
