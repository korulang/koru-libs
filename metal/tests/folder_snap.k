// folder.k as an automation scenario — the S4 derived-tooling A/B.
// Seven injected → land focus on the folder (id 7); snap f170 shows the
// vreg-derived strip under it (two tiles, one per registered verb). '1'
// injected at f190 fires vact 0 (open): the folder's three parked
// children materialize. Snap f240 shows them landed. Quit f260.
// registration: one table declaring the folder kind's verbs (vkey ->
// vact). The scene DERIVES chrome from it — sweep vreg, draw one tile
// per verb under the focused folder — and dispatch goes through it too:
// the key arm looks up vkey, reads vact, fires. Add a vreg row and a
// tile plus its binding both appear; the claim under test is that a
// derived surface can carry real tooling, not authored widgets.
//
//   → cycles focus, 1 = open (children land), 2 = pin (keep-warm the
//   group), T tilt, D drift, esc quits.
//
//   koruc run metal/tests/folder.k

import libs/metal
import std/store
import std/io

std/store:new(world) { frame: 0[i64], focus: 0[i64], n: 8[i64], tiltT: 0[i64], drift: 1[i64], folderH: 0[i64] }
std/store:new(cam) { tilt: 0.0[f64] }

// ui/folder register: keycode -> action (0 open, 1 pin), vi = tile ordinal.
std/store:new(vreg, capacity: 8) { vkey: i64, vact: i64, vi: i64 }
std/store:insert(vreg) { vkey: 18, vact: 0, vi: 0 }
| row _ |> std/store:insert(vreg) { vkey: 19, vact: 1, vi: 1 }
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

libs/metal:window.open(width: 720, height: 460, title: "omni folder snap")
| win w |> libs/metal:window.clear.color(win: w, r: 0.10, g: 0.10, b: 0.15)
        |> libs/metal:frames(win: w, count: 99999)
    ! frame f
        |> std/store:stored { world.frame: world.frame + 1 }
        |> std/store:stored { cam.tilt: cam.tilt + (@as(f64, @floatFromInt(world.tiltT)) - cam.tilt) * 0.10 }
        |> if (world.frame == 20)
            | then |> libs/metal:input.key(code: 124)
        |> if (world.frame == 40)
            | then |> libs/metal:input.key(code: 124)
        |> if (world.frame == 60)
            | then |> libs/metal:input.key(code: 124)
        |> if (world.frame == 80)
            | then |> libs/metal:input.key(code: 124)
        |> if (world.frame == 100)
            | then |> libs/metal:input.key(code: 124)
        |> if (world.frame == 120)
            | then |> libs/metal:input.key(code: 124)
        |> if (world.frame == 140)
            | then |> libs/metal:input.key(code: 124)
        |> if (world.frame == 170)
            | then |> libs/metal:window.snap(path: "/tmp/omni_folder_closed.bmp")
        |> if (world.frame == 190)
            | then |> libs/metal:input.key(code: 18)
        |> if (world.frame == 240)
            | then |> libs/metal:window.snap(path: "/tmp/omni_folder_open.bmp")
        |> if (world.frame == 260)
            | then |> libs/metal:quit()
        |> libs/metal:draw.rect(f, x: 0.0, y: 228.0, w: 720.0, h: 2.0, r: 0.45, g: 0.45, b: 0.55, a: cam.tilt * 0.5)
        |> std/store:query(res)
            ! query r
                |> std/store:stored { r.t: if (world.drift == 0) 0.0 else if (world.frame - r.touched > 240) 1.0 else @as(f64, @floatFromInt(world.frame - r.touched)) / 240.0 }
                |> std/store:stored { r.s: 1.0 - 0.78 * r.t }
                |> std/store:stored { r.rx: r.cx * (1.0 - r.t) + 360.0 * r.t - 70.0 * r.s, r.ry: r.cy * (1.0 - r.t) + 230.0 * r.t - 45.0 * r.s + (230.0 - r.cy) * 0.55 * cam.tilt - r.t * 150.0 * cam.tilt, r.rw: 140.0 * r.s, r.rh: 90.0 * r.s * (1.0 - 0.35 * cam.tilt), r.rr: r.br * (1.0 - r.t) + 0.10 * r.t, r.rg: r.bg * (1.0 - r.t) + 0.10 * r.t, r.rb: r.bb * (1.0 - r.t) + 0.15 * r.t }
                |> libs/metal:draw.rect(f, x: r.rx, y: r.ry, w: r.rw, h: r.rh, r: r.rr, g: r.rg, b: r.rb, a: @as(f64, @floatFromInt(r.alive)))
                |> libs/metal:draw.rect(f, x: r.rx + r.rw / 2.0 - 4.0, y: r.ry - 14.0, w: 8.0, h: 8.0, r: if (r.id == world.focus) 1.0 else 0.10, g: if (r.id == world.focus) 1.0 else 0.10, b: if (r.id == world.focus) 1.0 else 0.15, a: @as(f64, @floatFromInt(r.alive)))
        |> std/store:query(res)
            ! query r when r.id == world.focus and r.kind == 1
                |> std/store:query(vreg)
                    ! query v |> libs/metal:draw.rect(f, x: r.rx + @as(f64, @floatFromInt(v.vi)) * 56.0, y: r.ry + r.rh + 14.0, w: 48.0, h: 10.0, r: if (v.vact == 0) 0.65 else 0.95, g: if (v.vact == 0) 0.35 else 0.70, b: if (v.vact == 0) 1.00 else 0.20, a: 1.0)
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
    | done w2 |> libs/metal:window.close(win: w2) |> std/io:print.ln("folder_snap: closed")
| err e |> std/io:print.ln("metal init failed: {{ e:s }}")
