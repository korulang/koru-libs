// OMNI gallery — COMPONENTS AS DATA. Same surface as gallery.k/gallery_live.k,
// but the tree is authored rows in [spec] expanded per frame into [view]'s
// primitive rows, and emit walks view blind. The expansion pass IS the
// component model: a composite kind (vlist/tab/button/toggle/slider) is a
// rule mapping a spec row + world state to a primitive subtree — state
// (scroll range, tab active, toggle label, row sel/hover tints) bakes into
// emitted props here, so emit needs no state reads at all.
//
//   spec row kinds: panel, text (primitive copy-through) and
//   vlist, tab, button, toggle, slider (composite — expand inline)
//   view row kinds: panel, clip, text — the only vocabulary emit knows
//
//   uid rides spec.uid → view.uid → eid → hit.seq unchanged: a click on a
//   tab's panel OR its text maps to the same component instance.
//
// Depth convention (view.d): the count of elements open when the row's
// element should open — el.close-to pops to it; a composite's children sit
// at parent.d + 1 (text leaves don't push depth; close-to is a no-op for
// them and they land under the innermost open element).
//
// ud namespace: 1..60 = list rows, 100 = button, 101 = toggle,
// 102 = slider track, 200+i = tabs, 300 = the clicks label.
//
// Scripted twin: input.* drivers on fixed frames, snapshot at 15, quit at 20.
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
    clicks: 0[i64], tog: 0[i64], ic: 0[i64], r0: 0[i64], r1: 59[i64], icount: 0[i64],
}
std/store:new(fworld) {
    scroll: 0.0[f64], slider: 0.3[f64],
    lx0: 0.0[f64], ly0: 60.0[f64], lx1: 300.0[f64], ly1: 420.0[f64],
    sx: 0.0[f64], sw: 1.0[f64],
}
std/store:new(wins) { w: 640.0[f64], h: 480.0[f64] }
std/store:new(hit, capacity: 96) { seq: i64, cl: i64, x: f64, y: f64, w: f64, h: f64 }

// List CONTENT — the rows the vlist shows. Store memory is stable across
// the drain, so tx feeds clay text directly (no drain-drawn labels).
// insert(items) anywhere — next frame's expansion picks it up.
std/store:new(items, capacity: 128) { tx: char[40] }

// The AUTHORED tree — spec rows in DFS order. Composite kinds are legal
// here and illegal in view; n is the component param slot (tab index,
// vlist count).
std/store:new(spec, capacity: 32) {
    d: i64, kind: char[8], ws: char[8], w: f64, hs: char[8], h: f64,
    dir: char[8], gap: i64, pad: i64, ax: char[8], ay: char[8],
    r: f64, g: f64, b: f64, a: f64,
    n: i64, uid: i64, tx: char[40], fs: f64,
}

// The EXPANDED tree — rebuilt every frame by the pass below. Sizing/
// direction/alignment arrive as clay's int codes (emit maps them to the
// dialect strings panelx wants; el.clip takes the ints). ox/oy feed
// el.clip's childOffset.
std/store:new(view, capacity: 256) {
    d: i64, kind: char[8], wk: i64, w: f64, hk: i64, h: f64,
    dir: i64, gap: i64, pad: i64, ax: i64, ay: i64,
    r: f64, g: f64, b: f64, a: f64,
    ox: f64, oy: f64,
    uid: i64, tx: char[40], fs: f64,
}

libs/clay:init(width: 640, height: 480)
| cl h |> libs/metal:window.open(width: 640, height: 480, title: "omni gallery — components")
    | win w |> libs/metal:window.clear.color(win: w, r: 0.08, g: 0.08, b: 0.11)
            |> std/store:insert(spec) { d: 0, kind: "panel", ws: "star", w: 0.0, hs: "star", h: 0.0, dir: "ltr", gap: 20, pad: 20, ax: "start", ay: "start", r: 14.0, g: 15.0, b: 20.0, a: 255.0, n: 0, uid: 0, tx: "", fs: 0.0 }            |> std/store:insert(spec) { d: 1, kind: "vlist", ws: "star", w: 0.0, hs: "star", h: 0.0, dir: "ttb", gap: 6, pad: 8, ax: "start", ay: "start", r: 22.0, g: 24.0, b: 32.0, a: 255.0, n: 60, uid: 0, tx: "", fs: 0.0 }            |> std/store:insert(spec) { d: 1, kind: "panel", ws: "star", w: 0.0, hs: "star", h: 0.0, dir: "ttb", gap: 14, pad: 12, ax: "start", ay: "start", r: 22.0, g: 24.0, b: 32.0, a: 255.0, n: 0, uid: 0, tx: "", fs: 0.0 }            |> std/store:insert(spec) { d: 2, kind: "text", ws: "", w: 0.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "", ay: "", r: 230.0, g: 234.0, b: 246.0, a: 255.0, n: 0, uid: 0, tx: "control gallery", fs: 15.0 }            |> std/store:insert(spec) { d: 2, kind: "panel", ws: "star", w: 0.0, hs: "fix", h: 34.0, dir: "ltr", gap: 4, pad: 0, ax: "start", ay: "center", r: 30.0, g: 32.0, b: 42.0, a: 255.0, n: 0, uid: 0, tx: "", fs: 0.0 }            |> std/store:insert(spec) { d: 3, kind: "tab", ws: "", w: 0.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "", ay: "", r: 0.0, g: 0.0, b: 0.0, a: 0.0, n: 0, uid: 200, tx: "alpha", fs: 13.0 }            |> std/store:insert(spec) { d: 3, kind: "tab", ws: "", w: 0.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "", ay: "", r: 0.0, g: 0.0, b: 0.0, a: 0.0, n: 1, uid: 201, tx: "beta", fs: 13.0 }            |> std/store:insert(spec) { d: 3, kind: "tab", ws: "", w: 0.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "", ay: "", r: 0.0, g: 0.0, b: 0.0, a: 0.0, n: 2, uid: 202, tx: "gamma", fs: 13.0 }            |> std/store:insert(spec) { d: 2, kind: "button", ws: "", w: 0.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "", ay: "", r: 0.0, g: 0.0, b: 0.0, a: 0.0, n: 0, uid: 100, tx: "click me", fs: 13.0 }            |> std/store:insert(spec) { d: 2, kind: "text", ws: "", w: 0.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "", ay: "", r: 170.0, g: 176.0, b: 196.0, a: 255.0, n: 0, uid: 300, tx: "clicks:", fs: 13.0 }            |> std/store:insert(spec) { d: 2, kind: "toggle", ws: "", w: 0.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "", ay: "", r: 0.0, g: 0.0, b: 0.0, a: 0.0, n: 0, uid: 101, tx: "", fs: 13.0 }            |> std/store:insert(spec) { d: 2, kind: "text", ws: "", w: 0.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "", ay: "", r: 160.0, g: 166.0, b: 186.0, a: 255.0, n: 0, uid: 0, tx: "slider", fs: 12.0 }            |> std/store:insert(spec) { d: 2, kind: "slider", ws: "", w: 0.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "", ay: "", r: 0.0, g: 0.0, b: 0.0, a: 0.0, n: 0, uid: 102, tx: "", fs: 0.0 }
            |> libs/metal:frames(win: w, count: 9999)
                ! frame f
                    |> std/store:stored { world.frame: world.frame + 1 }
                    |> std/store:clear(hit)
                    |> std/store:clear(view)
                    |> libs/metal:window.size(win: w): wh
                    |> std/store:stored { wins.w: wh.w, wins.h: wh.h }
                    |> libs/clay:dims(cl: h, width: wh.w, height: wh.h)
                    // EXPANSION PASS — spec rows walk in order; each kind's
                    // rule inserts its primitive subtree into view. State
                    // reads (scroll, tab, tog, sel, hover, down) live HERE —
                    // emit below is state-free by construction.
                    // Seed the content store once — items are data, so a
                    // live insert anywhere would do the same thing.
                    |> for(0..60)
                        ! each ii |> if (world.frame == 1)
                            | then |> std/string:from-int(n: @as(i64, @intCast(ii)))
                                | ok is |> std/store:insert(items) { tx: is.data }
                                    |> std/string:free(s: is)
                                | err ie |> std/io:print.ln(ie)
                    |> std/store:query(items)
                        ! query { [row]ic, [ordinal]io } |> std/store:stored { world.icount: io }
                    |> std/store:query(spec)
                        ! query s
                            |> if (s.kind == "panel")
                                | then |> std/store:insert(view) { d: s.d, kind: "panel", wk: if (s.ws == "star") 1 else if (s.ws == "fix") 3 else 0, w: s.w, hk: if (s.hs == "star") 1 else if (s.hs == "fix") 3 else 0, h: s.h, dir: if (s.dir == "ttb") 1 else 0, gap: s.gap, pad: s.pad, ax: if (s.ax == "end") 1 else if (s.ax == "center") 2 else 0, ay: if (s.ay == "end") 1 else if (s.ay == "center") 2 else 0, r: s.r, g: s.g, b: s.b, a: s.a, ox: 0.0, oy: 0.0, uid: s.uid, tx: "", fs: 0.0 }
                                    | row _
                            |> if (s.kind == "text")
                                | then |> std/store:insert(view) { d: s.d, kind: "text", wk: 0, w: 0.0, hk: 0, h: 0.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: s.r, g: s.g, b: s.b, a: s.a, ox: 0.0, oy: 0.0, uid: s.uid, tx: s.tx, fs: s.fs }
                                    | row _
                            // vlist — the stateful composite: reads scroll +
                            // LAST frame's clip box to derive the visible
                            // range, emits clip + spacers + intersecting rows.
                            |> if (s.kind == "vlist")
                                | then |> std/store:insert(view) { d: s.d, kind: "clip", wk: if (s.ws == "star") 1 else if (s.ws == "fix") 3 else 0, w: s.w, hk: if (s.hs == "star") 1 else if (s.hs == "fix") 3 else 0, h: s.h, dir: if (s.dir == "ttb") 1 else 0, gap: s.gap, pad: s.pad, ax: if (s.ax == "end") 1 else if (s.ax == "center") 2 else 0, ay: if (s.ay == "end") 1 else if (s.ay == "center") 2 else 0, r: s.r, g: s.g, b: s.b, a: s.a, ox: 0.0, oy: 0.0 - fworld.scroll, uid: s.uid, tx: "", fs: 0.0 }
                                    | row _ |> if (world.r0 > 0)
                                        | then |> std/store:insert(view) { d: s.d + 1, kind: "panel", wk: 1, w: 0.0, hk: 3, h: @as(f64, @floatFromInt(world.r0)) * 36.0 - 6.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 0.0, g: 0.0, b: 0.0, a: 0.0, ox: 0.0, oy: 0.0, uid: 0, tx: "", fs: 0.0 }
                                            | row _
                                    |> std/store:query(items)
                                        ! query { [row]it, [ordinal]io } when @as(i64, @intCast(io)) - 1 >= world.r0 and @as(i64, @intCast(io)) - 1 <= world.r1
                                            |> std/store:insert(view) { d: s.d + 1, kind: "panel", wk: 1, w: 0.0, hk: 3, h: 30.0, dir: 1, gap: 0, pad: 10, ax: 0, ay: 2, r: 46.0 + (if (@as(i64, @intCast(io)) - 1 == world.sel) @as(f64, 60.0) else if (@as(i64, @intCast(io)) == world.hover) @as(f64, 24.0) else @as(f64, 0.0)), g: 48.0 + (if (@as(i64, @intCast(io)) - 1 == world.sel) @as(f64, 50.0) else if (@as(i64, @intCast(io)) == world.hover) @as(f64, 24.0) else @as(f64, 0.0)), b: 60.0, a: 255.0, ox: 0.0, oy: 0.0, uid: @as(i64, @intCast(io)), tx: "", fs: 0.0 }
                                                | row _ |> std/store:insert(view) { d: s.d + 2, kind: "text", wk: 0, w: 0.0, hk: 0, h: 0.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 200.0, g: 205.0, b: 220.0, a: 255.0, ox: 0.0, oy: 0.0, uid: @as(i64, @intCast(io)), tx: it.tx, fs: 13.0 }
                                                    | row _
                                    |> if (world.r1 < world.icount - 1)
                                        | then |> std/store:insert(view) { d: s.d + 1, kind: "panel", wk: 1, w: 0.0, hk: 3, h: @as(f64, @floatFromInt(world.icount - 1 - world.r1)) * 36.0 - 6.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 0.0, g: 0.0, b: 0.0, a: 0.0, ox: 0.0, oy: 0.0, uid: 0, tx: "", fs: 0.0 }
                                            | row _
                            |> if (s.kind == "tab")
                                | then |> std/store:insert(view) { d: s.d, kind: "panel", wk: 3, w: 90.0, hk: 3, h: 28.0, dir: 1, gap: 0, pad: 0, ax: 2, ay: 2, r: if (world.tab == s.n) 90.0 else if (world.hover == s.uid) 70.0 else 52.0, g: if (world.tab == s.n) 100.0 else if (world.hover == s.uid) 72.0 else 56.0, b: if (world.tab == s.n) 130.0 else if (world.hover == s.uid) 80.0 else 66.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.uid, tx: "", fs: 0.0 }
                                    | row _ |> std/store:insert(view) { d: s.d + 1, kind: "text", wk: 0, w: 0.0, hk: 0, h: 0.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 225.0, g: 228.0, b: 240.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.uid, tx: s.tx, fs: s.fs }
                                        | row _
                            |> if (s.kind == "button")
                                | then |> std/store:insert(view) { d: s.d, kind: "panel", wk: 3, w: 160.0, hk: 3, h: 36.0, dir: 1, gap: 0, pad: 0, ax: 2, ay: 2, r: if (world.down == s.uid) 60.0 else if (world.hover == s.uid) 105.0 else 84.0, g: if (world.down == s.uid) 100.0 else if (world.hover == s.uid) 180.0 else 150.0, b: if (world.down == s.uid) 170.0 else if (world.hover == s.uid) 255.0 else 220.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.uid, tx: "", fs: 0.0 }
                                    | row _ |> std/store:insert(view) { d: s.d + 1, kind: "text", wk: 0, w: 0.0, hk: 0, h: 0.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 240.0, g: 244.0, b: 252.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.uid, tx: s.tx, fs: s.fs }
                                        | row _
                            |> if (s.kind == "toggle")
                                | then |> std/store:insert(view) { d: s.d, kind: "panel", wk: 3, w: 160.0, hk: 3, h: 36.0, dir: 1, gap: 0, pad: 0, ax: 2, ay: 2, r: if (world.tog == 1) 60.0 else 66.0, g: if (world.tog == 1) 170.0 else 70.0, b: if (world.tog == 1) 110.0 else 78.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.uid, tx: "", fs: 0.0 }
                                    | row _ |> std/store:insert(view) { d: s.d + 1, kind: "text", wk: 0, w: 0.0, hk: 0, h: 0.0, dir: 0, gap: 0, pad: 0, ax: 0, ay: 0, r: 230.0, g: 234.0, b: 244.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.uid, tx: if (world.tog == 1) "toggle: on" else "toggle: off", fs: s.fs }
                                        | row _
                            |> if (s.kind == "slider")
                                | then |> std/store:insert(view) { d: s.d, kind: "panel", wk: 3, w: 200.0, hk: 3, h: 10.0, dir: 1, gap: 0, pad: 0, ax: 0, ay: 2, r: 60.0, g: 64.0, b: 78.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.uid, tx: "", fs: 0.0 }
                                    | row _
                    // The virtual window reads LAST frame's clip box, same
                    // contract as the hand-rolled gallery.
                    |> std/store:stored {
                        world.r0: @max(0, @as(i64, @intFromFloat(@floor(fworld.scroll / 36.0)))),
                        world.r1: @min(world.icount - 1, @as(i64, @intFromFloat(@floor((fworld.scroll + fworld.ly1 - fworld.ly0) / 36.0))))
                    }
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
                        | then |> libs/metal:window.snap(path: "/tmp/gallery_comp_snap.bmp")
                    // EMIT — blind over view: close-to the row's depth,
                    // dispatch on the primitive kind. No state reads;
                    // expansion already baked them.
                    |> libs/clay:layout(cl: h)
                        ! tree t
                            |> std/store:query(view)
                                ! query { [row]v }
                                    |> if (v.kind == "panel")
                                        | then |> libs/clay:el.close-to(t, v.d)
                                            |> libs/ui:panelx(t, dock: "", ws: if (v.wk == 1) "star" else if (v.wk == 3) "fix" else "", v.w, hs: if (v.hk == 1) "star" else if (v.hk == 3) "fix" else "", v.h, dir: if (v.dir == 1) "ttb" else "ltr", v.gap, v.pad, ax: if (v.ax == 2) "center" else if (v.ax == 1) "end" else "start", ay: if (v.ay == 2) "center" else if (v.ay == 1) "end" else "start", v.r, v.g, v.b, v.a, fl: 0, fx: 0.0, fy: 0.0, eid: v.uid)
                                    |> if (v.kind == "clip")
                                        | then |> libs/clay:el.close-to(t, v.d)
                                            |> libs/clay:el.open(t)
                                            |> libs/clay:el.clip(t, v.wk, v.w, v.hk, v.h, v.dir, v.gap, v.pad, v.r, v.g, v.b, v.a, v.ox, v.oy, horiz: 0, vert: 1)
                                    |> if (v.kind == "text")
                                        | then |> libs/clay:el.close-to(t, v.d)
                                            |> libs/ui:text(t, v.tx, v.fs, v.r, v.g, v.b, v.a, eid: v.uid)
                        | solved cls |> libs/clay:each(cl: cls)
                            ! cmd rc |> if (rc.kind == 1)
                                | then |> std/store:insert(hit) { seq: rc.ud, cl: world.ic, rc.x, rc.y, rc.w, rc.h }
                                    |> libs/metal:draw.rect(f, x: @round(rc.x), y: @round(rc.y), w: @round(rc.x + rc.w) - @round(rc.x), h: @round(rc.y + rc.h) - @round(rc.y), rc.r, rc.g, rc.b, rc.a)
                                    |> if (rc.ud == 102)
                                        | then |> std/store:stored { fworld.sx: rc.x, fworld.sw: rc.w }
                                            |> libs/metal:draw.rect(f, x: @round(rc.x + fworld.slider * (rc.w - 14.0)), y: @round(rc.y - 4.0), w: 14.0, h: 18.0, r: 120.0, g: 170.0, b: 240.0, a: 255.0)
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
                    |> if (world.frame == 20)
                        | then |> libs/metal:quit()
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
                        | then |> std/store:stored { fworld.scroll: if (fworld.scroll - e.dy < 0.0) 0.0 else if (fworld.scroll - e.dy > @as(f64, @floatFromInt(world.icount)) * 36.0 + 10.0 - (fworld.ly1 - fworld.ly0)) @as(f64, @floatFromInt(world.icount)) * 36.0 + 10.0 - (fworld.ly1 - fworld.ly0) else fworld.scroll - e.dy }
                ! close |> libs/metal:quit()
                | done w2 |> libs/clay:drop(cl: h) |> libs/metal:window.close(win: w2) |> std/io:print.ln("clicks: {{ world.clicks:d }} tog: {{ world.tog:d }} tab: {{ world.tab:d }} sel: {{ world.sel:d }} scroll: {{ fworld.scroll:f }} slider: {{ fworld.slider:f }}") |> std/io:print.ln("gallery_comp: closed (snapped)")
    | err e |> std/io:print.ln("metal init failed: {{ e:s }}")
| err e3 |> std/io:print.ln("clay init failed: {{ e3:s }}")
