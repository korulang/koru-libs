// OMNI bench — solver A/B: Clay vs the native bracket, same tree, same pass.
// Each climb frame runs BOTH pipelines back to back (per-frame interleave —
// every lap samples both solvers under the same clock/load):
//   lap 1  clay: spec query + HSL + ui:panel*/panelx declares
//   lap 2  clay: trailing closes + Clay_EndLayout (solve + commands)
//   lap 3  clay: each drain
//   lap 4  nl:   same spec query + HSL + nl.el.* declares
//   lap 5  nl:   trailing closes + native solve
//   lap 6  nl:   nl.each drain
// Caveat: lap 1 pays ui's word-mapping + zeroed C decl construction that a
// routed-nl world would partially still pay — nl's lap 4 excludes it, so
// lap 1 vs lap 4 slightly favors nl. Laps 2 vs 5 are pure solver.
import libs/clay
import libs/nativelayout
import libs/ui
import std/store
import std/io
import std/benchmarking

std/store:new(world) { n: 0[i64], m: 0[i64], f: 0[i64] }

std/store:new(leaves, capacity: 1024) { i: i64, gr: i64, gc: i64 }

std/store:new(gs) { t: 0.0[f64], hh: 0.0[f64], k0: 0.0[f64], k8: 0.0[f64], k4: 0.0[f64], off: 0.0[f64] }

for(0..600)
    ! each j |> std/store:insert(leaves) { i: @as(i64, @intCast(j)), gr: @divTrunc(@as(i64, @intCast(j)), 30), gc: @mod(@as(i64, @intCast(j)), 30) }

libs/clay:init(width: 900, height: 640)
| cl h |> libs/nativelayout:nl.init(width: 900, height: 640)
    | ncl nh |> std/benchmarking:climb(warmup: 30, frames: 300, reps: 3)
        ! pass
            |> std/store:stored { world.f: world.f + 1 }
            |> std/store:stored { gs.t: @as(f64, @floatFromInt(world.f)) / 120.0 }
            |> std/store:stored { world.n: 0, world.m: 0 }
            |> libs/clay:layout(cl: h)
                ! tree t
                    |> libs/ui:panel(t, dock: "", ws: "star", w: 1.0, hs: "star", h: 1.0, dir: "ttb", gap: 4, pad: 10, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0)
                    |> for(0..20)
                        ! each rr
                            |> libs/clay:el.close-to(t, d: 1)
                            |> libs/ui:panel(t, dock: "", ws: "star", w: 1.0, hs: "auto", h: 0.0, dir: "", gap: 4, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0)
                            |> std/store:query(leaves)
                                ! query lf when lf.gr == @as(i64, @intCast(rr))
                                    |> std/store:stored { gs.hh: @mod(gs.t * 60.0 + @as(f64, @floatFromInt(lf.i)) * 3.0, 360.0) }
                                    |> std/store:stored { gs.k0: @mod(0.0 + gs.hh / 30.0, 12.0), gs.k8: @mod(8.0 + gs.hh / 30.0, 12.0), gs.k4: @mod(4.0 + gs.hh / 30.0, 12.0) }
                                    |> libs/ui:panelx(t, dock: "", ws: "fix", w: 24.0, hs: "fix", h: 24.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start",
                                        r: (0.55 - 0.315 * @max(-1.0, @min(@min(gs.k0 - 3.0, 9.0 - gs.k0), 1.0))) * 255.0,
                                        g: (0.55 - 0.315 * @max(-1.0, @min(@min(gs.k8 - 3.0, 9.0 - gs.k8), 1.0))) * 255.0,
                                        b: (0.55 - 0.315 * @max(-1.0, @min(@min(gs.k4 - 3.0, 9.0 - gs.k4), 1.0))) * 255.0,
                                        a: 255.0, fl: 0, fx: 0.0, fy: 0.0, eid: lf.i)
                                    |> libs/clay:el.close(t)
                    |> std/benchmarking:lap(k: 1)
                | solved cls |> std/benchmarking:lap(k: 2)
                    |> libs/clay:each(cl: cls)
                        ! cmd rc
                            |> std/store:stored { gs.off: 6.0 * @sin(gs.t * 3.0 + @as(f64, @floatFromInt(rc.ud)) * 0.1) }
                            |> std/store:stored { world.n: world.n + 1 }
                        | drained |> _
                    |> std/benchmarking:lap(k: 3)
            |> libs/nativelayout:nl.layout(cl: nh)
                ! ntree nt
                    |> libs/nativelayout:nl.el.open(t: nt)
                    |> libs/nativelayout:nl.el.cfg(t: nt, wk: 1, w: 1.0, hk: 1, h: 1.0, dir: 1, gap: 4, padl: 10, padr: 10, padt: 10, padb: 10, ax: 0, ay: 0, r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, eid: 0)
                    |> for(0..20)
                        ! each rr
                            |> libs/nativelayout:nl.el.close-to(t: nt, d: 1)
                            |> libs/nativelayout:nl.el.open(t: nt)
                            |> libs/nativelayout:nl.el.cfg(t: nt, wk: 1, w: 1.0, hk: 0, h: 0.0, dir: 0, gap: 4, padl: 0, padr: 0, padt: 0, padb: 0, ax: 0, ay: 0, r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, eid: 0)
                            |> std/store:query(leaves)
                                ! query lf when lf.gr == @as(i64, @intCast(rr))
                                    |> std/store:stored { gs.hh: @mod(gs.t * 60.0 + @as(f64, @floatFromInt(lf.i)) * 3.0, 360.0) }
                                    |> std/store:stored { gs.k0: @mod(0.0 + gs.hh / 30.0, 12.0), gs.k8: @mod(8.0 + gs.hh / 30.0, 12.0), gs.k4: @mod(4.0 + gs.hh / 30.0, 12.0) }
                                    |> libs/nativelayout:nl.el.open(t: nt)
                                    |> libs/nativelayout:nl.el.cfg(t: nt, wk: 3, w: 24.0, hk: 3, h: 24.0, dir: 0, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 0, ay: 0,
                                        r: (0.55 - 0.315 * @max(-1.0, @min(@min(gs.k0 - 3.0, 9.0 - gs.k0), 1.0))) * 255.0,
                                        g: (0.55 - 0.315 * @max(-1.0, @min(@min(gs.k8 - 3.0, 9.0 - gs.k8), 1.0))) * 255.0,
                                        b: (0.55 - 0.315 * @max(-1.0, @min(@min(gs.k4 - 3.0, 9.0 - gs.k4), 1.0))) * 255.0,
                                        a: 255.0, fl: 0, fx: 0.0, fy: 0.0, eid: lf.i)
                                    |> libs/nativelayout:nl.el.close(t: nt)
                    |> std/benchmarking:lap(k: 4)
                | nsolved ncls |> std/benchmarking:lap(k: 5)
                    |> libs/nativelayout:nl.each(cl: ncls)
                        ! cmd rc
                            |> std/store:stored { gs.off: 6.0 * @sin(gs.t * 3.0 + @as(f64, @floatFromInt(rc.ud)) * 0.1) }
                            |> std/store:stored { world.m: world.m + 1 }
                        | drained |> _
                    |> std/benchmarking:lap(k: 6)
        | done d
            |> std/benchmarking:lap.ms(k: 1): a1 |> std/benchmarking:lap.ms(k: 2): a2 |> std/benchmarking:lap.ms(k: 3): a3
            |> std/benchmarking:lap.ms(k: 4): a4 |> std/benchmarking:lap.ms(k: 5): a5 |> std/benchmarking:lap.ms(k: 6): a6
            |> std/io:print.ln("clay: decl {{ a1:f }} solve {{ a2:f }} drain {{ a3:f }} cmds {{ world.n:d }} | nl: decl {{ a4:f }} solve {{ a5:f }} drain {{ a6:f }} cmds {{ world.m:d }} | frame {{ d.ms:f }} laps {{ d.laps:d }}")
            |> libs/nativelayout:nl.drop(cl: nh)
            |> libs/clay:drop(cl: h)
    | err ne |> std/io:print.ln("nl init failed: {{ ne:s }}")
| err e |> std/io:print.ln("clay init failed: {{ e:s }}")
