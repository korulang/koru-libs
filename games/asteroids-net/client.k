// client.k — the raylib half: keyboard in, snapshots in, pixels out. It owns
// NO simulation — `view` is a replicated store, cleared and refilled from
// the wire each frame. The pure paint helpers come from `sim` verbatim:
// rocks carry their LCG seed over the wire, so the client's polygons are the
// server's polygons, vertex for vertex.

import std/io
import std/store
import std/grid
import libs/raylib
import libs/udp
import sim
import wire

const {
    KEY_LEFT: 263
    KEY_RIGHT: 262
    KEY_UP: 265
    KEY_A: 65
    KEY_D: 68
    KEY_W: 87
    KEY_SPACE: 32
}

// The replicated field — one row per entity in the latest snapshot.
std/store:new(view, capacity: 128) {
    x: f32, y: f32, rot: f32, r: f32, inv: f32,
    seed: i32, kind: f32, dead: f32, owner: f32
}

std/grid:new(hud, size: 1) { score: 0.0[f32], wave: 0.0[f32] }

// One datagram → the whole view. clear+refill is the honest v0 — delta
// snapshots are the next slice (SERVER_CHALLENGE.md).
tor refill { d: string, n: i32 }

refill = std/store:clear(view)
    |> for(0..@as(usize, @intCast(n)))
        ! each i |> wire:snap.ent(d, i: @as(i32, @intCast(i))): e
            |> std/store:insert(view) { e.x, e.y, e.rot, e.r, e.inv, e.seed, e.kind, e.dead, e.owner }

tor apply { d: string }

apply = wire:snap.count(d): n
    |> wire:snap.score(d): sc
    |> wire:snap.wave(d): wv
    |> std/grid:stored { hud[0].score: sc, hud[0].wave: wv }
    |> if (n > 0)
        | then |> refill(d, n)
        | else |> _

tor paint-ship { f: *libs/raylib:Frame<frame> }
paint-ship = std/store:query(view)
    ! query e when e.kind == 1.0 and e.dead == 0.0
        |> sim:ship-visible(e.inv): vis
        |> if (vis)
            | then |> sim:ship-verts(e.x, e.y, rotation: e.rot): v
                |> libs/raylib:color(r: 235, g: 235, b: 250): white
                |> libs/raylib:draw.triangle.lines(f, v.x1, v.y1, v.x2, v.y2, v.x3, v.y3, col: white)
            | else |> _

tor paint-rocks { f: *libs/raylib:Frame<frame> }
paint-rocks = std/store:query(view)
    ! query e when e.kind == 2.0
        |> for(0..9)
            ! each i |> sim:rock-vert(cx: e.x, cy: e.y, e.r, e.seed, i: @as(i32, @intCast(i))): v1
                |> sim:rock-vert(cx: e.x, cy: e.y, e.r, e.seed, i: @as(i32, @intCast(i + 1))): v2
                |> libs/raylib:color(r: 170, g: 170, b: 195): rock_col
                |> libs/raylib:draw.line(f, x1: v1.x, y1: v1.y, x2: v2.x, y2: v2.y, thickness: 1.5, col: rock_col)

tor paint-shots { f: *libs/raylib:Frame<frame> }
paint-shots = std/store:query(view)
    ! query e when e.kind == 3.0
        |> libs/raylib:color(r: 235, g: 235, b: 250): shot
        |> libs/raylib:draw.circle(f, e.x, e.y, r: 2.0, col: shot)

// send.ip's branches would swallow the rest of the frame arm — box them in
// a tor so the caller's chain stays linear. (Branch arms ARE the
// continuation; a step with branches ends its enclosing flow.)
tor push-input { s: *libs/udp:Socket<bound>, pkt: string }

push-input = libs/udp:send.ip(sock: s, ip: "127.0.0.1", port: 7777, data: pkt)
    | sent |> _
    | err e |> std/io:print.ln("send err {{ e:s }}")

tor paint-hud { f: *libs/raylib:Frame<frame> }
paint-hud = libs/raylib:color(r: 140, g: 140, b: 160): dim
    |> libs/raylib:draw.text(f, text: "score", x: 12, y: 10, size: 18, col: dim)
    |> libs/raylib:draw.int(f, n: @as(i32, @intFromFloat(hud[0].score)), x: 76, y: 10, size: 18, col: dim)
    |> libs/raylib:draw.text(f, text: "wave", x: 160, y: 10, size: 18, col: dim)
    |> libs/raylib:draw.int(f, n: @as(i32, @intFromFloat(hud[0].wave)), x: 220, y: 10, size: 18, col: dim)

libs/udp:bind(port: 0)
| bound s |> libs/raylib:window.open(width: 800, height: 600, title: "koru asteroids-net")
    | win w |> libs/raylib:window.fps(win: w, fps: 60) |> libs/raylib:frames(win: w)
        ! frame f
            |> libs/raylib:input.key.down(key: 263): kl |> libs/raylib:input.key.down(key: 65): ka
            |> libs/raylib:input.key.down(key: 262): kr |> libs/raylib:input.key.down(key: 68): kd
            |> libs/raylib:input.key.down(key: 265): ku |> libs/raylib:input.key.down(key: 87): kw
            |> libs/raylib:input.key.down(key: 32): firing
            |> sim:either(a: kl, b: ka): left_held
            |> sim:either(a: kr, b: kd): right_held
            |> sim:either(a: ku, b: kw): thrusting
            |> wire:input.encode(left: left_held, right: right_held, thrust: thrusting, fire: firing): pkt
            |> push-input(s, pkt)
            |> libs/udp:packets(sock: s, max: 8)
                ! packet p |> libs/udp:packet.data(p): d |> apply(d)
                | done |> libs/raylib:color(r: 8, g: 10, b: 16): bg |> libs/raylib:draw.clear(f, col: bg)
                    |> paint-ship(f) |> paint-rocks(f) |> paint-shots(f) |> paint-hud(f)
                | err e |> std/io:print.ln("drain err {{ e:s }}")
        | done w2 |> libs/udp:close(sock: s)
            |> libs/raylib:window.close(win: w2)
    | err e |> std/io:print.ln("window err {{ e:s }}")
| err e |> std/io:print.ln("bind err {{ e:s }}")
