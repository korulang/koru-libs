// OMNI spike S5 — layout as DATA. The component internals are rows in a spec
// store, not code: each row is one element, `d` is its depth in the tree, and
// the `! tree` arm walks the rows — close-to(d) pops, open+cfg pushes. Two
// "document" cards (dock: title bar over a stacked body) and a two-column
// tool palette, each floating at a field position — where a chunk sits is
// ours, what fills it is clay's.
import libs/metal
import libs/clay
import std/store
import std/io

std/store:new(world) { frame: 0[i64], drew: 0[i64] }

// One row = one element. d: tree depth. wk/hk: 0=fit 1=grow 2=pct 3=fixed.
// dir: 0=LTR 1=TTB. ax/ay child align. fl: 1 = float at (fx,fy) on root.
std/store:new(spec, capacity: 64) {
    d: i64, wk: i64, w: f64, hk: i64, h: f64,
    dir: i64, gap: i64, pad: i64, ax: i64, ay: i64,
    r: f64, g: f64, b: f64, a: f64,
    fl: i64, fx: f64, fy: f64,
}

libs/clay:init(width: 640, height: 400)
| cl h |> libs/metal:window.open(width: 640, height: 400, title: "omni s5 — spec-driven layout")
    | win w |> libs/metal:window.clear.color(win: w, r: 0.08, g: 0.08, b: 0.11)
            |> libs/metal:frames(win: w, count: 9999)
        ! frame f
            |> std/store:stored { world.frame: world.frame + 1 }
            |> if (world.frame == 1)
                | then |> std/store:insert(spec) { d: 0, wk: 3, w: 220.0, hk: 0, h: 0.0, dir: 1, gap: 0, pad: 0, ax: 0, ay: 0, r: 30.0, g: 32.0, b: 42.0, a: 255.0, fl: 1, fx: 60.0, fy: 70.0 }
                    | row _ |> std/store:insert(spec) { d: 1, wk: 1, w: 0.0, hk: 3, h: 24.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 62.0, g: 74.0, b: 96.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                        | row _ |> std/store:insert(spec) { d: 1, wk: 1, w: 0.0, hk: 0, h: 0.0, dir: 1, gap: 6, pad: 10, ax: 0, ay: 0, r: 24.0, g: 26.0, b: 34.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                            | row _ |> std/store:insert(spec) { d: 2, wk: 1, w: 0.0, hk: 3, h: 8.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 120.0, g: 126.0, b: 142.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                | row _ |> std/store:insert(spec) { d: 2, wk: 1, w: 0.0, hk: 3, h: 8.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 96.0, g: 101.0, b: 118.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                    | row _ |> std/store:insert(spec) { d: 2, wk: 1, w: 0.0, hk: 3, h: 8.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 76.0, g: 80.0, b: 96.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                        | row _ |> std/store:insert(spec) { d: 0, wk: 3, w: 220.0, hk: 0, h: 0.0, dir: 1, gap: 0, pad: 0, ax: 0, ay: 0, r: 42.0, g: 32.0, b: 28.0, a: 255.0, fl: 1, fx: 60.0, fy: 250.0 }
                                            | row _ |> std/store:insert(spec) { d: 1, wk: 1, w: 0.0, hk: 3, h: 24.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 104.0, g: 74.0, b: 56.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                | row _ |> std/store:insert(spec) { d: 1, wk: 1, w: 0.0, hk: 0, h: 0.0, dir: 1, gap: 6, pad: 10, ax: 0, ay: 0, r: 34.0, g: 26.0, b: 22.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                    | row _ |> std/store:insert(spec) { d: 2, wk: 1, w: 0.0, hk: 3, h: 8.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 150.0, g: 118.0, b: 92.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                        | row _ |> std/store:insert(spec) { d: 2, wk: 1, w: 0.0, hk: 3, h: 8.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 118.0, g: 94.0, b: 74.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                            | row _ |> std/store:insert(spec) { d: 0, wk: 0, w: 0.0, hk: 0, h: 0.0, dir: 0, gap: 4, pad: 6, ax: 0, ay: 0, r: 20.0, g: 22.0, b: 30.0, a: 255.0, fl: 1, fx: 340.0, fy: 70.0 }
                                                                | row _ |> std/store:insert(spec) { d: 1, wk: 0, w: 0.0, hk: 0, h: 0.0, dir: 1, gap: 4, pad: 0, ax: 0, ay: 0, r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                    | row _ |> std/store:insert(spec) { d: 2, wk: 3, w: 30.0, hk: 3, h: 26.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 120.0, g: 80.0, b: 200.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                        | row _ |> std/store:insert(spec) { d: 2, wk: 3, w: 30.0, hk: 3, h: 26.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 200.0, g: 150.0, b: 60.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                            | row _ |> std/store:insert(spec) { d: 2, wk: 3, w: 30.0, hk: 3, h: 26.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 60.0, g: 170.0, b: 160.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                                | row _ |> std/store:insert(spec) { d: 1, wk: 0, w: 0.0, hk: 0, h: 0.0, dir: 1, gap: 4, pad: 0, ax: 0, ay: 0, r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                                    | row _ |> std/store:insert(spec) { d: 2, wk: 3, w: 30.0, hk: 3, h: 26.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 190.0, g: 80.0, b: 80.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                                        | row _ |> std/store:insert(spec) { d: 2, wk: 3, w: 30.0, hk: 3, h: 26.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 80.0, g: 110.0, b: 200.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                                            | row _ |> std/store:insert(spec) { d: 2, wk: 3, w: 30.0, hk: 3, h: 26.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 90.0, g: 180.0, b: 90.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
            |> libs/clay:layout(cl: h)
                ! tree t
                    |> std/store:query(spec)
                        ! query s |> libs/clay:el.close-to(t, s.d)
                            |> libs/clay:el.open(t)
                            |> libs/clay:el.cfg(t, s.wk, s.w, s.hk, s.h, s.dir, s.gap, s.pad, s.ax, s.ay, s.r, s.g, s.b, s.a, s.fl, s.fx, s.fy)
                | solved cls |> libs/clay:each(cl: cls)
                    ! cmd rc |> if (rc.kind == 1)
                        | then |> libs/metal:draw.rect(f, rc.x, rc.y, rc.w, rc.h, rc.r, rc.g, rc.b, rc.a)
                    | drained |> std/store:stored { world.drew: 1 }
        ! key-down k when k.code == 53 |> libs/metal:quit()
        ! close |> libs/metal:quit()
        | done w2 |> libs/clay:drop(cl: h) |> libs/metal:window.close(win: w2) |> std/io:print.ln("spec: closed")
    | err e |> std/io:print.ln("metal init failed: {{ e:s }}")
| err e2 |> std/io:print.ln("clay init failed: {{ e2:s }}")
