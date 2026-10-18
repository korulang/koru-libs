// OMNI spike S5 — layout cost probe. Same spec store, same seed rows,
// same walk as spec.k — but no window: std/benchmarking:run drives the
// whole per-frame pipeline (scratch seed → tx measure → deepest→root
// fold → clay:layout emit + grid solve → command drain) once per
// ! pass for `seconds`, and | done reports passes and elapsed. The
// command drain counts rc instead of drawing — the consumer loop is
// part of the measured pipeline.
import libs/clay
import libs/ui
import std/store
import std/io
import std/benchmarking

std/store:new(world) { n: 0[i64] }

std/store:new(spec, capacity: 64) {
    d: i64, kind: char[8], dock: char[8],
    ws: char[8], w: f64, hs: char[8], h: f64,
    dir: char[8], gap: i64, pad: i64, ax: char[8], ay: char[8],
    r: f64, g: f64, b: f64, a: f64,
    fl: i64, fx: f64, fy: f64,
    id: i64, pid: i64, gc: i64, gr: i64,
    mw: f64, mh: f64, cw: f64, ch: f64, cc: i64,
    tx: char[40], fs: f64,
}

std/store:new(gs) { cf: 0.0[f64], cs: 0.0[f64], cn: 0.0[f64], rf: 0.0[f64], rs: 0.0[f64], rn: 0.0[f64], cstar: 0.0[f64], rstar: 0.0[f64], co: 0.0[f64], ro: 0.0[f64], amax: 0.0[f64], res: 0.0[f64] }
std/store:new(gtrk, capacity: 16) { pid: i64, axis: i64, i: i64, off: f64, size: f64 }

std/store:insert(spec) { d: 0, kind: "dock", dock: "", ws: "fix", w: 220.0, hs: "auto", h: 0.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 30.0, g: 32.0, b: 42.0, a: 255.0, fl: 1, fx: 60.0, fy: 70.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
    | row _ |> std/store:insert(spec) { d: 1, kind: "leaf", dock: "top", ws: "", w: 0.0, hs: "fix", h: 24.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 62.0, g: 74.0, b: 96.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
        | row _ |> std/store:insert(spec) { d: 1, kind: "stack", dock: "fill", ws: "", w: 0.0, hs: "", h: 0.0, dir: "ttb", gap: 6, pad: 10, ax: "start", ay: "start", r: 24.0, g: 26.0, b: 34.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
            | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 120.0, g: 126.0, b: 142.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 96.0, g: 101.0, b: 118.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                    | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 76.0, g: 80.0, b: 96.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                        | row _ |> std/store:insert(spec) { d: 0, kind: "dock", dock: "", ws: "fix", w: 220.0, hs: "auto", h: 0.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 42.0, g: 32.0, b: 28.0, a: 255.0, fl: 1, fx: 60.0, fy: 250.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                            | row _ |> std/store:insert(spec) { d: 1, kind: "leaf", dock: "top", ws: "", w: 0.0, hs: "fix", h: 24.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 104.0, g: 74.0, b: 56.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                | row _ |> std/store:insert(spec) { d: 1, kind: "stack", dock: "fill", ws: "", w: 0.0, hs: "", h: 0.0, dir: "ttb", gap: 6, pad: 10, ax: "start", ay: "start", r: 34.0, g: 26.0, b: 22.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                    | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 150.0, g: 118.0, b: 92.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                        | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 118.0, g: 94.0, b: 74.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                            | row _ |> std/store:insert(spec) { d: 0, kind: "grid", dock: "", ws: "fix", w: 170.0, hs: "fix", h: 98.0, dir: "", gap: 4, pad: 6, ax: "start", ay: "start", r: 20.0, g: 22.0, b: 30.0, a: 255.0, fl: 1, fx: 340.0, fy: 70.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 1, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                | row _ |> std/store:insert(spec) { d: 1, kind: "col", dock: "", ws: "auto", w: 0.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                    | row _ |> std/store:insert(spec) { d: 1, kind: "col", dock: "", ws: "star", w: 1.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 1, gr: 0, tx: "", fs: 0.0 }
                                                        | row _ |> std/store:insert(spec) { d: 1, kind: "row", dock: "", ws: "", w: 0.0, hs: "auto", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                            | row _ |> std/store:insert(spec) { d: 1, kind: "row", dock: "", ws: "", w: 0.0, hs: "star", h: 1.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 1, tx: "", fs: 0.0 }
                                                                | row _ |> std/store:insert(spec) { d: 1, kind: "row", dock: "", ws: "", w: 0.0, hs: "star", h: 1.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 2, tx: "", fs: 0.0 }
                                                                    | row _ |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "", w: 0.0, hs: "", h: 0.0, dir: "ttb", gap: 3, pad: 4, ax: "start", ay: "start", r: 120.0, g: 80.0, b: 200.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 2, pid: 1, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                                        | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "fix", w: 14.0, hs: "fix", h: 10.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 220.0, g: 220.0, b: 240.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 2, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                                            | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "fix", w: 22.0, hs: "fix", h: 6.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 60.0, g: 60.0, b: 70.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 2, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                                                | row _ |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "fix", w: 0.0, hs: "star", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 200.0, g: 150.0, b: 60.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 1, tx: "auto hugs text", fs: 12.0 }
                                                                                    | row _ |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "fix", w: 20.0, hs: "star", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 60.0, g: 170.0, b: 160.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 2, tx: "", fs: 0.0 }
                                                                                        | row _ |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "star", w: 0.0, hs: "fix", h: 18.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 190.0, g: 80.0, b: 80.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 1, gr: 0, tx: "", fs: 0.0 }
                                                                                            | row _ |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "star", w: 0.0, hs: "star", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 80.0, g: 110.0, b: 200.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 1, gr: 1, tx: "", fs: 0.0 }
                                                                                                | row _ |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "fix", w: 18.0, hs: "fix", h: 14.0, dir: "", gap: 0, pad: 0, ax: "center", ay: "center", r: 90.0, g: 180.0, b: 90.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 1, gr: 2, tx: "", fs: 0.0 }

libs/clay:init(width: 640, height: 400)
| cl h |> std/benchmarking:run(seconds: 3)
    ! pass
        |> std/store:query(spec)
            ! query s
                |> std/store:stored { s.mw: 0.0, s.mh: 0.0, s.cw: 0.0, s.ch: 0.0, s.cc: 0 }
        |> std/store:query(spec)
            ! query s when s.tx != ""
                |> libs/clay:measure.text(s.tx, s.fs): dims
                |> std/store:stored { s.w: dims.w, s.h: dims.h, s.mw: dims.w, s.mh: dims.h }
        |> for(&[_]i64{ 2, 1 })
            ! each lv |> std/store:query(spec)
                ! query s when s.pid != 0 and s.d == lv
                    |> std/store:stored { s.mw: if (s.ws == "fix") s.w else if (s.cc == 0) 0.0 else if (s.dir == "ttb") s.cw + @as(f64, @floatFromInt(s.pad)) * 2.0 else s.cw - @as(f64, @floatFromInt(s.gap)) + @as(f64, @floatFromInt(s.pad)) * 2.0, s.mh: if (s.hs == "fix") s.h else if (s.cc == 0) 0.0 else if (s.dir == "ttb") s.ch - @as(f64, @floatFromInt(s.gap)) + @as(f64, @floatFromInt(s.pad)) * 2.0 else s.ch + @as(f64, @floatFromInt(s.pad)) * 2.0 }
                |> std/store:query(spec)
                    ! query s when s.pid != 0 and s.d == lv
                        |> std/store:query(spec)
                            ! query p when p.id == s.pid
                                |> std/store:stored { p.cc: p.cc + 1, p.cw: if (p.dir == "ttb") (if (s.mw > p.cw) s.mw else p.cw) else p.cw + s.mw + @as(f64, @floatFromInt(p.gap)), p.ch: if (p.dir == "ttb") p.ch + s.mh + @as(f64, @floatFromInt(p.gap)) else (if (s.mh > p.ch) s.mh else p.ch) }
        |> libs/clay:layout(cl: h)
            ! tree t
                |> std/store:clear(gtrk)
                |> std/store:query(spec)
                    ! query s
                        |> if (s.kind == "grid")
                            | then |> libs/clay:el.close-to(t, s.d)
                                |> libs/ui:panel(t, s.dock, s.ws, s.w, s.hs, s.h, s.dir, s.gap, s.pad, s.ax, s.ay, s.r, s.g, s.b, s.a, s.fl, s.fx, s.fy)
                                |> std/store:stored { gs.cf: 0.0, gs.cs: 0.0, gs.cn: 0.0, gs.rf: 0.0, gs.rs: 0.0, gs.rn: 0.0 }
                                |> std/store:query(spec)
                                    ! query d when d.pid == s.id and d.kind == "col"
                                        |> std/store:stored { gs.amax: 0.0 }
                                        |> std/store:query(spec)
                                            ! query c when d.ws == "auto" and c.pid == s.id and c.kind == "cell" and c.gc == d.gc
                                                |> std/store:stored { gs.amax: if (c.mw > gs.amax) c.mw else gs.amax }
                                        |> std/store:stored { gs.cf: gs.cf + if (d.ws == "star") 0.0 else if (d.ws == "auto") gs.amax else d.w, gs.cs: gs.cs + if (d.ws == "star") d.w else 0.0, gs.cn: gs.cn + 1.0 }
                                |> std/store:query(spec)
                                    ! query d when d.pid == s.id and d.kind == "row"
                                        |> std/store:stored { gs.amax: 0.0 }
                                        |> std/store:query(spec)
                                            ! query c when d.hs == "auto" and c.pid == s.id and c.kind == "cell" and c.gr == d.gr
                                                |> std/store:stored { gs.amax: if (c.mh > gs.amax) c.mh else gs.amax }
                                        |> std/store:stored { gs.rf: gs.rf + if (d.hs == "star") 0.0 else if (d.hs == "auto") gs.amax else d.h, gs.rs: gs.rs + if (d.hs == "star") d.h else 0.0, gs.rn: gs.rn + 1.0 }
                                |> std/store:stored { gs.cstar: if (gs.cs == 0.0) 0.0 else (s.w - 2.0 * @as(f64, @floatFromInt(s.pad)) - gs.cf - @as(f64, @floatFromInt(s.gap)) * (gs.cn - 1.0)) / gs.cs, gs.rstar: if (gs.rs == 0.0) 0.0 else (s.h - 2.0 * @as(f64, @floatFromInt(s.pad)) - gs.rf - @as(f64, @floatFromInt(s.gap)) * (gs.rn - 1.0)) / gs.rs }
                                |> std/store:stored { gs.co: 0.0 }
                                |> std/store:query(spec)
                                    ! query d when d.pid == s.id and d.kind == "col"
                                        |> std/store:stored { gs.amax: 0.0 }
                                        |> std/store:query(spec)
                                            ! query c when d.ws == "auto" and c.pid == s.id and c.kind == "cell" and c.gc == d.gc
                                                |> std/store:stored { gs.amax: if (c.mw > gs.amax) c.mw else gs.amax }
                                        |> std/store:stored { gs.res: if (d.ws == "star") (if (gs.cstar * d.w < 0.0) 0.0 else gs.cstar * d.w) else if (d.ws == "auto") gs.amax else d.w }
                                        |> std/store:insert(gtrk) { pid: s.id, axis: 0, i: d.gc, off: s.fx + @as(f64, @floatFromInt(s.pad)) + gs.co, size: gs.res }
                                            | row _ |> std/store:stored { gs.co: gs.co + gs.res + @as(f64, @floatFromInt(s.gap)) }
                                |> std/store:stored { gs.ro: 0.0 }
                                |> std/store:query(spec)
                                    ! query d when d.pid == s.id and d.kind == "row"
                                        |> std/store:stored { gs.amax: 0.0 }
                                        |> std/store:query(spec)
                                            ! query c when d.hs == "auto" and c.pid == s.id and c.kind == "cell" and c.gr == d.gr
                                                |> std/store:stored { gs.amax: if (c.mh > gs.amax) c.mh else gs.amax }
                                        |> std/store:stored { gs.res: if (d.hs == "star") (if (gs.rstar * d.h < 0.0) 0.0 else gs.rstar * d.h) else if (d.hs == "auto") gs.amax else d.h }
                                        |> std/store:insert(gtrk) { pid: s.id, axis: 1, i: d.gr, off: s.fy + @as(f64, @floatFromInt(s.pad)) + gs.ro, size: gs.res }
                                            | row _ |> std/store:stored { gs.ro: gs.ro + gs.res + @as(f64, @floatFromInt(s.gap)) }
                        |> if (s.kind == "cell")
                            | then |> std/store:query(gtrk)
                                ! query tc when tc.pid == s.pid and tc.axis == 0 and tc.i == s.gc
                                    |> std/store:query(gtrk)
                                        ! query tr when tr.pid == s.pid and tr.axis == 1 and tr.i == s.gr
                                            |> libs/clay:el.close-to(t, s.d)
                                            |> libs/ui:panel(t, dock: "", ws: "fix", w: if (s.ws == "fix") s.w else tc.size, hs: "fix", h: if (s.hs == "fix") s.h else tr.size, s.dir, s.gap, s.pad, s.ax, s.ay, s.r, s.g, s.b, s.a, fl: 1, fx: tc.off + if (s.ax == "center") (tc.size - (if (s.ws == "fix") s.w else tc.size)) / 2.0 else if (s.ax == "end") tc.size - (if (s.ws == "fix") s.w else tc.size) else 0.0, fy: tr.off + if (s.ay == "center") (tr.size - (if (s.hs == "fix") s.h else tr.size)) / 2.0 else if (s.ay == "end") tr.size - (if (s.hs == "fix") s.h else tr.size) else 0.0)
                        |> if (s.kind != "grid" and s.kind != "cell" and s.kind != "col" and s.kind != "row")
                            | then |> libs/clay:el.close-to(t, s.d)
                                |> libs/ui:panel(t, s.dock, s.ws, s.w, s.hs, s.h, s.dir, s.gap, s.pad, s.ax, s.ay, s.r, s.g, s.b, s.a, s.fl, s.fx, s.fy)
            | solved cls |> libs/clay:each(cl: cls)
                ! cmd _ |> std/store:stored { world.n: world.n + 1 }
                | drained |> std/store:stored { world.n: world.n + 0 }
    | done d |> std/io:print.ln("layout: {{ d.passes:d }} passes in {{ d.seconds:f }}s")
        |> std/io:print.ln("us/layout: {{ d.seconds * 1000000.0 / @as(f64, @floatFromInt(d.passes)):f }}")
        |> libs/clay:drop(cl: h)
| err e |> std/io:print.ln("clay init failed: {{ e:s }}")
