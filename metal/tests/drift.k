// OMNI spike S1 — drift-feel. Eight "resources" rest on a 4x2 plane; every
// frame each one's rendered depth is derived from age = frame - touched:
// it lerps toward the vanishing center, shrinks, and fades to the clear
// color. The right arrow (keyCode 124) cycles focus and stamps the newly
// focused resource's touched — attention is a write. Escape/closing quits.
//
// The store IS the scene: query pass writes derived columns (t, s, rx..rb)
// then draws them — layout then paint, the materialized-view reading.
//
//   koruc run metal/tests/drift.k     (→ cycle, esc quit)

import libs/metal
import std/store
import std/io

std/store:new(world) { frame: 0[i64], focus: 0[i64], n: 8[i64] }

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

libs/metal:window.open(width: 720, height: 460, title: "omni drift — → to touch, esc to quit")
| win w |> libs/metal:window.clear.color(win: w, r: 0.10, g: 0.10, b: 0.15)
        |> libs/metal:frames(win: w, count: 99999)
    ! frame f
        |> std/store:stored { world.frame: world.frame + 1 }
        |> std/store:query(res)
            ! query r
                |> std/store:stored { r.t: if (world.frame - r.touched > 240) 1.0 else @as(f64, @floatFromInt(world.frame - r.touched)) / 240.0 }
                |> std/store:stored { r.s: 1.0 - 0.78 * r.t }
                |> std/store:stored { r.rx: r.cx * (1.0 - r.t) + 360.0 * r.t - 70.0 * r.s, r.ry: r.cy * (1.0 - r.t) + 230.0 * r.t - 45.0 * r.s, r.rw: 140.0 * r.s, r.rh: 90.0 * r.s, r.rr: r.br * (1.0 - r.t) + 0.10 * r.t, r.rg: r.bg * (1.0 - r.t) + 0.10 * r.t, r.rb: r.bb * (1.0 - r.t) + 0.15 * r.t }
                |> libs/metal:draw.rect(f, x: r.rx, y: r.ry, w: r.rw, h: r.rh, r: r.rr, g: r.rg, b: r.rb, a: 1.0)
                |> libs/metal:draw.rect(f, x: r.rx + r.rw / 2.0 - 4.0, y: r.ry - 14.0, w: 8.0, h: 8.0, r: if (r.id == world.focus) 1.0 else 0.10, g: if (r.id == world.focus) 1.0 else 0.10, b: if (r.id == world.focus) 1.0 else 0.15, a: 1.0)
    ! key-down k when k.code == 124
        |> std/store:stored { world.focus: if (world.focus + 1 >= world.n) 0 else world.focus + 1 }
        |> std/store:query(res)
            ! query r when r.id == world.focus
                |> std/store:stored { r.touched: world.frame }
    ! key-down k when k.code == 53 |> libs/metal:quit()
    ! close |> libs/metal:quit()
    | done w2 |> libs/metal:window.close(win: w2) |> std/io:print.ln("drift: closed")
| err e |> std/io:print.ln("metal init failed: {{ e:s }}")
