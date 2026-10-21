// OMNI gallery — SCRIPTED. gallery_live.k with injected drivers instead
// of a human: scroll/click/drag events exercise the same mailbox arms,
// one snapshot pins the result. The control surface built from the verbs the
// event/mouse work added: a virtualized scroll list (clay:el.clip +
// SCISSOR commands + draw.clip), a tab strip, a button, a toggle, and a
// slider — all hand-emitted elements, state in stores, hit-testing via
// the drained-command map. No spec store: the tree is a fixed shape
// emitted in order, same way a compiled component would emit it.
// Element nesting is RUNTIME — el.open/el.close mutate clay's stack, so
// the emit chain below is flat; indentation only marks branch arms.
//
//   fworld.scroll   list scroll offset; childOffset on the clip element
//   world.hover    ud under the pointer (-1 = none)
//   world.down     ud the press started on — click = down+up on same ud
//   world.tab      active tab index (0..2)
//   world.sel      selected list row (-1 = none)
//   world.clicks   button press count
//   world.tog      toggle state 0/1
//   fworld.slider   0..1
//   world.ic       inside-scissor flag, set while draining kind 5..6 —
//                  stamps cl=1 on hit rows so pointer guards can require
//                  containment in the clip box (clay does NOT clamp child
//                  boundingBoxes to the scissor — without this a row
//                  scrolled above the viewport still swallows clicks)
//   fworld.lx0..ly1 the clip box, written when SCISSOR_START drains;
//                  scroll arms + virtual window read LAST frame's box
//   fworld.sx/sw    slider track rect, written when its RECT drains —
//                  mouse-down/drag arms map x into 0..1 through it
//   world.r0/r1    first/last visible row indices — the virtualization:
//                  only rows intersecting the viewport emit; spacers take
//                  the culled space so clay sees the full content extent
//
// ud namespace: 1..60 = list rows, 100 = button, 101 = toggle,
// 102 = slider track, 200+i = tabs.
//
// Row geometry: 30px rows, gap 6, stride 36, 60 rows, pad 8 —
// content height 8+8+60*30+59*6 = 2170.
//
// Pointer bookkeeping: hover always repaints; down marks the press
// target; up fires the click iff it lands on down's ud.
//
import libs/metal
import libs/clay
import libs/ui
import std/store
import std/io
import std/string

std/store:new(world) {
    frame: 0[i64],
    hover: -1[i64], down: -1[i64], tab: 0[i64], sel: -1[i64],
    clicks: 0[i64], tog: 0[i64], ic: 0[i64], r0: 0[i64], r1: 59[i64],
}
std/store:new(fworld) {
    scroll: 0.0[f64], slider: 0.3[f64],
    lx0: 0.0[f64], ly0: 60.0[f64], lx1: 300.0[f64], ly1: 420.0[f64],
    sx: 0.0[f64], sw: 1.0[f64],
}
std/store:new(wins) { w: 640.0[f64], h: 480.0[f64] }
std/store:new(hit, capacity: 96) { seq: i64, cl: i64, x: f64, y: f64, w: f64, h: f64 }

libs/clay:init(width: 640, height: 480)
| cl h |> libs/metal:window.open(width: 640, height: 480, title: "omni gallery — controls")
    | win w |> libs/metal:window.clear.color(win: w, r: 0.08, g: 0.08, b: 0.11)
            |> libs/metal:frames(win: w, count: 16)
                ! frame f
                    |> std/store:stored { world.frame: world.frame + 1 }
                    |> std/store:clear(hit)
                    |> libs/metal:window.size(win: w): wh
                    |> std/store:stored { wins.w: wh.w, wins.h: wh.h }
                    |> libs/clay:dims(cl: h, width: wh.w, height: wh.h)
                    |> if (world.frame == 3)
                        | then |> libs/metal:input.scroll(x: 100.0, y: 200.0, dx: 0.0, dy: 0.0 - 200.0)
                    |> if (world.frame == 4)
                        | then |> libs/metal:input.mouse(x: 410.0, y: 128.0)
                    |> if (world.frame == 5)
                        | then |> libs/metal:input.up(x: 410.0, y: 128.0)
                    |> if (world.frame == 6)
                        | then |> libs/metal:input.mouse(x: 400.0, y: 208.0)
                    |> if (world.frame == 7)
                        | then |> libs/metal:input.up(x: 400.0, y: 208.0)
                    |> if (world.frame == 8)
                        | then |> libs/metal:input.mouse(x: 560.0, y: 80.0)
                    |> if (world.frame == 9)
                        | then |> libs/metal:input.up(x: 560.0, y: 80.0)
                    |> if (world.frame == 10)
                        | then |> libs/metal:input.mouse(x: 500.0, y: 272.0)
                    |> if (world.frame == 11)
                        | then |> libs/metal:input.drag(x: 380.0, y: 272.0)
                    |> if (world.frame == 12)
                        | then |> libs/metal:input.up(x: 380.0, y: 272.0)
                    |> if (world.frame == 13)
                        | then |> libs/metal:input.mouse(x: 150.0, y: 48.0)
                    |> if (world.frame == 14)
                        | then |> libs/metal:input.up(x: 150.0, y: 48.0)
                    |> if (world.frame == 15)
                        | then |> libs/metal:window.snap(path: "/tmp/gallery_snap.bmp")
                    // The virtual window: which of the 60 rows intersect the
                    // clip box at the current scroll. Reads LAST frame's box —
                    // the drain writes ly0/ly1 before any scroll arm fires.
                    |> std/store:stored {
                        world.r0: @max(0, @as(i64, @intFromFloat(@floor(fworld.scroll / 36.0)))),
                        world.r1: @min(59, @as(i64, @intFromFloat(@floor((fworld.scroll + fworld.ly1 - fworld.ly0) / 36.0))))
                    }
                    |> libs/clay:layout(cl: h)
                        ! tree t
                            |> libs/clay:el.open(t)
                            |> libs/clay:el.cfg(t, wk: 1, w: 0.0, hk: 1, h: 0.0, dir: 0, gap: 20, padl: 20, padr: 20, padt: 20, padb: 20, ax: 0, ay: 0, r: 14.0, g: 15.0, b: 20.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, eid: 0, ovr: 0.0, ovg: 0.0, ovb: 0.0, ova: 0.0)
                            |> libs/clay:el.open(t)
                            |> libs/clay:el.clip(t, wk: 1, w: 0.0, hk: 1, h: 0.0, dir: 1, gap: 6, padl: 8, padr: 8, padt: 8, padb: 8, r: 22.0, g: 24.0, b: 32.0, a: 255.0, ox: 0.0, oy: 0.0 - fworld.scroll, horiz: 0, vert: 1, ovr: 0.0, ovg: 0.0, ovb: 0.0, ova: 0.0)
                            // top spacer stands in for culled rows (its height
                            // minus the gap the spacer itself takes)
                            |> if (world.r0 > 0)
                                | then |> libs/clay:el.open(t)
                                    |> libs/clay:el.cfg(t, wk: 1, w: 0.0, hk: 3, h: @as(f64, @floatFromInt(world.r0)) * 36.0 - 6.0, dir: 0, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 0, ay: 0, r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, eid: 0, ovr: 0.0, ovg: 0.0, ovb: 0.0, ova: 0.0)
                                    |> libs/clay:el.close(t)
                            |> for(0..60)
                                ! each ri |> if (@as(i64, @intCast(ri)) >= world.r0 and @as(i64, @intCast(ri)) <= world.r1)
                                    | then |> libs/ui:panelx(t, dock: "", ws: "star", w: 0.0, hs: "fix", h: 30.0, dir: "ttb", gap: 0, pad: 0, ax: "center", ay: "center", r: 46.0 + (if (@as(i64, @intCast(ri)) == world.sel) @as(f64, 60.0) else if (@as(i64, @intCast(ri)) + 1 == world.hover) @as(f64, 24.0) else @as(f64, 0.0)), g: 48.0 + (if (@as(i64, @intCast(ri)) == world.sel) @as(f64, 50.0) else if (@as(i64, @intCast(ri)) + 1 == world.hover) @as(f64, 24.0) else @as(f64, 0.0)), b: 60.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, eid: @as(i64, @intCast(ri)) + 1)
                                        |> libs/clay:el.close(t)
                            |> if (world.r1 < 59)
                                | then |> libs/clay:el.open(t)
                                    |> libs/clay:el.cfg(t, wk: 1, w: 0.0, hk: 3, h: @as(f64, @floatFromInt(59 - world.r1)) * 36.0 - 6.0, dir: 0, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 0, ay: 0, r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, eid: 0, ovr: 0.0, ovg: 0.0, ovb: 0.0, ova: 0.0)
                                    |> libs/clay:el.close(t)
                            |> libs/clay:el.close(t)
                            |> libs/ui:panelx(t, dock: "", ws: "star", w: 0.0, hs: "star", h: 0.0, dir: "ttb", gap: 14, pad: 12, ax: "start", ay: "start", r: 22.0, g: 24.0, b: 32.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, eid: 0)
                            |> libs/ui:text(t, tx: "control gallery", fs: 15.0, r: 230.0, g: 234.0, b: 246.0, a: 255.0, eid: 0)
                            |> libs/ui:panelx(t, dock: "", ws: "star", w: 0.0, hs: "fix", h: 34.0, dir: "ltr", gap: 4, pad: 0, ax: "start", ay: "center", r: 30.0, g: 32.0, b: 42.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, eid: 0)
                            |> libs/ui:panelx(t, dock: "", ws: "fix", w: 90.0, hs: "fix", h: 28.0, dir: "ttb", gap: 0, pad: 0, ax: "center", ay: "center", r: if (world.tab == 0) 90.0 else if (world.hover == 200) 70.0 else 52.0, g: if (world.tab == 0) 100.0 else if (world.hover == 200) 72.0 else 56.0, b: if (world.tab == 0) 130.0 else if (world.hover == 200) 80.0 else 66.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, eid: 200)
                            |> libs/ui:text(t, tx: "alpha", fs: 13.0, r: 225.0, g: 228.0, b: 240.0, a: 255.0, eid: 200)
                            |> libs/clay:el.close(t)
                            |> libs/ui:panelx(t, dock: "", ws: "fix", w: 90.0, hs: "fix", h: 28.0, dir: "ttb", gap: 0, pad: 0, ax: "center", ay: "center", r: if (world.tab == 1) 90.0 else if (world.hover == 201) 70.0 else 52.0, g: if (world.tab == 1) 100.0 else if (world.hover == 201) 72.0 else 56.0, b: if (world.tab == 1) 130.0 else if (world.hover == 201) 80.0 else 66.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, eid: 201)
                            |> libs/ui:text(t, tx: "beta", fs: 13.0, r: 225.0, g: 228.0, b: 240.0, a: 255.0, eid: 201)
                            |> libs/clay:el.close(t)
                            |> libs/ui:panelx(t, dock: "", ws: "fix", w: 90.0, hs: "fix", h: 28.0, dir: "ttb", gap: 0, pad: 0, ax: "center", ay: "center", r: if (world.tab == 2) 90.0 else if (world.hover == 202) 70.0 else 52.0, g: if (world.tab == 2) 100.0 else if (world.hover == 202) 72.0 else 56.0, b: if (world.tab == 2) 130.0 else if (world.hover == 202) 80.0 else 66.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, eid: 202)
                            |> libs/ui:text(t, tx: "gamma", fs: 13.0, r: 225.0, g: 228.0, b: 240.0, a: 255.0, eid: 202)
                            |> libs/clay:el.close(t)
                            |> libs/clay:el.close(t)
                            |> libs/ui:panelx(t, dock: "", ws: "fix", w: 160.0, hs: "fix", h: 36.0, dir: "ttb", gap: 0, pad: 0, ax: "center", ay: "center", r: if (world.down == 100) 60.0 else if (world.hover == 100) 105.0 else 84.0, g: if (world.down == 100) 100.0 else if (world.hover == 100) 180.0 else 150.0, b: if (world.down == 100) 170.0 else if (world.hover == 100) 255.0 else 220.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, eid: 100)
                            |> libs/ui:text(t, tx: "click me", fs: 13.0, r: 240.0, g: 244.0, b: 252.0, a: 255.0, eid: 100)
                            |> libs/clay:el.close(t)
                            |> libs/ui:text(t, tx: "clicks:", fs: 13.0, r: 170.0, g: 176.0, b: 196.0, a: 255.0, eid: 300)
                            |> libs/ui:panelx(t, dock: "", ws: "fix", w: 160.0, hs: "fix", h: 36.0, dir: "ttb", gap: 0, pad: 0, ax: "center", ay: "center", r: if (world.tog == 1) 60.0 else 66.0, g: if (world.tog == 1) 170.0 else 70.0, b: if (world.tog == 1) 110.0 else 78.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, eid: 101)
                            |> libs/ui:text(t, tx: if (world.tog == 1) "toggle: on" else "toggle: off", fs: 13.0, r: 230.0, g: 234.0, b: 244.0, a: 255.0, eid: 101)
                            |> libs/clay:el.close(t)
                            |> libs/ui:text(t, tx: "slider", fs: 12.0, r: 160.0, g: 166.0, b: 186.0, a: 255.0, eid: 0)
                            |> libs/ui:panelx(t, dock: "", ws: "fix", w: 200.0, hs: "fix", h: 10.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "center", r: 60.0, g: 64.0, b: 78.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, eid: 102)
                            |> libs/clay:el.close(t)
                            |> libs/clay:el.close(t)
                            |> libs/clay:el.close(t)
                        | solved cls |> libs/clay:each(cl: cls)
                            ! cmd rc |> if (rc.kind == 1)
                                | then |> std/store:insert(hit) { seq: rc.ud, cl: world.ic, rc.x, rc.y, rc.w, rc.h }
                                    |> libs/metal:draw.rect(f, x: @round(rc.x), y: @round(rc.y), w: @round(rc.x + rc.w) - @round(rc.x), h: @round(rc.y + rc.h) - @round(rc.y), rc.r, rc.g, rc.b, rc.a)
                                    |> if (rc.ud == 102)
                                        | then |> std/store:stored { fworld.sx: rc.x, fworld.sw: rc.w }
                                            |> libs/metal:draw.rect(f, x: @round(rc.x + fworld.slider * (rc.w - 14.0)), y: @round(rc.y - 4.0), w: 14.0, h: 18.0, r: 120.0, g: 170.0, b: 240.0, a: 255.0)
                                    // Row labels draw HERE, not as clay text — clay borrows the
                                    // string pointer through the drain, so a per-frame String
                                    // must live exactly as long as draw.text needs it: this arm.
                                    |> if (rc.ud >= 1 and rc.ud <= 60)
                                        | then |> std/string:from-int(n: rc.ud - 1)
                                            | ok ns |> libs/metal:text.ascent(win: w, size: 13.0): rasc
                                                |> libs/metal:text.descent(win: w, size: 13.0): rdesc
                                                |> libs/metal:draw.text(f, x: @round(rc.x + 10.0), y: @round(rc.y + (rc.h - rasc - rdesc) / 2.0), size: 13.0, r: 200.0, g: 205.0, b: 220.0, a: 255.0, text: ns.data)
                                                |> std/string:free(s: ns)
                                            | err e0 |> std/io:print.ln(e0)
                            ! cmd rc |> if (rc.kind == 3)
                                | then |> std/store:insert(hit) { seq: rc.ud, cl: world.ic, rc.x, rc.y, rc.w, rc.h }
                                    |> libs/metal:draw.text(f, x: @round(rc.x), y: @round(rc.y), size: rc.fs, rc.r, rc.g, rc.b, rc.a, text: rc.tx)
                                    |> if (rc.ud == 300)
                                        | then |> libs/clay:measure.text(tx: "clicks: ", fs: 13.0): cd
                                            |> std/string:from-int(n: world.clicks)
                                                | ok cn |> libs/metal:draw.text(f, x: @round(rc.x + cd.w), y: @round(rc.y), size: 13.0, r: 170.0, g: 176.0, b: 196.0, a: 255.0, text: cn.data)
                                                    |> std/string:free(s: cn)
                                                | err e1 |> std/io:print.ln(e1)
                            ! cmd rc |> if (rc.kind == 5)
                                | then |> std/store:stored { world.ic: 1 }
                                    |> std/store:stored { fworld.lx0: rc.x, fworld.ly0: rc.y, fworld.lx1: rc.x + rc.w, fworld.ly1: rc.y + rc.h }
                                    |> libs/metal:draw.clip.push(f, rc.x, rc.y, rc.w, rc.h)
                            ! cmd rc |> if (rc.kind == 6)
                                | then |> libs/metal:draw.clip.pop(f)
                                    |> std/store:stored { world.ic: 0 }
                            | drained |> std/store:stored { world.frame: world.frame }
                ! key-down k when k.code == 53 |> libs/metal:quit()
                ! mouse-move e
                    |> std/store:stored { world.hover: -1 }
                    |> std/store:query(hit)
                        ! query hi when (hi.cl == 0 or e.y >= fworld.ly0 and e.y < fworld.ly1) and e.x >= hi.x and e.x < hi.x + hi.w and e.y >= hi.y and e.y < hi.y + hi.h
                            |> std/store:stored { world.hover: hi.seq }
                ! mouse-down e
                    |> std/store:stored { world.down: -1 }
                    |> std/store:query(hit)
                        ! query hi when (hi.cl == 0 or e.y >= fworld.ly0 and e.y < fworld.ly1) and e.x >= hi.x and e.x < hi.x + hi.w and e.y >= hi.y and e.y < hi.y + hi.h
                            |> std/store:stored { world.down: hi.seq }
                    |> if (world.down == 102)
                        | then |> std/store:stored { fworld.slider: if (e.x < fworld.sx) 0.0 else if (e.x > fworld.sx + fworld.sw) 1.0 else (e.x - fworld.sx) / fworld.sw }
                ! mouse-drag e
                    |> if (world.down == 102)
                        | then |> std/store:stored { fworld.slider: if (e.x < fworld.sx) 0.0 else if (e.x > fworld.sx + fworld.sw) 1.0 else (e.x - fworld.sx) / fworld.sw }
                ! mouse-up e
                    |> std/store:query(hit)
                        ! query hi when (hi.cl == 0 or e.y >= fworld.ly0 and e.y < fworld.ly1) and world.down == hi.seq and e.x >= hi.x and e.x < hi.x + hi.w and e.y >= hi.y and e.y < hi.y + hi.h
                            |> if (world.down == 100)
                                | then |> std/store:stored { world.clicks: world.clicks + 1, world.down: -2 }
                            |> if (world.down == 101)
                                | then |> std/store:stored { world.tog: 1 - world.tog, world.down: -2 }
                            |> if (world.down >= 200)
                                | then |> std/store:stored { world.tab: world.down - 200, world.down: -2 }
                            |> if (world.down >= 1 and world.down <= 60)
                                | then |> std/store:stored { world.sel: world.down - 1, world.down: -2 }
                    |> std/store:stored { world.down: -1 }
                ! scroll e
                    |> if (e.x >= fworld.lx0 and e.x < fworld.lx1 and e.y >= fworld.ly0 and e.y < fworld.ly1)
                        | then |> std/store:stored { fworld.scroll: if (fworld.scroll - e.dy < 0.0) 0.0 else if (fworld.scroll - e.dy > 2170.0 - (fworld.ly1 - fworld.ly0)) 2170.0 - (fworld.ly1 - fworld.ly0) else fworld.scroll - e.dy }
                ! close |> libs/metal:quit()
                | done w2 |> libs/clay:drop(cl: h) |> libs/metal:window.close(win: w2) |> std/io:print.ln("clicks: {{ world.clicks:d }} tog: {{ world.tog:d }} tab: {{ world.tab:d }} sel: {{ world.sel:d }} scroll: {{ fworld.scroll:f }} slider: {{ fworld.slider:f }}") |> std/io:print.ln("gallery: closed (snapped)")
    | err e |> std/io:print.ln("metal init failed: {{ e:s }}")
| err e3 |> std/io:print.ln("clay init failed: {{ e3:s }}")
