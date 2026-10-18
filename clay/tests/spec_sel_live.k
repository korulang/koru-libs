// OMNI spike S5b-LIVE — spec_sel.k with the scripted drivers removed:
// no snap frames, no auto-select/deselect, no auto-quit. Selection is
// only the live path — Tab (code 48) cycles sel through the spec
// ordinals, a mouse click hits the row whose rect contains the point
// (chrome clicks swallowed), Escape quits. Same stores, fold, chrome.
//
//   world.sel      the selected row's ORDINAL (-1 = none). Ordinal, not a
//                  branded handle: value stores are scalar-only, so the
//                  handle can't live here — ref(Spec) wants a proto-seeded
//                  spec store (a follow-up gap, not worked around).
//   world.selkind  the kind code cached at selection time (dock 1, leaf 2,
//                  stack 3, grid 4, col/row 5, cell 7, none 0) — one spec
//                  scan per CHANGE, never per frame.
//   tools.px       the slide x, denormalized onto every chrome row
//                  (lerped 660 offscreen → 496 docked each frame; chips
//                  read tl.px + tl.cx, no cross-row lookup). The slide IS
//                  the "lerp between arrangements" claim, as store math.
//   world.dirty    set by every sel writer; one refresh site — here only
//                  Tab (code 48) cycles sel through the spec ordinals,
//                  Escape quits.
//
// `tools` is chrome: a palette backdrop plus kind-keyed chips, all fl:1 —
// they float over the spec and never enter the fold. `tk` names the kind
// code a chip serves (-1 = the palette itself, always vis); `cx`/`cy` are
// its two-column offsets inside the palette. Chips ride the slide via
// fx = px + cx.
//
// Verification is manual: Tab cycles, click selects topmost-under-point,
// click on empty space or chrome deselects — palette slides, chips rekey,
// the element tints. The scripted sibling spec_sel.k pins pixel snaps.
//
import libs/metal
import libs/clay
import libs/ui
import std/store
import std/io

std/store:new(world) { frame: 0[i64], drew: 0[i64], sel: -1[i64], selkind: 0[i64], dirty: 0[i64], cmdi: 0[i64], hitool: 0[i64] }
// wins carries the LIVE window size in points (world is i64-only — value
// stores are single-scalar-type). Updated every frame from window.size;
// hit rows flip y against wins.h, the palette docks to wins.w.
std/store:new(wins) { w: 640.0[f64], h: 400.0[f64] }

// One row = one element in the dialect. d: tree depth. kind: stack|leaf|
// grid|cell|col|row. dock: ""|top|bottom|left|right|fill (a dock slot
// derives the cross-axis sizing). ws/hs: auto|fix|star|pct. dir: ttb|ltr.
// ax/ay: start|end|center. fl: 1 = canvas — float at (fx,fy).
// id/pid: dialect-level grid membership (a member's pid names its grid's
// id) — unchanged from the flat twin. The child→parent fold edge is the
// store's own [tree]-synthesized `parent` self-FK instead: seeded via
// handle stamps below and read back as the row's projected `s.parent`.
// gc/gr: the cell's column/row track index; defs declare theirs in gc/gr
// too. mw/mh + cw/ch/cc are the measure pass's scratch — natural size and
// child accumulators.
[tree]std/store:new(spec, capacity: 64) {
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

// Tool chrome — the adaptive surface. One palette backdrop (tk -1)
// plus chips keyed by the selected element's kind code in tk; cx/cy place
// each chip inside the palette's two columns (cx 10 or 74, cy steps of 30).
// vis is rewritten only when world.dirty fires — the surface recomputes on
// selection change, not per frame.
std/store:new(tools, capacity: 32) {
    ws: char[8], w: f64, hs: char[8], h: f64,
    dir: char[8], gap: i64, pad: i64, ax: char[8], ay: char[8],
    r: f64, g: f64, b: f64, a: f64,
    tk: i64, cx: f64, cy: f64, px: f64, vis: i64,
}
// Hit map — one row per RECTANGLE command drained this frame, recorded in
// WINDOW coordinates. Clay rects live in the pinned 640x400 layout space
// and the shader stretches that space to fill the drawable (vp_w/vp_h are
// fixed at open — NDC maps layout px straight onto the whole framebuffer),
// so window-space rect = layout rect scaled by win/layout, then y flipped
// (locationInWindow is bottom-up, layout is top-down). seq is the running
// rect index; spec emits
// first, so seq < 25 is a spec row (25 = the seed block's insert count)
// and seq >= 25 is chrome. Cleared and re-recorded every frame — mailbox
// drains before ! frame, so mouse arms always see a complete table.
std/store:new(hit, capacity: 64) { seq: i64, tool: i64, x: f64, y: f64, w: f64, h: f64 }
libs/clay:init(width: 640, height: 400)
| cl h |> libs/metal:window.open(width: 640, height: 400, title: "omni s5 — spec-driven layout")
    | win w |> libs/metal:window.clear.color(win: w, r: 0.08, g: 0.08, b: 0.11)
            |> libs/metal:frames(win: w, count: 9999)
        ! frame f
            |> std/store:stored { world.frame: world.frame + 1, world.cmdi: 0 }
            |> std/store:clear(hit)
            |> libs/metal:window.size(win: w): wh
            |> std/store:stored { wins.w: wh.w, wins.h: wh.h }
            |> libs/clay:dims(cl: h, width: wh.w, height: wh.h)
            // Selection drivers: Tab and click are the only writers.
            // Every writer sets dirty — the refresh below is the single
            // site, same shape as the scripted sibling.
            |> if (world.dirty == 1)
                | then |> std/store:stored { world.dirty: 0 }
                    |> std/store:stored { world.selkind: 0 }
                    |> std/store:query(spec)
                        ! query { [row]s, [ordinal]o }
                            |> if (o == world.sel)
                                | then |> std/store:stored { world.selkind: if (s.kind == "dock") 1 else if (s.kind == "leaf") 2 else if (s.kind == "stack") 3 else if (s.kind == "grid") 4 else if (s.kind == "cell") 7 else 5 }
                    |> std/store:query(tools)
                        ! query tl
                            |> std/store:stored { tl.vis: if (tl.tk == world.selkind or tl.tk == -1) 1 else 0 }
            |> std/store:query(tools)
                        ! query tl
                            |> std/store:stored { tl.px: tl.px + ((if (world.sel != -1) wins.w - 144.0 else wins.w + 20.0) - tl.px) * 0.22 }
            |> if (world.frame == 1)
                | then |> std/store:insert(spec) { d: 0, kind: "dock", dock: "", ws: "fix", w: 220.0, hs: "auto", h: 0.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 30.0, g: 32.0, b: 42.0, a: 255.0, fl: 1, fx: 60.0, fy: 70.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                    | row h0 |> std/store:insert(spec) { d: 1, kind: "leaf", dock: "top", ws: "", w: 0.0, hs: "fix", h: 24.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 62.0, g: 74.0, b: 96.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                        | row h1 |> std/store:insert(spec) { d: 1, kind: "stack", dock: "fill", ws: "", w: 0.0, hs: "", h: 0.0, dir: "ttb", gap: 6, pad: 10, ax: "start", ay: "start", r: 24.0, g: 26.0, b: 34.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                            | row h2 |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 120.0, g: 126.0, b: 142.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                | row h3 |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 96.0, g: 101.0, b: 118.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                    | row h4 |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 76.0, g: 80.0, b: 96.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                        | row h5 |> std/store:insert(spec) { d: 0, kind: "dock", dock: "", ws: "fix", w: 220.0, hs: "auto", h: 0.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 42.0, g: 32.0, b: 28.0, a: 255.0, fl: 1, fx: 60.0, fy: 250.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                            | row h6 |> std/store:insert(spec) { d: 1, kind: "leaf", dock: "top", ws: "", w: 0.0, hs: "fix", h: 24.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 104.0, g: 74.0, b: 56.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                | row h7 |> std/store:insert(spec) { d: 1, kind: "stack", dock: "fill", ws: "", w: 0.0, hs: "", h: 0.0, dir: "ttb", gap: 6, pad: 10, ax: "start", ay: "start", r: 34.0, g: 26.0, b: 22.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                    | row h8 |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 150.0, g: 118.0, b: 92.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                        | row h9 |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 118.0, g: 94.0, b: 74.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                            | row h10 |> std/store:insert(spec) { d: 0, kind: "grid", dock: "", ws: "fix", w: 170.0, hs: "fix", h: 98.0, dir: "", gap: 4, pad: 6, ax: "start", ay: "start", r: 20.0, g: 22.0, b: 30.0, a: 255.0, fl: 1, fx: 340.0, fy: 70.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 1, pid: 0, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                                | row h11 |> std/store:insert(spec) { d: 1, kind: "col", dock: "", ws: "auto", w: 0.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                                    | row h12 |> std/store:insert(spec) { d: 1, kind: "col", dock: "", ws: "star", w: 1.0, hs: "", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 1, gr: 0, tx: "", fs: 0.0 }
                                                                        | row h13 |> std/store:insert(spec) { d: 1, kind: "row", dock: "", ws: "", w: 0.0, hs: "auto", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                                            | row h14 |> std/store:insert(spec) { d: 1, kind: "row", dock: "", ws: "", w: 0.0, hs: "star", h: 1.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 1, tx: "", fs: 0.0 }
                                                                                | row h15 |> std/store:insert(spec) { d: 1, kind: "row", dock: "", ws: "", w: 0.0, hs: "star", h: 1.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 2, tx: "", fs: 0.0 }
                                                                                    | row h16 |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "", w: 0.0, hs: "", h: 0.0, dir: "ttb", gap: 3, pad: 4, ax: "start", ay: "start", r: 120.0, g: 80.0, b: 200.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 2, pid: 1, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                                                        | row h17 |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "fix", w: 14.0, hs: "fix", h: 10.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 220.0, g: 220.0, b: 240.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 2, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                                                            | row h18 |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "fix", w: 22.0, hs: "fix", h: 6.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 60.0, g: 60.0, b: 70.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 2, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                                                                | row h19 |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "fix", w: 0.0, hs: "star", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 200.0, g: 150.0, b: 60.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 1, tx: "auto hugs text", fs: 12.0 }
                                                                                                    | row h20 |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "fix", w: 20.0, hs: "star", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 60.0, g: 170.0, b: 160.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 2, tx: "", fs: 0.0 }
                                                                                                        | row h21 |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "star", w: 0.0, hs: "fix", h: 18.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 190.0, g: 80.0, b: 80.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 1, gr: 0, tx: "", fs: 0.0 }
                                                                                                            | row h22 |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "star", w: 0.0, hs: "star", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 80.0, g: 110.0, b: 200.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 1, gr: 1, tx: "", fs: 0.0 }
                                                                                                                | row h23 |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "fix", w: 18.0, hs: "fix", h: 14.0, dir: "", gap: 0, pad: 0, ax: "center", ay: "center", r: 90.0, g: 180.0, b: 90.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 1, gr: 2, tx: "", fs: 0.0 }
                                                                                                                    | row h24 |> std/store:stored { spec[h1].parent: h0 }
                                                                                                                        |> std/store:stored { spec[h2].parent: h0 }
                                                                                                                        |> std/store:stored { spec[h3].parent: h2 }
                                                                                                                        |> std/store:stored { spec[h4].parent: h2 }
                                                                                                                        |> std/store:stored { spec[h5].parent: h2 }
                                                                                                                        |> std/store:stored { spec[h7].parent: h6 }
                                                                                                                        |> std/store:stored { spec[h8].parent: h6 }
                                                                                                                        |> std/store:stored { spec[h9].parent: h8 }
                                                                                                                        |> std/store:stored { spec[h10].parent: h8 }
                                                                                                                        |> std/store:stored { spec[h12].parent: h11 }
                                                                                                                        |> std/store:stored { spec[h13].parent: h11 }
                                                                                                                        |> std/store:stored { spec[h14].parent: h11 }
                                                                                                                        |> std/store:stored { spec[h15].parent: h11 }
                                                                                                                        |> std/store:stored { spec[h16].parent: h11 }
                                                                                                                        |> std/store:stored { spec[h17].parent: h11 }
                                                                                                                        |> std/store:stored { spec[h18].parent: h17 }
                                                                                                                        |> std/store:stored { spec[h19].parent: h17 }
                                                                                                                        |> std/store:stored { spec[h20].parent: h11 }
                                                                                                                        |> std/store:stored { spec[h21].parent: h11 }
                                                                                                                        |> std/store:stored { spec[h22].parent: h11 }
                                                                                                                        |> std/store:stored { spec[h23].parent: h11 }
                                                                                                                        |> std/store:stored { spec[h24].parent: h11 }
            // Tool chrome seed — the palette backdrop plus two-column chip
            // sets per kind code (leaf 2 ×4, stack 3 ×2, grid 4 ×2, track
            // 5 ×2 for col/row defs, cell 7 ×4, dock 1 ×1). Chips seed
            // vis: 0 — nothing shows until a selection lands.
            |> if (world.frame == 1)
                | then |> std/store:insert(tools) { ws: "fix", w: 140.0, hs: "fix", h: 140.0, dir: "ttb", gap: 6, pad: 8, ax: "start", ay: "start", r: 16.0, g: 18.0, b: 24.0, a: 235.0, tk: -1, cx: 0.0, cy: 0.0, px: 660.0, vis: 1 }
                    | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 70.0, g: 140.0, b: 220.0, a: 255.0, tk: 2, cx: 10.0, cy: 12.0, px: 660.0, vis: 0 }
                        | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 50.0, g: 110.0, b: 180.0, a: 255.0, tk: 2, cx: 74.0, cy: 12.0, px: 660.0, vis: 0 }
                            | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 120.0, g: 170.0, b: 240.0, a: 255.0, tk: 2, cx: 10.0, cy: 42.0, px: 660.0, vis: 0 }
                                | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 40.0, g: 80.0, b: 140.0, a: 255.0, tk: 2, cx: 74.0, cy: 42.0, px: 660.0, vis: 0 }
                                    | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 60.0, g: 160.0, b: 110.0, a: 255.0, tk: 3, cx: 10.0, cy: 12.0, px: 660.0, vis: 0 }
                                        | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 40.0, g: 120.0, b: 80.0, a: 255.0, tk: 3, cx: 74.0, cy: 12.0, px: 660.0, vis: 0 }
                                            | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 40.0, g: 170.0, b: 190.0, a: 255.0, tk: 4, cx: 10.0, cy: 12.0, px: 660.0, vis: 0 }
                                                | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 30.0, g: 120.0, b: 150.0, a: 255.0, tk: 4, cx: 74.0, cy: 12.0, px: 660.0, vis: 0 }
                                                    | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 200.0, g: 160.0, b: 70.0, a: 255.0, tk: 5, cx: 10.0, cy: 12.0, px: 660.0, vis: 0 }
                                                        | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 160.0, g: 120.0, b: 50.0, a: 255.0, tk: 5, cx: 74.0, cy: 12.0, px: 660.0, vis: 0 }
                                                            | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 150.0, g: 90.0, b: 220.0, a: 255.0, tk: 7, cx: 10.0, cy: 12.0, px: 660.0, vis: 0 }
                                                                | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 120.0, g: 70.0, b: 180.0, a: 255.0, tk: 7, cx: 74.0, cy: 12.0, px: 660.0, vis: 0 }
                                                                    | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 180.0, g: 120.0, b: 240.0, a: 255.0, tk: 7, cx: 10.0, cy: 42.0, px: 660.0, vis: 0 }
                                                                        | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 90.0, g: 50.0, b: 150.0, a: 255.0, tk: 7, cx: 74.0, cy: 42.0, px: 660.0, vis: 0 }
                                                                            | row _ |> std/store:insert(tools) { ws: "fix", w: 56.0, hs: "fix", h: 24.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 90.0, g: 100.0, b: 120.0, a: 255.0, tk: 1, cx: 10.0, cy: 12.0, px: 660.0, vis: 0 }
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
                    ! query { [row]s } when s.d == lv
                        |> if (s.parent != -1)
                            | then |> std/store:stored { s.mw: if (s.ws == "fix") s.w else if (s.cc == 0) 0.0 else if (s.dir == "ttb") s.cw + @as(f64, @floatFromInt(s.pad)) * 2.0 else s.cw - @as(f64, @floatFromInt(s.gap)) + @as(f64, @floatFromInt(s.pad)) * 2.0, s.mh: if (s.hs == "fix") s.h else if (s.cc == 0) 0.0 else if (s.dir == "ttb") s.ch - @as(f64, @floatFromInt(s.gap)) + @as(f64, @floatFromInt(s.pad)) * 2.0 else s.ch + @as(f64, @floatFromInt(s.pad)) * 2.0 }
                    |> std/store:query(spec)
                        ! query { [row]s } when s.d == lv
                            |> if (s.parent != -1)
                                | then |> if (spec[s.parent].dir == "ttb")
                                    | then |> std/store:stored { spec[s.parent].cc: spec[s.parent].cc + 1, spec[s.parent].cw: if (s.mw > spec[s.parent].cw) s.mw else spec[s.parent].cw, spec[s.parent].ch: spec[s.parent].ch + s.mh + @as(f64, @floatFromInt(spec[s.parent].gap)) }
                                    | else |> std/store:stored { spec[s.parent].cc: spec[s.parent].cc + 1, spec[s.parent].cw: spec[s.parent].cw + s.mw + @as(f64, @floatFromInt(spec[s.parent].gap)), spec[s.parent].ch: if (s.mh > spec[s.parent].ch) s.mh else spec[s.parent].ch }
            |> libs/clay:layout(cl: h)
                ! tree t
                    |> std/store:clear(gtrk)
                    |> std/store:query(spec)
                        ! query { [row]s, [ordinal]o }
                            |> if (s.kind == "grid")
                                | then |> libs/clay:el.close-to(t, s.d)
                                    |> libs/ui:panel(t, s.dock, s.ws, s.w, s.hs, s.h, s.dir, s.gap, s.pad, s.ax, s.ay, r: s.r + (if (o == world.sel) @as(f64, 90.0) else @as(f64, 0.0)), g: s.g + (if (o == world.sel) @as(f64, 90.0) else @as(f64, 0.0)), s.b, s.a, s.fl, s.fx, s.fy)
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
                                                |> libs/ui:panel(t, dock: "", ws: "fix", w: if (s.ws == "fix") s.w else tc.size, hs: "fix", h: if (s.hs == "fix") s.h else tr.size, s.dir, s.gap, s.pad, s.ax, s.ay, r: s.r + (if (o == world.sel) @as(f64, 90.0) else @as(f64, 0.0)), g: s.g + (if (o == world.sel) @as(f64, 90.0) else @as(f64, 0.0)), s.b, s.a, fl: 1, fx: tc.off + if (s.ax == "center") (tc.size - (if (s.ws == "fix") s.w else tc.size)) / 2.0 else if (s.ax == "end") tc.size - (if (s.ws == "fix") s.w else tc.size) else 0.0, fy: tr.off + if (s.ay == "center") (tr.size - (if (s.hs == "fix") s.h else tr.size)) / 2.0 else if (s.ay == "end") tr.size - (if (s.hs == "fix") s.h else tr.size) else 0.0)
                            |> if (s.kind != "grid" and s.kind != "cell" and s.kind != "col" and s.kind != "row")
                                | then |> libs/clay:el.close-to(t, s.d)
                                    |> libs/ui:panel(t, s.dock, s.ws, s.w, s.hs, s.h, s.dir, s.gap, s.pad, s.ax, s.ay, r: s.r + (if (o == world.sel) @as(f64, 90.0) else @as(f64, 0.0)), g: s.g + (if (o == world.sel) @as(f64, 90.0) else @as(f64, 0.0)), s.b, s.a, s.fl, s.fx, s.fy)
                    // Tool chrome emit — every visible tools row is a root-
                    // floating element; chips ride the slide via px + cx.
                    // Emitted after the spec sweep so chrome draws on top.
                    |> std/store:query(tools)
                        ! query tl when tl.vis == 1
                            |> libs/clay:el.close-to(t, d: 0)
                            |> libs/ui:panel(t, dock: "", tl.ws, tl.w, tl.hs, tl.h, tl.dir, tl.gap, tl.pad, tl.ax, tl.ay, tl.r, tl.g, tl.b, tl.a, fl: 1, fx: tl.px + tl.cx, fy: 70.0 + tl.cy)
                | solved cls |> libs/clay:each(cl: cls)
                    ! cmd rc |> if (rc.kind == 1)
                        | then |> std/store:insert(hit) { seq: world.cmdi, tool: if (world.cmdi < 25) 0 else 1, rc.x, y: wins.h - rc.y - rc.h, rc.w, rc.h }
                            |> std/store:stored { world.cmdi: world.cmdi + 1 }
                            // Quantize to the pixel grid — edges, not sizes:
                            // x/w round independently so a box's left AND
                            // right both snap instead of the box breathing.
                            |> libs/metal:draw.rect(f, x: @round(rc.x), y: @round(rc.y), w: @round(rc.x + rc.w) - @round(rc.x), h: @round(rc.y + rc.h) - @round(rc.y), rc.r, rc.g, rc.b, rc.a)
                    | drained |> std/store:stored { world.drew: 1 }
        ! key-down k when k.code == 48
            |> std/store:stored { world.sel: if (world.sel >= 24) 0 else world.sel + 1, world.dirty: 1 }
        ! mouse-down e  // chrome pass first (palette click swallowed via
                        // hitool); spec pass takes the LAST match — later
                        // draws sit on top
            |> std/store:stored { world.sel: -1, world.hitool: 0 }
            |> std/store:query(hit)
                ! query hi when hi.tool == 1 and e.x >= hi.x and e.x < hi.x + hi.w and e.y >= hi.y and e.y < hi.y + hi.h
                    |> std/store:stored { world.hitool: 1 }
            |> std/store:query(hit)
                ! query hi when hi.tool == 0 and world.hitool == 0 and e.x >= hi.x and e.x < hi.x + hi.w and e.y >= hi.y and e.y < hi.y + hi.h
                    |> std/store:stored { world.sel: hi.seq }
            |> std/store:stored { world.dirty: 1 }
        ! key-down k when k.code == 53 |> libs/metal:quit()
        ! close |> libs/metal:quit()
        | done w2 |> libs/clay:drop(cl: h) |> libs/metal:window.close(win: w2) |> std/io:print.ln("spec: closed (snapped)")
    | err e |> std/io:print.ln("metal init failed: {{ e:s }}")
| err e2 |> std/io:print.ln("clay init failed: {{ e2:s }}")
