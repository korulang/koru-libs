// main.k — koru ponkatris shell: window + frame loop over sim/.
//
// Kernel scope is closed (only kernel ops inside `| kernel k`), so the tick
// is a named tor the frame chain calls — one `step(0..1)` per rendered
// frame at fixed DT=1/120. Painting is a set of guarded `! query` arms over
// sim's `bodies` store — cross-module store access is plain: the query names
// the store, codegen resolves it to koru_sim's scope.

import std/io
import std/store
import std/fmt
import libs/raylib
import sim

// Paint every body, keyed on kind: one query flow per class, each with a
// guarded `! query` arm (the one-arm-per-flow shape the store grammar gives).
tor paint-ball { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }
tor paint-bumper { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }
tor paint-wall { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }
tor paint-crystal { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }
tor paint-killzone { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }

paint-ball = std/store:query(bodies)
    ! query e when e.kind == 0.0
        |> libs/raylib:draw.circle(f, x: @as(f32, @floatCast(e.x)), y: @as(f32, @floatCast(e.y)), r: @as(f32, @floatCast(e.radius)), col)

paint-bumper = std/store:query(bodies)
    ! query e when e.kind == 1.0
        |> libs/raylib:draw.circle(f, x: @as(f32, @floatCast(e.x)), y: @as(f32, @floatCast(e.y)), r: @as(f32, @floatCast(e.radius)), col)

paint-wall = std/store:query(bodies)
    ! query e when e.kind == 2.0
        |> libs/raylib:draw.rect(f, x: @as(i32, @intFromFloat(e.x - e.hw)), y: @as(i32, @intFromFloat(e.y - e.hh)), w: @as(i32, @intFromFloat(e.hw * 2.0)), h: @as(i32, @intFromFloat(e.hh * 2.0)), col)

paint-crystal = std/store:query(bodies)
    ! query e when e.kind == 3.0
        |> libs/raylib:draw.rect(f, x: @as(i32, @intFromFloat(e.x - e.hw)), y: @as(i32, @intFromFloat(e.y - e.hh)), w: @as(i32, @intFromFloat(e.hw * 2.0)), h: @as(i32, @intFromFloat(e.hh * 2.0)), col)

paint-killzone = std/store:query(bodies)
    ! query e when e.kind == 4.0
        |> libs/raylib:draw.rect(f, x: @as(i32, @intFromFloat(e.x - e.hw)), y: @as(i32, @intFromFloat(e.y - e.hh)), w: @as(i32, @intFromFloat(e.hw * 2.0)), h: @as(i32, @intFromFloat(e.hh * 2.0)), col)

// HUD: the game row formatted through std/fmt, drawn via the bounded text
// proc. One arm per flow, so end banners are their own tors.
tor paint-hud { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }

paint-hud = std/store:query(game)
    ! query g |> std/fmt:ln("t {{ g.tleft:f }}   {{ g.score:d }}/{{ g.total:d }}"): l
        |> libs/raylib:draw.text(f, l.text, x: 16, y: 12, size: 24, col)

tor paint-end-won { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }

paint-end-won = std/store:query(game)
    ! query g when g.won == 1.0
        |> libs/raylib:draw.text(f, text: "CLEAR — R to restart", x: 250, y: 280, size: 30, col)

tor paint-end-over { f: *libs/raylib:Frame<frame>, col: libs/raylib:Color }

paint-end-over = std/store:query(game)
    ! query g when g.over == 1.0 and g.won == 0.0
        |> libs/raylib:draw.text(f, text: "TIME UP — R to restart", x: 240, y: 280, size: 30, col)

libs/raylib:window.open(width: 800, height: 600, title: "koru ponkatris")
| win w |> libs/raylib:window.fps(win: w, fps: 120) |> libs/raylib:frames(win: w, count: 7200)
    ! frame f
        |> libs/raylib:input.key.down(key: 263): left_held
        |> libs/raylib:input.key.down(key: 262): right_held
        |> libs/raylib:input.key.down(key: 265): up_held
        |> libs/raylib:input.key.down(key: 65): a_held
        |> libs/raylib:input.key.down(key: 68): d_held
        |> libs/raylib:input.key.down(key: 87): w_held
        |> libs/raylib:input.key.pressed(key: 82): r_pressed
        |> sim:thrust(left: left_held or a_held, right: right_held or d_held, up: up_held or w_held)
        |> sim:tick()
        |> sim:collect()
        |> sim:respawn()
        |> sim:countdown()
        |> sim:reset(pressed: r_pressed)
        |> sim:reset-spawn(pressed: r_pressed)
        |> sim:reset-ball(pressed: r_pressed)
        |> sim:reset-game(pressed: r_pressed)
        |> libs/raylib:color(r: 8, g: 10, b: 16): bg
        |> libs/raylib:color(r: 120, g: 200, b: 255): ball_col
        |> libs/raylib:color(r: 255, g: 140, b: 60): bump_col
        |> libs/raylib:color(r: 90, g: 90, b: 110): wall_col
        |> libs/raylib:color(r: 120, g: 255, b: 160): crys_col
        |> libs/raylib:color(r: 255, g: 60, b: 80): kill_col
        |> libs/raylib:color(r: 235, g: 235, b: 245): hud_col
        |> libs/raylib:draw.clear(f, col: bg)
        |> paint-ball(f, col: ball_col)
        |> paint-bumper(f, col: bump_col)
        |> paint-wall(f, col: wall_col)
        |> paint-crystal(f, col: crys_col)
        |> paint-killzone(f, col: kill_col)
        |> paint-hud(f, col: hud_col)
        |> paint-end-won(f, col: crys_col)
        |> paint-end-over(f, col: kill_col)
    | done w2 |> libs/raylib:window.close(win: w2)
        |> sim:dump()
        |> sim:dump-game()
| err e |> std/io:print.ln("ponkatris init failed: {{ e:s }}")
