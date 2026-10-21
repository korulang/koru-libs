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
// ud namespace: 500+i = list rows, 100 = button, 101 = toggle,
// 102 = slider track, 200+i = tabs, 300 = the clicks label.
//
// Scripted twin: input.* drivers on fixed frames — grow the list by slider
// (snap 16), shrink it back (snap 28), quit at 30.
//
import libs/metal
import libs/clay
import libs/ui
import libs/oshun
import std/args
import std/store
import std/io
import std/string
import std/fmt

std/store:new(world) {
    frame: 0[i64],
    hover: -1[i64], down: -1[i64], tab: 0[i64], sel: -1[i64],
    clicks: 0[i64], tog: 0[i64], ic: 0[i64], r0: 0[i64], r1: 59[i64], icount: 0[i64], strip: 0[i64], grafted: 0[i64], live: 0[i64], demo: 0[i64], want: 60[i64], downsk: -1[i64],
    alphah: -1[i64], betah: -1[i64], gammah: -1[i64], deltah: -1[i64],
    buth: -1[i64], togh: -1[i64], sliderh: -1[i64], labelh: -1[i64],
}
std/store:new(fworld) {
    scroll: 0.0[f64], slider: 0.3[f64],
    lx0: 0.0[f64], ly0: 60.0[f64], lx1: 300.0[f64], ly1: 420.0[f64],
    sx: 0.0[f64], sw: 1.0[f64],
}
std/store:new(wins) { w: 640.0[f64], h: 480.0[f64] }
std/store:new(hit, capacity: 96) { seq: i64, cl: i64, x: f64, y: f64, w: f64, h: f64 }

// Items-handle set — refilled each frame from a top-level items query.
// eid carries ROW HANDLES: spec rows arrive via the hid column the seed
// writes (spec[h].hid: h), item rows via the arm's [id]ih. A click on an
// item row resolves by membership here; spec components resolve by
// comparing against handles captured at seed — no uid namespaces.
std/store:new(uids, capacity: 256) { uid: i64 }

// List CONTENT — the rows the vlist shows. Store memory is stable across
// the drain, so tx feeds clay text directly (no drain-drawn labels).
// insert(items) anywhere — next frame's expansion picks it up.
std/store:new(items, capacity: 256) { tx: char[40] }

// Per-instance component state — append-only journal, NOT a record per
// component. Interactions insert {uid, k, v}; expansion folds latest-per-
// key back into the world scalars, so everything downstream is unchanged.
// (std/store has no row-field write: `stored` is cell-only, `take` removes.
// Journal+fold is the honest shape until a real update verb exists.)
std/store:new(cstate, capacity: 1024) { uid: i64, k: char[8], v: f64 }

// The AUTHORED tree — spec rows in DFS order. Composite kinds are legal
// here and illegal in view; n is the component param slot (tab index,
// vlist count).
[tree]std/store:new(spec, capacity: 64) {
    d: i64, kind: char[8], ws: char[8], w: f64, hs: char[8], h: f64,
    dir: char[8], gap: i64, pad: i64, ax: char[8], ay: char[8],
    r: f64, g: f64, b: f64, a: f64,
    n: i64, uid: i64, tx: char[40], fs: f64, ord: i64, hid: i64,
}

// The EXPANDED tree — rebuilt every frame by the pass below. Sizing/
// direction/alignment arrive as clay's int codes (emit maps them to the
// dialect strings panelx wants; el.clip takes the ints). ox/oy feed
// el.clip's childOffset.
std/store:new(view, capacity: 256) {
    d: i64, kind: char[8], wk: i64, w: f64, hk: i64, h: f64,
    dir: i64, gap: i64, padl: i64, padr: i64, padt: i64, padb: i64, ax: i64, ay: i64,
    r: f64, g: f64, b: f64, a: f64,
    ox: f64, oy: f64,
    uid: i64, tx: char[40], fs: f64,
}

// The static tree, authored as markup. `component` synthesizes `seed` — a
// tor whose impl emits the insert/|row|/stored chain the old seed wrote by
// hand (every column filled from the schema, d/ord from the markup shape,
// parent edges from nesting, hid self-handles per row).
libs/oshun:component(seed, spec) {
    <panel ws="star" hs="star" dir="ltr" gap="20" pad="20" ax="start" ay="start" r="14" g="15" b="20" a="255" ord="0">
        <vlist ws="star" hs="star" dir="ttb" gap="6" pad="8" ax="start" ay="start" r="22" g="24" b="32" a="255" n="60" uid="50" ord="100"/>
        <panel ws="star" hs="star" dir="ttb" gap="14" pad="12" ax="start" ay="start" r="22" g="24" b="32" a="255" ord="200">
            <text tx="control {{ which:s }}" fs="15" r="230" g="234" b="246" a="255" ord="300"/>
            <panel ws="star" hs="fix" h="34" dir="ltr" gap="4" ax="start" ay="center" r="30" g="32" b="42" a="255" uid="400" ord="400" bind="world.strip">
                <tab tx="alpha" uid="200" fs="13" ord="500" bind="world.alphah"/>
                <tab tx="beta" uid="201" n={{ bn:d }} fs="13" ord="600" bind="world.betah"/>
                <tab tx="gamma" uid="202" n={{ gn:d }} fs="13" ord="700" bind="world.gammah"/>
            </panel>
            <button tx="click me" uid="100" fs="13" ord="800" bind="world.buth"/>
            <text tx="clicks:" uid="300" fs="13" r="170" g="176" b="196" a="255" ord="900" bind="world.labelh"/>
            <toggle uid="101" fs="13" ord="1000" bind="world.togh"/>
            <text tx="slider" fs="12" r="160" g="166" b="186" a="255" ord="1100"/>
            <slider uid="102" ord="1200" bind="world.sliderh"/>
        </panel>
    </panel>
}

libs/clay:init(width: 640, height: 480)
| cl h |> libs/metal:window.open(width: 640, height: 480, title: "omni gallery — components")
    | win w |> libs/metal:window.clear.color(win: w, r: 0.08, g: 0.08, b: 0.11)
            |> seed(which: "gallery", bn: 1, gn: 2)
            // --live skips the scripted drivers; anything else is the
            // deterministic twin (drivers inject at fixed frames).
            |> std/args:get(index: 1)
                | arg a |> std/store:stored { world.live: if (a == "live") 1 else 0 }
                | out-of-bounds |> std/store:stored { world.live: 0 }
            // live <preset> — play the scripted drivers through a named
            // checkpoint, then hand control over in that exact state.
            |> std/args:get(index: 2)
                | arg b |> std/store:stored { world.demo: if (b == "graft") 9 else if (b == "grown") 15 else if (b == "shrunk") 19 else if (b == "full") 28 else 0 }
                | out-of-bounds |> std/store:stored { world.demo: 0 }
            |> libs/metal:frames(win: w, count: if (world.live == 1) 999999 else 9999)
                ! frame f
                    |> std/store:stored { world.frame: world.frame + 1 }
                    |> std/store:clear(hit)
                    |> std/store:clear(view)
                    |> std/store:clear(uids)
                    |> libs/metal:window.size(win: w): wh
                    |> std/store:stored { wins.w: wh.w, wins.h: wh.h }
                    |> libs/clay:dims(cl: h, width: wh.w, height: wh.h)
                    // Resolve component state: defaults, then latest-per-key
                    // fold of the cstate journal into the world scalars.
                    |> std/store:stored { world.tog: 0, world.tab: 0, world.clicks: 0 }
                    |> std/store:stored { fworld.slider: 0.3 }
                    |> std/store:query(cstate)
                        ! query cs |> std/store:stored {
                            world.clicks: if (cs.uid == 100 and cs.k == "clk") @as(i64, @intFromFloat(cs.v)) else world.clicks,
                            world.tog: if (cs.uid == 101 and cs.k == "tog") @as(i64, @intFromFloat(cs.v)) else world.tog,
                            world.tab: if (cs.uid == 400 and cs.k == "tab") @as(i64, @intFromFloat(cs.v)) else world.tab,
                        }
                            |> std/store:stored { fworld.slider: if (cs.uid == 102 and cs.k == "sli") cs.v else fworld.slider }
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
                    // Slider → list length: want = slider * 200. [ordinal]
                    // is the 0-based dense index, so icount is count-1.
                    // Growing appends labeled rows; shrinking takes rows at
                    // dense positions >= want — swap-remove hides stragglers
                    // inside visited positions, converging over next frames.
                    |> std/store:stored { world.want: @as(i64, @intFromFloat(@round(fworld.slider * 200.0))) }
                    |> if (world.want > world.icount + 1)
                        | then |> for(0..@as(usize, @intCast(world.want - world.icount - 1)))
                            ! each ii |> std/string:from-int(n: world.icount + 1 + @as(i64, @intCast(ii)))
                                | ok is |> std/store:insert(items) { tx: is.data }
                                    |> std/string:free(s: is)
                                | err ie |> std/io:print.ln(ie)
                    |> if (world.want < world.icount + 1)
                        | then |> std/store:query(items)
                            ! query { [row]it, [ordinal]io } when io >= world.want
                                |> std/store:take(items[it])
                                    | item _ |> std/store:stored { world.icount: world.icount - 1 }
                            |> std/store:stored { fworld.scroll: @min(fworld.scroll, @max(0.0, @as(f64, @floatFromInt(world.icount + 1)) * 36.0 + 10.0 - (fworld.ly1 - fworld.ly0))) }
                    |> std/store:query(items)
                        ! query { [row]it, [id]ih }
                            |> std/store:insert(uids) { uid: ih }
                                | row _
                    |> std/store:preorder(spec, order: "ord")
                        ! preorder s
                            |> if (s.kind == "panel")
                                | then |> std/store:insert(view) { d: s.d, kind: "panel", wk: if (s.ws == "star") 1 else if (s.ws == "fix") 3 else 0, w: s.w, hk: if (s.hs == "star") 1 else if (s.hs == "fix") 3 else 0, h: s.h, dir: if (s.dir == "ttb") 1 else 0, gap: s.gap, padl: s.pad, padr: s.pad, padt: s.pad, padb: s.pad, ax: if (s.ax == "end") 1 else if (s.ax == "center") 2 else 0, ay: if (s.ay == "end") 1 else if (s.ay == "center") 2 else 0, r: s.r, g: s.g, b: s.b, a: s.a, ox: 0.0, oy: 0.0, uid: s.hid, tx: "", fs: 0.0 }
                                    | row _
                            |> if (s.kind == "text")
                                | then |> std/store:insert(view) { d: s.d, kind: "text", wk: 0, w: 0.0, hk: 0, h: 0.0, dir: 0, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 0, ay: 0, r: s.r, g: s.g, b: s.b, a: s.a, ox: 0.0, oy: 0.0, uid: s.hid, tx: s.tx, fs: s.fs }
                                    | row _
                            // vlist — the stateful composite: reads scroll +
                            // LAST frame's clip box to derive the visible
                            // range, emits clip + spacers + intersecting rows.
                            |> if (s.kind == "vlist")
                                | then |> std/store:insert(view) { d: s.d, kind: "clip", wk: if (s.ws == "star") 1 else if (s.ws == "fix") 3 else 0, w: s.w, hk: if (s.hs == "star") 1 else if (s.hs == "fix") 3 else 0, h: s.h, dir: if (s.dir == "ttb") 1 else 0, gap: s.gap, padl: s.pad, padr: s.pad, padt: s.pad, padb: s.pad, ax: if (s.ax == "end") 1 else if (s.ax == "center") 2 else 0, ay: if (s.ay == "end") 1 else if (s.ay == "center") 2 else 0, r: s.r, g: s.g, b: s.b, a: s.a, ox: 0.0, oy: 0.0 - fworld.scroll, uid: s.hid, tx: "", fs: 0.0 }
                                    | row _ |> if (world.r0 > 0)
                                        | then |> std/store:insert(view) { d: s.d + 1, kind: "panel", wk: 1, w: 0.0, hk: 3, h: @as(f64, @floatFromInt(world.r0)) * 36.0 - 6.0, dir: 0, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 0, ay: 0, r: 0.0, g: 0.0, b: 0.0, a: 0.0, ox: 0.0, oy: 0.0, uid: 0, tx: "", fs: 0.0 }
                                            | row _
                                    |> std/store:query(items)
                                        ! query { [row]it, [ordinal]io, [id]ih } when @as(i64, @intCast(io)) >= world.r0 and @as(i64, @intCast(io)) <= world.r1
                                            |> std/store:insert(view) { d: s.d + 1, kind: "panel", wk: 1, w: 0.0, hk: 3, h: 30.0, dir: 1, gap: 0, padl: 10, padr: 10, padt: 10, padb: 10, ax: 0, ay: 2, r: 46.0 + (if (ih == world.sel) @as(f64, 60.0) else if (ih == world.hover) @as(f64, 24.0) else @as(f64, 0.0)), g: 48.0 + (if (ih == world.sel) @as(f64, 50.0) else if (ih == world.hover) @as(f64, 24.0) else @as(f64, 0.0)), b: 60.0, a: 255.0, ox: 0.0, oy: 0.0, uid: ih, tx: "", fs: 0.0 }
                                                    | row _ |> std/store:insert(view) { d: s.d + 2, kind: "text", wk: 0, w: 0.0, hk: 0, h: 0.0, dir: 0, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 0, ay: 0, r: 200.0, g: 205.0, b: 220.0, a: 255.0, ox: 0.0, oy: 0.0, uid: ih, tx: it.tx, fs: 13.0 }
                                                        | row _
                                    |> if (world.r1 < world.icount)
                                        | then |> std/store:insert(view) { d: s.d + 1, kind: "panel", wk: 1, w: 0.0, hk: 3, h: @as(f64, @floatFromInt(world.icount - world.r1)) * 36.0 - 6.0, dir: 0, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 0, ay: 0, r: 0.0, g: 0.0, b: 0.0, a: 0.0, ox: 0.0, oy: 0.0, uid: 0, tx: "", fs: 0.0 }
                                            | row _
                            |> if (s.kind == "tab")
                                | then |> std/store:insert(view) { d: s.d, kind: "panel", wk: 3, w: 90.0, hk: 3, h: 28.0, dir: 1, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 2, ay: 2, r: if (world.tab == s.n) 90.0 else if (world.hover == s.hid) 70.0 else 52.0, g: if (world.tab == s.n) 100.0 else if (world.hover == s.hid) 72.0 else 56.0, b: if (world.tab == s.n) 130.0 else if (world.hover == s.hid) 80.0 else 66.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.hid, tx: "", fs: 0.0 }
                                    | row _ |> std/store:insert(view) { d: s.d + 1, kind: "text", wk: 0, w: 0.0, hk: 0, h: 0.0, dir: 0, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 0, ay: 0, r: 225.0, g: 228.0, b: 240.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.hid, tx: s.tx, fs: s.fs }
                                        | row _
                            |> if (s.kind == "button")
                                | then |> std/store:insert(view) { d: s.d, kind: "panel", wk: 3, w: 160.0, hk: 3, h: 36.0, dir: 1, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 2, ay: 2, r: if (world.down == s.hid) 60.0 else if (world.hover == s.hid) 105.0 else 84.0, g: if (world.down == s.hid) 100.0 else if (world.hover == s.hid) 180.0 else 150.0, b: if (world.down == s.hid) 170.0 else if (world.hover == s.hid) 255.0 else 220.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.hid, tx: "", fs: 0.0 }
                                    | row _ |> std/store:insert(view) { d: s.d + 1, kind: "text", wk: 0, w: 0.0, hk: 0, h: 0.0, dir: 0, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 0, ay: 0, r: 240.0, g: 244.0, b: 252.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.hid, tx: s.tx, fs: s.fs }
                                        | row _
                            |> if (s.kind == "toggle")
                                | then |> std/store:insert(view) { d: s.d, kind: "panel", wk: 3, w: 160.0, hk: 3, h: 36.0, dir: 1, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 2, ay: 2, r: if (world.tog == 1) 60.0 else 66.0, g: if (world.tog == 1) 170.0 else 70.0, b: if (world.tog == 1) 110.0 else 78.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.hid, tx: "", fs: 0.0 }
                                    | row _ |> std/store:insert(view) { d: s.d + 1, kind: "text", wk: 0, w: 0.0, hk: 0, h: 0.0, dir: 0, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 0, ay: 0, r: 230.0, g: 234.0, b: 244.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.hid, tx: if (world.tog == 1) "toggle: on" else "toggle: off", fs: s.fs }
                                        | row _
                            |> if (s.kind == "slider")
                                | then |> std/store:insert(view) { d: s.d, kind: "panel", wk: 3, w: 200.0, hk: 3, h: 10.0, dir: 1, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 0, ay: 2, r: 60.0, g: 64.0, b: 78.0, a: 255.0, ox: 0.0, oy: 0.0, uid: s.hid, tx: "", fs: 0.0 }
                                    | row _
                    // The virtual window reads LAST frame's clip box, same
                    // contract as the hand-rolled gallery.
                    |> std/store:stored {
                        world.r0: @max(0, @as(i64, @intFromFloat(@floor(fworld.scroll / 36.0)))),
                        world.r1: @min(world.icount, @as(i64, @intFromFloat(@floor((fworld.scroll + fworld.ly1 - fworld.ly0) / 36.0))))
                    }
                    |> if (world.frame == 3 and (world.live == 0 or 3 <= world.demo))
                        | then |> libs/metal:input.scroll(x: 100.0, y: 200.0, dx: 0.0, dy: 0.0 - 200.0)
                    |> if (world.frame == 4 and (world.live == 0 or 4 <= world.demo))
                        | then |> libs/metal:input.mouse(x: 410.0, y: 128.0)
                    |> if (world.frame == 5 and (world.live == 0 or 5 <= world.demo))
                        | then |> libs/metal:input.up(x: 410.0, y: 128.0)
                    |> if (world.frame == 6 and (world.live == 0 or 6 <= world.demo))
                        | then |> libs/metal:input.mouse(x: 400.0, y: 208.0)
                    |> if (world.frame == 7 and (world.live == 0 or 7 <= world.demo))
                        | then |> libs/metal:input.up(x: 400.0, y: 208.0)
                    |> if (world.frame == 8 and (world.live == 0 or 8 <= world.demo))
                        | then |> libs/metal:input.mouse(x: 560.0, y: 80.0)
                    |> if (world.frame == 9 and (world.live == 0 or 9 <= world.demo))
                        | then |> libs/metal:input.up(x: 560.0, y: 80.0)
                    |> if (world.frame == 10 and (world.live == 0 or 10 <= world.demo))
                        | then |> libs/metal:input.mouse(x: 400.0, y: 272.0)
                    |> if (world.frame == 11 and (world.live == 0 or 11 <= world.demo))
                        | then |> libs/metal:input.drag(x: 300.0, y: 272.0)
                    |> if (world.frame == 12 and (world.live == 0 or 12 <= world.demo))
                        | then |> libs/metal:input.up(x: 300.0, y: 272.0)
                    |> if (world.frame == 13 and (world.live == 0 or 13 <= world.demo))
                        | then |> libs/metal:input.mouse(x: 150.0, y: 48.0)
                    |> if (world.frame == 14 and (world.live == 0 or 14 <= world.demo))
                        | then |> libs/metal:input.up(x: 150.0, y: 48.0)
                            |> libs/metal:input.scroll(x: 100.0, y: 200.0, dx: 0.0, dy: 0.0 - 2000.0)
                    |> if (world.frame == 16 and (world.live == 0 or 16 <= world.demo))
                        | then |> libs/metal:window.snap(path: "/tmp/gallery_comp_snap.bmp")
                    |> if (world.frame == 17 and (world.live == 0 or 17 <= world.demo))
                        | then |> libs/metal:input.mouse(x: 400.0, y: 272.0)
                    |> if (world.frame == 18 and (world.live == 0 or 18 <= world.demo))
                        | then |> libs/metal:input.drag(x: 256.0, y: 272.0)
                    |> if (world.frame == 19 and (world.live == 0 or 19 <= world.demo))
                        | then |> libs/metal:input.up(x: 256.0, y: 272.0)
                    |> if (world.frame == 28 and (world.live == 0 or 28 <= world.demo))
                        | then |> libs/metal:window.snap(path: "/tmp/gallery_comp_snap2.bmp")
                    // A named preset documents itself: two frames after the
                    // replay cutoff the layout has settled — write the snap.
                    |> if (world.demo > 0 and world.frame == world.demo + 2)
                        | then |> libs/metal:window.snap(path: "/tmp/gallery_comp_preset.bmp")
                    // EMIT — blind over view: close-to the row's depth,
                    // dispatch on the primitive kind. No state reads;
                    // expansion already baked them.
                    |> libs/clay:layout(cl: h)
                        ! tree t
                            |> std/store:query(view)
                                ! query { [row]v }
                                    |> if (v.kind == "panel")
                                        | then |> libs/clay:el.close-to(t, v.d)
                                            |> libs/ui:panelx(t, dock: "", ws: if (v.wk == 1) "star" else if (v.wk == 3) "fix" else "", v.w, hs: if (v.hk == 1) "star" else if (v.hk == 3) "fix" else "", v.h, dir: if (v.dir == 1) "ttb" else "ltr", v.gap, pad: v.padl, ax: if (v.ax == 2) "center" else if (v.ax == 1) "end" else "start", ay: if (v.ay == 2) "center" else if (v.ay == 1) "end" else "start", v.r, v.g, v.b, v.a, fl: 0, fx: 0.0, fy: 0.0, eid: v.uid)
                                    |> if (v.kind == "clip")
                                        | then |> libs/clay:el.close-to(t, v.d)
                                            |> libs/clay:el.open(t)
                                            |> libs/clay:el.clip(t, v.wk, v.w, v.hk, v.h, v.dir, v.gap, v.padl, v.padr, v.padt, v.padb, v.r, v.g, v.b, v.a, v.ox, v.oy, horiz: 0, vert: 1)
                                    |> if (v.kind == "text")
                                        | then |> libs/clay:el.close-to(t, v.d)
                                            |> libs/ui:text(t, v.tx, v.fs, v.r, v.g, v.b, v.a, eid: v.uid)
                        | solved cls |> libs/clay:each(cl: cls)
                            ! cmd rc |> if (rc.kind == 1)
                                | then |> std/store:insert(hit) { seq: rc.ud, cl: world.ic, rc.x, rc.y, rc.w, rc.h }
                                    |> libs/metal:draw.rect(f, x: @round(rc.x), y: @round(rc.y), w: @round(rc.x + rc.w) - @round(rc.x), h: @round(rc.y + rc.h) - @round(rc.y), rc.r, rc.g, rc.b, rc.a)
                                    |> if (rc.ud == world.sliderh)
                                        | then |> std/store:stored { fworld.sx: rc.x, fworld.sw: rc.w }
                                            |> libs/metal:draw.rect(f, x: @round(rc.x + fworld.slider * (rc.w - 14.0)), y: @round(rc.y - 4.0), w: 14.0, h: 18.0, r: 120.0, g: 170.0, b: 240.0, a: 255.0)
                            ! cmd rc |> if (rc.kind == 3)
                                | then |> std/store:insert(hit) { seq: rc.ud, cl: world.ic, rc.x, rc.y, rc.w, rc.h }
                                    |> libs/metal:draw.text(f, x: @round(rc.x), y: @round(rc.y), size: rc.fs, rc.r, rc.g, rc.b, rc.a, text: rc.tx)
                                    |> if (rc.ud == world.labelh)
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
                    |> if (world.frame == 30 and (world.live == 0 or 30 <= world.demo))
                        | then |> libs/metal:quit()
                ! key-down k when k.code == 53 |> libs/metal:quit()
                ! mouse-move e
                    |> std/store:stored { world.hover: -1 }
                    |> std/store:query(hit)
                        ! query hi when (hi.cl == 0 or e.y >= fworld.ly0 and e.y < fworld.ly1) and e.x >= hi.x and e.x < hi.x + hi.w and e.y >= hi.y and e.y < hi.y + hi.h
                            |> std/store:stored { world.hover: hi.seq }
                ! mouse-down e
                    |> std/store:stored { world.down: -1, world.downsk: -1 }
                    |> std/store:query(hit)
                        ! query hi when (hi.cl == 0 or e.y >= fworld.ly0 and e.y < fworld.ly1) and e.x >= hi.x and e.x < hi.x + hi.w and e.y >= hi.y and e.y < hi.y + hi.h
                            |> std/store:stored { world.down: hi.seq }
                    |> std/store:query(uids)
                        ! query u when u.uid == world.down
                            |> std/store:stored { world.downsk: 2 }
                    |> if (world.down == world.sliderh)
                        | then |> std/store:insert(cstate) { uid: 102, k: "sli", v: if (e.x < fworld.sx) 0.0 else if (e.x > fworld.sx + fworld.sw) 1.0 else (e.x - fworld.sx) / fworld.sw }
                            | row _
                ! mouse-drag e
                    |> if (world.down == world.sliderh)
                        | then |> std/store:insert(cstate) { uid: 102, k: "sli", v: if (e.x < fworld.sx) 0.0 else if (e.x > fworld.sx + fworld.sw) 1.0 else (e.x - fworld.sx) / fworld.sw }
                            | row _
                ! mouse-up e
                    |> std/store:query(hit)
                        ! query hi when (hi.cl == 0 or e.y >= fworld.ly0 and e.y < fworld.ly1) and world.down == hi.seq and e.x >= hi.x and e.x < hi.x + hi.w and e.y >= hi.y and e.y < hi.y + hi.h
                            |> if (world.down == world.buth)
                                | then |> std/store:insert(cstate) { uid: 100, k: "clk", v: @as(f64, @floatFromInt(world.clicks)) + 1.0 }
                                    | row _ |> std/store:stored { world.down: -2 }
                            |> if (world.down == world.togh)
                                | then |> std/store:insert(cstate) { uid: 101, k: "tog", v: 1.0 - @as(f64, @floatFromInt(world.tog)) }
                                    | row _ |> std/store:stored { world.down: -2 }
                            // Gamma grafts a tab mid-strip — an agent
                            // splicing a child under an existing parent
                            // mid-run. ord: 550 lands delta between
                            // alpha(500) and beta(600): inserted last,
                            // emitted second — the order: clause at work.
                            |> if (world.down == world.gammah and world.grafted == 0)
                                | then |> std/store:insert(spec) { d: 3, kind: "tab", ws: "", w: 0.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "", ay: "", r: 0.0, g: 0.0, b: 0.0, a: 0.0, n: 3, uid: 203, tx: "delta", fs: 13.0 , ord: 550, hid: 0 }
                                    | row hd |> std/store:stored { spec[hd].parent: world.strip, spec[hd].hid: hd }
                                        |> std/store:stored { world.deltah: hd, world.grafted: 1 }
                            |> if (world.down == world.alphah)
                                | then |> std/store:insert(cstate) { uid: 400, k: "tab", v: 0.0 }
                                    | row _ |> std/store:stored { world.down: -2 }
                            |> if (world.down == world.betah)
                                | then |> std/store:insert(cstate) { uid: 400, k: "tab", v: 1.0 }
                                    | row _ |> std/store:stored { world.down: -2 }
                            |> if (world.down == world.gammah)
                                | then |> std/store:insert(cstate) { uid: 400, k: "tab", v: 2.0 }
                                    | row _ |> std/store:stored { world.down: -2 }
                            |> if (world.down == world.deltah)
                                | then |> std/store:insert(cstate) { uid: 400, k: "tab", v: 3.0 }
                                    | row _ |> std/store:stored { world.down: -2 }
                            |> if (world.downsk == 2)
                                | then |> std/store:stored { world.sel: world.down }
                                    |> std/store:stored { world.down: -2 }
                    |> std/store:stored { world.down: -1, world.downsk: -1 }
                ! scroll e
                    |> if (e.x >= fworld.lx0 and e.x < fworld.lx1 and e.y >= fworld.ly0 and e.y < fworld.ly1)
                        | then |> std/store:stored { fworld.scroll: @min(@max(0.0, fworld.scroll - e.dy), @max(0.0, @as(f64, @floatFromInt(world.icount + 1)) * 36.0 + 10.0 - (fworld.ly1 - fworld.ly0))) }
                ! close |> libs/metal:quit()
                | done w2 |> libs/clay:drop(cl: h) |> libs/metal:window.close(win: w2) |> std/io:print.ln("clicks: {{ world.clicks:d }} tog: {{ world.tog:d }} tab: {{ world.tab:d }} sel: {{ world.sel:d }} scroll: {{ fworld.scroll:f }} slider: {{ fworld.slider:f }}") |> std/io:print.ln("gallery_comp: closed (snapped)")
    | err e |> std/io:print.ln("metal init failed: {{ e:s }}")
| err e3 |> std/io:print.ln("clay init failed: {{ e3:s }}")
