// tilt.k as an automation scenario — the S2 legibility A/B, no hands.
// Drift runs from frame 0. The script staggers `touched` with injected
// right-arrows so resources sit at different depths, snaps the FLAT
// projection at f260, injects T, touches one more item at f300 (a fresh
// item must stay low+large under tilt), snaps TILTED at f340, quits.
//
// The question the pair answers: in the tilted capture, does depth read
// as SPATIAL ORDER (fresh low and large, stale high and small near the
// horizon), or is it still just smaller boxes?
import libs/metal
import std/store
import std/io

std/store:new(world) { frame: 0[i64], focus: 0[i64], n: 8[i64], tiltT: 0[i64], drift: 1[i64] }
std/store:new(cam) { tilt: 0.0[f64] }

std/store:new(res, capacity: 8) {
    id: i64,
    cx: f64, cy: f64,
    touched: i64,
    br: f64, bg: f64, bb: f64,
    t: f64, s: f64,
    rx: f64, ry: f64, rw: f64, rh: f64,
    rr: f64, rg: f64, rb: f64
}

std/store:insert(res) { id: 0, cx: 110.0, cy: 130.0, touched: 0, br: 0.90, bg: 0.40, bb: 0.40, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
| row _ |> std/store:insert(res) { id: 1, cx: 270.0, cy: 130.0, touched: 0, br: 0.90, bg: 0.75, bb: 0.30, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
    | row _ |> std/store:insert(res) { id: 2, cx: 430.0, cy: 130.0, touched: 0, br: 0.40, bg: 0.80, bb: 0.45, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
        | row _ |> std/store:insert(res) { id: 3, cx: 590.0, cy: 130.0, touched: 0, br: 0.30, bg: 0.75, bb: 0.80, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
            | row _ |> std/store:insert(res) { id: 4, cx: 110.0, cy: 320.0, touched: 0, br: 0.35, bg: 0.50, bb: 0.90, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
                | row _ |> std/store:insert(res) { id: 5, cx: 270.0, cy: 320.0, touched: 0, br: 0.60, bg: 0.45, bb: 0.90, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
                    | row _ |> std/store:insert(res) { id: 6, cx: 430.0, cy: 320.0, touched: 0, br: 0.90, bg: 0.45, bb: 0.75, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
                        | row _ |> std/store:insert(res) { id: 7, cx: 590.0, cy: 320.0, touched: 0, br: 0.85, bg: 0.80, bb: 0.60, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
                            | row _ |> _

libs/metal:window.open(width: 720, height: 460, title: "omni tilt — automation A/B")
| win w |> libs/metal:window.clear.color(win: w, r: 0.10, g: 0.10, b: 0.15)
        |> libs/metal:frames(win: w, count: 9999)
    ! frame f
        |> std/store:stored { world.frame: world.frame + 1 }
        |> std/store:stored { cam.tilt: cam.tilt + (@as(f64, @floatFromInt(world.tiltT)) - cam.tilt) * 0.10 }
        |> libs/metal:draw.rect(f, x: 0.0, y: 228.0, w: 720.0, h: 2.0, r: 0.45, g: 0.45, b: 0.55, a: cam.tilt * 0.5)
        |> std/store:query(res)
            ! query r
                |> std/store:stored { r.t: if (world.drift == 0) 0.0 else if (world.frame - r.touched > 240) 1.0 else @as(f64, @floatFromInt(world.frame - r.touched)) / 240.0 }
                |> std/store:stored { r.s: 1.0 - 0.78 * r.t }
                |> std/store:stored { r.rx: r.cx * (1.0 - r.t) + 360.0 * r.t - 70.0 * r.s, r.ry: r.cy * (1.0 - r.t) + 230.0 * r.t - 45.0 * r.s + (230.0 - r.cy) * 0.55 * cam.tilt - r.t * 150.0 * cam.tilt, r.rw: 140.0 * r.s, r.rh: 90.0 * r.s * (1.0 - 0.35 * cam.tilt), r.rr: r.br * (1.0 - r.t) + 0.10 * r.t, r.rg: r.bg * (1.0 - r.t) + 0.10 * r.t, r.rb: r.bb * (1.0 - r.t) + 0.15 * r.t }
                |> libs/metal:draw.rect(f, x: r.rx, y: r.ry, w: r.rw, h: r.rh, r: r.rr, g: r.rg, b: r.rb, a: 1.0)
                |> libs/metal:draw.rect(f, x: r.rx + r.rw / 2.0 - 4.0, y: r.ry - 14.0, w: 8.0, h: 8.0, r: if (r.id == world.focus) 1.0 else 0.10, g: if (r.id == world.focus) 1.0 else 0.10, b: if (r.id == world.focus) 1.0 else 0.15, a: 1.0)
        |> if (world.frame == 60)
            | then |> libs/metal:input.key(code: 124)
        |> if (world.frame == 140)
            | then |> libs/metal:input.key(code: 124)
        |> if (world.frame == 260)
            | then |> libs/metal:window.snap(path: "/tmp/omni_tilt_flat.bmp")
        |> if (world.frame == 265)
            | then |> libs/metal:input.key(code: 17)
        |> if (world.frame == 300)
            | then |> libs/metal:input.key(code: 124)
        |> if (world.frame == 340)
            | then |> libs/metal:window.snap(path: "/tmp/omni_tilt_tilted.bmp")
        |> if (world.frame == 345)
            | then |> libs/metal:quit()
    ! key-down k when k.code == 124
        |> std/store:stored { world.focus: if (world.focus + 1 >= world.n) 0 else world.focus + 1 }
        |> std/store:query(res)
            ! query r when r.id == world.focus
                |> std/store:stored { r.touched: world.frame }
    ! key-down k when k.code == 17
        |> std/store:stored { world.tiltT: if (world.tiltT == 0) 1 else 0 }
    ! key-down k when k.code == 2
        |> std/store:stored { world.drift: if (world.drift == 0) 1 else 0 }
    ! key-down k when k.code == 53 |> libs/metal:quit()
    ! close |> libs/metal:quit()
    | done w2 |> libs/metal:window.close(win: w2) |> std/io:print.ln("tilt_snap: closed")
| err e |> std/io:print.ln("metal init failed: {{ e:s }}")
