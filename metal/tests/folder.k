// OMNI spike S4 — first ui/folder register block, now solved through the
// panel dialect. `vreg` is the registration: one table declaring the
// folder kind's verbs (vkey -> vact, plus the tile's color). The scene
// DERIVES chrome from it — a floating `stack` canvas-anchored under the
// focused folder, one `leaf` tile per registered verb — and dispatch
// goes through it too: the key arm looks up vkey, reads vact, fires.
// Layout words live in libs/ui, solving in libs/clay, drawing in Metal —
// the strip is authored data, not placement math.
//
//   → cycles focus, 1 = open (children land), 2 = pin (keep-warm the
//   group), T tilt, D drift, esc quits.
//
//   koruc run metal/tests/folder.k

import libs/metal
import libs/clay
import libs/ui
import std/store
import std/io

std/store:new(world) { frame: 0[i64], focus: 0[i64], n: 8[i64], tiltT: 0[i64], drift: 1[i64], folderH: 0[i64] }
std/store:new(cam) { tilt: 0.0[f64] }

// ui/folder register: keycode -> action (0 open, 1 pin), vi = tile ordinal,
// r/g/b = the tile's color — the register declares the chrome it derives.
std/store:new(vreg, capacity: 8) { vkey: i64, vact: i64, vi: i64, r: f64, g: f64, b: f64 }
std/store:insert(vreg) { vkey: 18, vact: 0, vi: 0, r: 166.0, g: 89.0, b: 255.0 }
| row _ |> std/store:insert(vreg) { vkey: 19, vact: 1, vi: 1, r: 242.0, g: 179.0, b: 51.0 }
    | row _ |> _

std/store:new(res, capacity: 12) {
    id: i64, kind: i64,
    parent: i64,
    cx: f64, cy: f64,
    touched: i64, alive: i64,
    br: f64, bg: f64, bb: f64,
    t: f64, s: f64,
    rx: f64, ry: f64, rw: f64, rh: f64,
    rr: f64, rg: f64, rb: f64
}

std/store:insert(res) { id: 0, kind: 0, parent: 0, cx: 110.0, cy: 130.0, touched: 0, alive: 1, br: 0.90, bg: 0.40, bb: 0.40, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
| row _ |> std/store:insert(res) { id: 1, kind: 0, parent: 0, cx: 270.0, cy: 130.0, touched: 0, alive: 1, br: 0.90, bg: 0.75, bb: 0.30, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
    | row _ |> std/store:insert(res) { id: 2, kind: 0, parent: 0, cx: 430.0, cy: 130.0, touched: 0, alive: 1, br: 0.40, bg: 0.80, bb: 0.45, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
        | row _ |> std/store:insert(res) { id: 3, kind: 0, parent: 0, cx: 590.0, cy: 130.0, touched: 0, alive: 1, br: 0.30, bg: 0.75, bb: 0.80, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
            | row _ |> std/store:insert(res) { id: 4, kind: 0, parent: 0, cx: 110.0, cy: 320.0, touched: 0, alive: 1, br: 0.35, bg: 0.50, bb: 0.90, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
                | row _ |> std/store:insert(res) { id: 5, kind: 0, parent: 0, cx: 270.0, cy: 320.0, touched: 0, alive: 1, br: 0.60, bg: 0.45, bb: 0.90, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
                    | row _ |> std/store:insert(res) { id: 6, kind: 0, parent: 0, cx: 430.0, cy: 320.0, touched: 0, alive: 1, br: 0.90, bg: 0.45, bb: 0.75, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
                        | row _ |> std/store:insert(res) { id: 7, kind: 1, parent: 0, cx: 590.0, cy: 320.0, touched: 0, alive: 1, br: 0.85, bg: 0.80, bb: 0.60, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
                            | row hf |> std/store:insert(res) { id: 8, kind: 0, parent: hf, cx: 505.0, cy: 225.0, touched: 0, alive: 0, br: 0.75, bg: 0.65, bb: 0.30, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
                                | row _ |> std/store:insert(res) { id: 9, kind: 0, parent: hf, cx: 590.0, cy: 225.0, touched: 0, alive: 0, br: 0.75, bg: 0.65, bb: 0.30, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
                                    | row _ |> std/store:insert(res) { id: 10, kind: 0, parent: hf, cx: 675.0, cy: 225.0, touched: 0, alive: 0, br: 0.75, bg: 0.65, bb: 0.30, t: 0.0, s: 1.0, rx: 0.0, ry: 0.0, rw: 0.0, rh: 0.0, rr: 0.0, rg: 0.0, rb: 0.0 }
                                        | row _ |> std/store:stored { world.folderH: hf }

libs/clay:init(width: 720, height: 460)
| cl h |> libs/metal:window.open(width: 720, height: 460, title: "omni folder — 1 open, 2 pin, esc quits")
    | win w |> libs/metal:window.clear.color(win: w, r: 0.10, g: 0.10, b: 0.15)
            |> libs/metal:frames(win: w, count: 99999)
        ! frame f
            |> std/store:stored { world.frame: world.frame + 1 }
            |> std/store:stored { cam.tilt: cam.tilt + (@as(f64, @floatFromInt(world.tiltT)) - cam.tilt) * 0.10 }
            |> libs/metal:draw.rect(f, x: 0.0, y: 228.0, w: 720.0, h: 2.0, r: 0.45, g: 0.45, b: 0.55, a: cam.tilt * 0.5)
            |> std/store:query(res)
                ! query r
                    |> std/store:stored { r.t: if (world.drift == 0) 0.0 else if (world.frame - r.touched > 240) 1.0 else @as(f64, @floatFromInt(world.frame - r.touched)) / 240.0 }
                    |> std/store:stored { r.s: 1.0 - 0.78 * r.t }
                    |> std/store:stored { r.rx: r.cx * (1.0 - r.t) + 360.0 * r.t - 70.0 * r.s, r.ry: r.cy * (1.0 - r.t) + 230.0 * r.t - 45.0 * r.s + (230.0 - r.cy) * 0.55 * cam.tilt - r.t * 150.0 * cam.tilt, r.rw: 140.0 * r.s, r.rh: 90.0 * r.s * (1.0 - 0.35 * cam.tilt), r.rr: r.br * (1.0 - r.t) + 0.10 * r.t, r.rg: r.bg * (1.0 - r.t) + 0.10 * r.t, r.rb: r.bb * (1.0 - r.t) + 0.15 * r.t }
                    |> libs/metal:draw.rect(f, x: r.rx, y: r.ry, w: r.rw, h: r.rh, r: r.rr, g: r.rg, b: r.rb, a: @as(f64, @floatFromInt(r.alive)))
                    |> libs/metal:draw.rect(f, x: r.rx + r.rw / 2.0 - 4.0, y: r.ry - 14.0, w: 8.0, h: 8.0, r: if (r.id == world.focus) 1.0 else 0.10, g: if (r.id == world.focus) 1.0 else 0.10, b: if (r.id == world.focus) 1.0 else 0.15, a: @as(f64, @floatFromInt(r.alive)))
            |> libs/clay:layout(cl: h)
                ! tree t
                    |> std/store:query(res)
                        ! query r when r.id == world.focus and r.kind == 1
                            |> libs/clay:el.close-to(t, d: 0)
                            |> libs/ui:panel(t, dock: "", ws: "auto", w: 0.0, hs: "auto", h: 0.0, dir: "ltr", gap: 8, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 1, fx: r.rx, fy: r.ry + r.rh + 14.0)
                            |> std/store:query(vreg)
                                ! query v |> libs/clay:el.close-to(t, d: 1)
                                    |> libs/ui:panel(t, dock: "", ws: "fix", w: 52.0, hs: "fix", h: 12.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", v.r, v.g, v.b, a: 255.0, fl: 0, fx: 0.0, fy: 0.0)
                | solved cls |> libs/clay:each(cl: cls)
                    ! cmd rc |> if (rc.kind == 1 and rc.a > 0.0)
                        | then |> libs/metal:draw.rect(f, rc.x, rc.y, rc.w, rc.h, rc.r, rc.g, rc.b, rc.a)
                    | drained |> _
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
        ! key-down k
            |> std/store:query(vreg)
                ! query v when v.vkey == k.code
                    |> if (v.vact == 0)
                        | then |> std/store:query(res)
                            ! query c when c.parent == world.folderH
                                |> std/store:stored { c.alive: 1, c.touched: world.frame }
                    |> if (v.vact == 1)
                        | then |> std/store:query(res)
                            ! query c when c.parent == world.folderH or c.id == world.focus
                                |> std/store:stored { c.touched: world.frame }
        ! close |> libs/metal:quit()
        | done w2 |> libs/clay:drop(cl: h) |> libs/metal:window.close(win: w2) |> std/io:print.ln("folder: closed")
    | err e |> std/io:print.ln("metal init failed: {{ e:s }}")
| err e2 |> std/io:print.ln("clay init failed: {{ e2:s }}")
