// Differential fuzz gate — random trees over the reachable Clay
// vocabulary (NATIVE_SOLVER_BRIEF §4), declared to Clay and dumped as a
// normalized CmdView stream, three passes in one binary:
//
//   ==REF==   Clay oracle stream
//   ==CAND==  candidate stream — the native solver (clay:nl.*) walking
//             the same spec rows through the parallel bracket; dock
//             overrides are pre-computed since nl takes raw codes.
//   ==MUT==   known-wrong candidate: same walk but pad/gap/w/eid carry
//             +world.mut corruptions. The comparator must find REF≠MUT —
//             a gate that can't reject a wrong candidate is not a gate.
//
// Coverage: fit/grow/percent/fixed sizing, pad, gap, ax/ay, ltr/ttb,
// dock overrides, float-at-root, clip+childOffset (scroll), image,
// text incl. wrap (long strings + narrow parents), userData (eid).
// The forest is one layout bracket: spec.d = count of open elements
// when the row's element opens (gallery_comp convention); a descend is
// only generated after a container row, so no row lands under a leaf.
// Deterministic: LCG over i64, no wall clock, no argv.
import libs/clay
import libs/nativelayout
import libs/ui
import std/store
import std/io

std/store:new(world) { mut: 0[i64], n: 0[i64] }

// LCG state — s is the draw the depth/kind dice read; s2..s5 chain off it.
std/store:new(rng) { s: 123456789[i64], s2: 0[i64], s3: 0[i64], s4: 0[i64], s5: 0[i64] }

// Generator bookkeeping — d = spec depth (parent open-count), prev = was
// the last row a container (descend legal), wk/hk = this row's size kinds.
std/store:new(gen) { d: 1[i64], k: 0[i64], prev: 1[i64], wk: 1[i64], hk: 1[i64] }

// Spec rows in DFS order — int codes; the walk maps codes to dialect
// words at the call site (gallery_comp convention).
// kind: 0 panel | 1 clip | 2 img | 3 text.  wk/hk: 0 fit 1 grow 2 pct 3 fix.
std/store:new(specs, capacity: 2048) {
    d: i64, kind: i64, eid: i64,
    wk: i64, w: f64, hk: i64, h: f64,
    dir: i64, gap: i64, pad: i64, ax: i64, ay: i64, dk: i64,
    r: f64, g: f64, b: f64, a: f64,
    fl: i64, fx: f64, fy: f64,
    ox: f64, oy: f64, hv: i64,
    txc: i64, fs: f64,
}

for(0..1200)
    ! each i
        |> std/store:stored { rng.s: @mod(rng.s * 1103515245 + 12345, 2147483648) }
        |> std/store:stored { rng.s2: @mod(rng.s * 1103515245 + 12345, 2147483648) }
        |> std/store:stored { rng.s3: @mod(rng.s2 * 1103515245 + 12345, 2147483648) }
        |> std/store:stored { rng.s4: @mod(rng.s3 * 1103515245 + 12345, 2147483648) }
        |> std/store:stored { rng.s5: @mod(rng.s4 * 1103515245 + 12345, 2147483648) }
        |> std/store:stored {
            gen.d: if (gen.prev == 1 and @mod(rng.s, 100) < 30) (if (gen.d < 6) gen.d + 1 else 6) else if (@mod(rng.s, 100) < 75) gen.d else 1 + @mod(rng.s2, gen.d),
            gen.k: @mod(@divTrunc(rng.s, 400), 10),
            gen.wk: @mod(@divTrunc(rng.s, 4000), 4),
            gen.hk: @mod(@divTrunc(rng.s, 16000), 4)
        }
        |> std/store:insert(specs) {
            gen.d,
            kind: if (gen.k < 5) 0 else if (gen.k < 7) 1 else if (gen.k < 9) 2 else 3,
            eid: @as(i64, @intCast(i)),
            gen.wk,
            w: if (gen.wk == 2) 0.05 + @as(f64, @floatFromInt(@mod(rng.s2, 94))) / 100.0 else if (gen.wk == 1 and @mod(rng.s2, 2) == 0) 0.0 else 4.0 + @as(f64, @floatFromInt(@mod(@divTrunc(rng.s2, 300), 76))),
            gen.hk,
            h: if (gen.hk == 2) 0.05 + @as(f64, @floatFromInt(@mod(@divTrunc(rng.s2, 60000), 94))) / 100.0 else if (gen.hk == 1 and @mod(@divTrunc(rng.s2, 7), 2) == 0) 0.0 else 4.0 + @as(f64, @floatFromInt(@mod(@divTrunc(rng.s2, 1000000), 76))),
            dir: @mod(rng.s3, 2),
            gap: @mod(@divTrunc(rng.s3, 2), 8),
            pad: @mod(@divTrunc(rng.s3, 16), 10),
            ax: @mod(@divTrunc(rng.s3, 160), 3),
            ay: @mod(@divTrunc(rng.s3, 480), 3),
            dk: @mod(@divTrunc(rng.s3, 1440), 5),
            r: @as(f64, @floatFromInt(@mod(@divTrunc(rng.s3, 7200), 256))),
            g: @as(f64, @floatFromInt(@mod(@divTrunc(rng.s3, 1843200), 256))),
            b: @as(f64, @floatFromInt(@mod(rng.s4, 256))),
            a: if (@mod(@divTrunc(rng.s4, 256), 6) == 0) 128.0 else 255.0,
            fl: if (@mod(@divTrunc(rng.s4, 1536), 5) == 0) 1 else 0,
            fx: @as(f64, @floatFromInt(@mod(@divTrunc(rng.s4, 7680), 400))) - 60.0,
            fy: @as(f64, @floatFromInt(@mod(@divTrunc(rng.s4, 614400), 320))) - 40.0,
            ox: @as(f64, @floatFromInt(@mod(@divTrunc(rng.s4, 4915200), 160))) - 80.0,
            oy: @as(f64, @floatFromInt(@mod(@divTrunc(rng.s4, 7864320), 160))) - 80.0,
            hv: @mod(@divTrunc(rng.s4, 12582912), 4),
            txc: @mod(@divTrunc(rng.s5, 201326592), 5),
            fs: 8.0 + @as(f64, @floatFromInt(@mod(@divTrunc(rng.s5, 50331648), 20))),
        }
            | row _
        |> std/store:stored { gen.prev: if (gen.k < 7) 1 else 0 }

libs/clay:init(width: 900, height: 640)
| cl h |> std/io:print.ln("==REF==")
    |> libs/clay:layout(cl: h)
        ! tree t
            |> libs/ui:panelx(t, dock: "", ws: "star", w: 0.0, hs: "star", h: 0.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, eid: 7000001)
            |> std/store:query(specs)
                ! query s
                    |> libs/clay:el.close-to(t, s.d)
                    |> if (s.kind == 0)
                        | then |> libs/ui:panelx(t,
                            dock: if (s.dk == 1) "top" else if (s.dk == 2) "left" else if (s.dk == 3) "fill" else "",
                            ws: if (s.wk == 1) "star" else if (s.wk == 2) "pct" else if (s.wk == 3) "fix" else "auto", s.w,
                            hs: if (s.hk == 1) "star" else if (s.hk == 2) "pct" else if (s.hk == 3) "fix" else "auto", s.h,
                            dir: if (s.dir == 1) "ttb" else "ltr", s.gap, s.pad,
                            ax: if (s.ax == 1) "end" else if (s.ax == 2) "center" else "start",
                            ay: if (s.ay == 1) "end" else if (s.ay == 2) "center" else "start",
                            s.r, s.g, s.b, s.a, s.fl, s.fx, s.fy, s.eid)
                    |> if (s.kind == 1)
                        | then |> libs/clay:el.clip(t, s.wk, s.w, s.hk, s.h,
                            s.dir, s.gap, s.pad,
                            s.r, s.g, s.b, s.a,
                            s.ox, s.oy, horiz: @mod(s.hv, 2), vert: @divTrunc(s.hv, 2))
                    |> if (s.kind == 2)
                        | then |> libs/ui:imgpanel(t, dock: "", ws: if (s.wk == 1) "star" else if (s.wk == 2) "pct" else if (s.wk == 3) "fix" else "auto", s.w,
                            hs: if (s.hk == 1) "star" else if (s.hk == 2) "pct" else if (s.hk == 3) "fix" else "auto", s.h,
                            data: s.eid + 5000, s.fl, s.fx, s.fy, s.eid)
                            |> libs/clay:el.close(t)
                    |> if (s.kind == 3)
                        | then |> libs/ui:text(t,
                            tx: if (s.txc == 0) "the quick brown fox jumps over the lazy dog" else if (s.txc == 1) "lorem ipsum dolor sit" else if (s.txc == 2) "ab cd" else "w",
                            s.fs, s.r, s.g, s.b, s.a, s.eid)
        | solved cls |> libs/clay:each(cl: cls)
            ! cmd rc |> std/io:print.ln("cmd k={{ rc.kind:d }} ud={{ rc.ud:d }} r={{ rc.x:d:.3 }},{{ rc.y:d:.3 }},{{ rc.w:d:.3 }},{{ rc.h:d:.3 }} c={{ rc.r:d:.4 }},{{ rc.g:d:.4 }},{{ rc.b:d:.4 }},{{ rc.a:d:.4 }} i={{ rc.img:d }} f={{ rc.fs:d:.1 }} tx={{ rc.tx:s }}")
            | drained |> _
    |> std/io:print.ln("==CAND==")
    |> libs/nativelayout:nl.init(width: 900, height: 640)
    | ncl nh
        |> libs/nativelayout:nl.layout(cl: nh)
            ! ntree nt
                |> libs/nativelayout:nl.el.open(t: nt)
                |> libs/nativelayout:nl.el.cfg(t: nt, wk: 1, w: 0.0, hk: 1, h: 0.0, dir: 1, gap: 0, pad: 0, ax: 0, ay: 0, r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, eid: 7000001)
                |> std/store:query(specs)
                    ! query s
                        |> libs/nativelayout:nl.el.close-to(t: nt, s.d)
                        |> if (s.kind == 0)
                            | then |> libs/nativelayout:nl.el.open(t: nt)
                                |> libs/nativelayout:nl.el.cfg(t: nt,
                                    wk: if (s.dk == 1 or s.dk == 3) 1 else if (s.dk == 2) 3 else s.wk, s.w,
                                    hk: if (s.dk == 1) 3 else if (s.dk == 2 or s.dk == 3) 1 else s.hk, s.h,
                                    s.dir, s.gap, s.pad, s.ax, s.ay,
                                    s.r, s.g, s.b, s.a, s.fl, s.fx, s.fy, s.eid)
                        |> if (s.kind == 1)
                            | then |> libs/nativelayout:nl.el.clip(t: nt, s.wk, s.w, s.hk, s.h,
                                s.dir, s.gap, s.pad,
                                s.r, s.g, s.b, s.a,
                                s.ox, s.oy, horiz: @mod(s.hv, 2), vert: @divTrunc(s.hv, 2))
                        |> if (s.kind == 2)
                            | then |> libs/nativelayout:nl.el.open(t: nt)
                                |> libs/nativelayout:nl.el.img(t: nt, s.wk, s.w, s.hk, s.h,
                                    data: s.eid + 5000, s.fl, s.fx, s.fy, s.eid)
                                |> libs/nativelayout:nl.el.close(t: nt)
                        |> if (s.kind == 3)
                            | then |> libs/nativelayout:nl.el.text(t: nt,
                                tx: if (s.txc == 0) "the quick brown fox jumps over the lazy dog" else if (s.txc == 1) "lorem ipsum dolor sit" else if (s.txc == 2) "ab cd" else "w",
                                s.fs, s.r, s.g, s.b, s.a, s.eid)
            | nsolved cls |> libs/nativelayout:nl.each(cl: cls)
                ! cmd rc |> std/io:print.ln("cmd k={{ rc.kind:d }} ud={{ rc.ud:d }} r={{ rc.x:d:.3 }},{{ rc.y:d:.3 }},{{ rc.w:d:.3 }},{{ rc.h:d:.3 }} c={{ rc.r:d:.4 }},{{ rc.g:d:.4 }},{{ rc.b:d:.4 }},{{ rc.a:d:.4 }} i={{ rc.img:d }} f={{ rc.fs:d:.1 }} tx={{ rc.tx:s }}")
                | drained |> libs/nativelayout:nl.drop(cl: nh)
    | err ne |> std/io:print.ln("nl init failed: {{ ne:s }}")
    |> std/store:stored { world.mut: 1 }
    |> std/io:print.ln("==MUT==")
    |> libs/clay:layout(cl: h)
        ! tree t
            |> libs/ui:panelx(t, dock: "", ws: "star", w: 0.0, hs: "star", h: 0.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, eid: 7000001)
            |> std/store:query(specs)
                ! query s
                    |> libs/clay:el.close-to(t, s.d)
                    |> if (s.kind == 0)
                        | then |> libs/ui:panelx(t,
                            dock: if (s.dk == 1) "top" else if (s.dk == 2) "left" else if (s.dk == 3) "fill" else "",
                            ws: if (s.wk == 1) "star" else if (s.wk == 2) "pct" else if (s.wk == 3) "fix" else "auto", w: if (s.wk == 2) s.w else s.w + @as(f64, @floatFromInt(world.mut)),
                            hs: if (s.hk == 1) "star" else if (s.hk == 2) "pct" else if (s.hk == 3) "fix" else "auto", s.h,
                            dir: if (s.dir == 1) "ttb" else "ltr", gap: s.gap + world.mut, pad: s.pad + world.mut,
                            ax: if (s.ax == 1) "end" else if (s.ax == 2) "center" else "start",
                            ay: if (s.ay == 1) "end" else if (s.ay == 2) "center" else "start",
                            s.r, s.g, s.b, s.a, s.fl, s.fx, s.fy, eid: s.eid + world.mut * 100000)
                    |> if (s.kind == 1)
                        | then |> libs/clay:el.clip(t, s.wk, s.w, s.hk, s.h,
                            s.dir, gap: s.gap + world.mut, pad: s.pad + world.mut,
                            s.r, s.g, s.b, s.a,
                            s.ox, s.oy, horiz: @mod(s.hv, 2), vert: @divTrunc(s.hv, 2))
                    |> if (s.kind == 2)
                        | then |> libs/ui:imgpanel(t, dock: "", ws: if (s.wk == 1) "star" else if (s.wk == 2) "pct" else if (s.wk == 3) "fix" else "auto", w: if (s.wk == 2) s.w else s.w + @as(f64, @floatFromInt(world.mut)),
                            hs: if (s.hk == 1) "star" else if (s.hk == 2) "pct" else if (s.hk == 3) "fix" else "auto", s.h,
                            data: s.eid + 5000, s.fl, s.fx, s.fy, eid: s.eid + world.mut * 100000)
                            |> libs/clay:el.close(t)
                    |> if (s.kind == 3)
                        | then |> libs/ui:text(t,
                            tx: if (s.txc == 0) "the quick brown fox jumps over the lazy dog" else if (s.txc == 1) "lorem ipsum dolor sit" else if (s.txc == 2) "ab cd" else "w",
                            s.fs, s.r, s.g, s.b, s.a, eid: s.eid + world.mut * 100000)
        | solved cls |> libs/clay:each(cl: cls)
            ! cmd rc |> std/io:print.ln("cmd k={{ rc.kind:d }} ud={{ rc.ud:d }} r={{ rc.x:d:.3 }},{{ rc.y:d:.3 }},{{ rc.w:d:.3 }},{{ rc.h:d:.3 }} c={{ rc.r:d:.4 }},{{ rc.g:d:.4 }},{{ rc.b:d:.4 }},{{ rc.a:d:.4 }} i={{ rc.img:d }} f={{ rc.fs:d:.1 }} tx={{ rc.tx:s }}")
            | drained |> _
    |> libs/clay:drop(cl: h)
| err e |> std/io:print.ln("clay init failed: {{ e:s }}")
