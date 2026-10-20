// OMNI bench gate — nanoui hillclimb "boxes" scene, correctness half.
// One deterministic pass at gs.t = 100/120 (hillclimb frame 100):
// 1 bg quad + 600 shadowed rounded boxes in a 20x30 grid, dumped in
// nanoui's instance format for a geometry diff against the reference.
//
// Reproduce the reference: clone github.com/justrach/nanoui, build the
// hillclimb `dump` exe (a Tester that prints t.instances for one frame —
// ~40 lines over src/main.zig's runNanoui), run
//   dump --scene boxes --frame 100 2> ref.txt
// then  ./a.out > cand.txt  and  python3 bench_boxes_cmp.py ref.txt cand.txt
// (0.005pt / 0.002-color tolerance — f32-vs-f64 rounding is expected;
// a gr/gc-swapped seed fails with 2247 divergences and 200 orphans).
// The leaf rows are retained spec data; offset + hsl + shadow are
// paint-side derivations, mirroring nanoui decl.offset / decl.shadow.
import libs/clay
import libs/ui
import std/store
import std/io

std/store:new(world) { n: 0[i64] }

std/store:new(leaves, capacity: 1024) { i: i64, gr: i64, gc: i64 }

std/store:new(gs) { t: 0.83333333333333337[f64], hh: 0.0[f64], k0: 0.0[f64], k8: 0.0[f64], k4: 0.0[f64], off: 0.0[f64] }

for(0..600)
    ! each j |> std/store:insert(leaves) { i: @as(i64, @intCast(j)), gr: @divTrunc(@as(i64, @intCast(j)), 30), gc: @mod(@as(i64, @intCast(j)), 30) }

libs/clay:init(width: 900, height: 640)
| cl h |> libs/clay:layout(cl: h)
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
    | solved cls |> libs/clay:each(cl: cls)
        ! cmd rc
            |> std/store:stored { gs.off: 6.0 * @sin(gs.t * 3.0 + @as(f64, @floatFromInt(rc.ud)) * 0.1) }
            |> std/store:stored { world.n: world.n + 1 }
            |> if (world.n == 1)
                | then |> std/io:print.ln("0 kind=0 rect=0.000,0.000,900.000,640.000 r=0.00 c=0.9608,0.9608,0.9686,1.0000 clip=-1000000.0,-1000000.0,1000000.0,1000000.0")
            |> std/io:print.ln("{{ world.n * 2 - 1:d }} kind=2 rect={{ rc.x:d:.3 }},{{ rc.y + gs.off + 2.0:d:.3 }},{{ rc.w:d:.3 }},{{ rc.h:d:.3 }} r=6.00 c=0.0000,0.0000,0.0000,0.2000 clip=-1000000.0,-1000000.0,1000000.0,1000000.0")
            |> std/io:print.ln("{{ world.n * 2:d }} kind=0 rect={{ rc.x:d:.3 }},{{ rc.y + gs.off:d:.3 }},{{ rc.w:d:.3 }},{{ rc.h:d:.3 }} r=6.00 c={{ rc.r:d:.4 }},{{ rc.g:d:.4 }},{{ rc.b:d:.4 }},{{ rc.a:d:.4 }} clip=-1000000.0,-1000000.0,1000000.0,1000000.0")
        | drained |> libs/clay:drop(cl: h)
            |> std/io:print.ln("gate: {{ world.n:d }} cmds")
| err e |> std/io:print.ln("clay init failed: {{ e:s }}")
