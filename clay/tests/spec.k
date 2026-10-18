// OMNI spike S5 — layout as DATA, in the panel dialect. Each row is one
// element declared in WPF vocabulary: `kind` names the panel (stack|dock|
// leaf|grid|cell|col|row), `dock` is a child's dock slot, `ws`/`hs` are
// Auto|fix|star|pct words, `dir` is the stack orientation, `fl`+`fx`/`fy`
// is canvas semantics (float at a field position). The walk is
// close-to(d) + panel — the dialect lives in the rows, libs/ui lowers
// the words, libs/clay solves, Metal draws.
//
// grid is the dialect's shared-track panel — the thing clay structurally
// cannot do: a `grid` row authors its own rect (fl+fx/fy + fix w/h),
// `col`/`row` children declare track sizes in the same ws/w | hs/h words
// (fix = px, star w = the N in `N*`, auto = hug the largest member cell's
// measured size), and `cell` children carry gc/gr — the walk solves tracks
// into gtrk and emits each cell floating at its solved rect.
//
// `auto` is a real measure: a per-frame pass sweeps spec deepest→root —
// each row finalizes mw/mh (fix = declared; else children folded along
// dir with gap+pad) then adds itself into its parent's accumulators via
// pid — and an auto track takes the max member mw/mh. A cell carrying
// children (rows at deeper d with pid=cell.id) hugs its subtree, and a
// row carrying `tx` is rendered content — `clay:measure.text` bakes its
// w/h from the OS font metric (fs = point size) before the fold.
import libs/metal
import libs/clay
import libs/ui
import std/store
import std/io

std/store:new(world) { frame: 0[i64], drew: 0[i64] }

// One row = one element in the dialect. d: tree depth. kind: stack|leaf|
// grid|cell|col|row. dock: ""|top|bottom|left|right|fill (a dock slot
// derives the cross-axis sizing). ws/hs: auto|fix|star|pct. dir: ttb|ltr.
// ax/ay: start|end|center. fl: 1 = canvas — float at (fx,fy).
// id/pid: row identity + parent link — grid scope (a cell's pid names its
// grid's id; def rows likewise) AND the measure pass's child→parent edge:
// a measured subtree's rows link pid→id. gc/gr: the cell's column/row
// track index; defs declare theirs in gc/gr too. mw/mh + cw/ch/cc are the
// measure pass's scratch — natural size and child accumulators.
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

// Grid solve scratch: per-axis accumulators (fix sum, star weight sum,
// count, resolved star size, running offset/index) plus the solved track
// rect table cell arms read back — pid keys the owning grid row,
// axis 0 = column track, 1 = row track. Cleared and re-solved each frame.
std/store:new(gs) { cf: 0.0[f64], cs: 0.0[f64], cn: 0.0[f64], rf: 0.0[f64], rs: 0.0[f64], rn: 0.0[f64], cstar: 0.0[f64], rstar: 0.0[f64], co: 0.0[f64], ro: 0.0[f64], amax: 0.0[f64], res: 0.0[f64] }
std/store:new(gtrk, capacity: 16) { pid: i64, axis: i64, i: i64, off: f64, size: f64 }

libs/clay:init(width: 640, height: 400)
| cl h |> libs/metal:window.open(width: 640, height: 400, title: "omni s5 — spec-driven layout")
    | win w |> libs/metal:window.clear.color(win: w, r: 0.08, g: 0.08, b: 0.11)
            |> libs/metal:frames(win: w, count: 9999)
        ! frame f
            |> std/store:stored { world.frame: world.frame + 1 }
            |> if (world.frame == 1)
                | then |> std/store:insert(spec) { d: 0, kind: "dock", dock: "", ws: "fix", w: 220.0, hs: "auto", h: 0.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 30.0, g: 32.0, b: 42.0, a: 255.0, fl: 1, fx: 60.0, fy: 70.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
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
            // measure: seed scratch, then sweep deepest→root — each row
            // finalizes mw/mh (fix = declared; else children folded along
            // dir with gap+pad) then adds itself into its parent's
            // accumulators via pid. The depth list is authored ({2, 1} —
            // the spec's real depth); ! each lv carries it into both sweeps.
            // A row carrying tx is rendered content — its w/h (and mw/mh)
            // bake from the OS's font metric, then the fold sees a fix row.
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
                    ! cmd rc |> if (rc.kind == 1)
                        | then |> libs/metal:draw.rect(f, rc.x, rc.y, rc.w, rc.h, rc.r, rc.g, rc.b, rc.a)
                    | drained |> std/store:stored { world.drew: 1 }
        ! key-down k when k.code == 53 |> libs/metal:quit()
        ! close |> libs/metal:quit()
        | done w2 |> libs/clay:drop(cl: h) |> libs/metal:window.close(win: w2) |> std/io:print.ln("spec: closed")
    | err e |> std/io:print.ln("metal init failed: {{ e:s }}")
| err e2 |> std/io:print.ln("clay init failed: {{ e2:s }}")
