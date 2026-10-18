// OMNI spike S5 — the CSS oracle twin of spec.k. Same spec store, same
// seed rows — but instead of clay solving and Metal drawing, the walk
// emits the layout as HTML+CSS Grid and lets the browser be the
// reference rasterizer: ws/hs words map fix→px, star→Nfr, auto→auto;
// gc/gr map to grid-column/grid-row (CSS is 1-based); dir/gap/pad map
// to flex; fl+fx/fy map to position:absolute; a row carrying tx emits
// the string with font:FSpx Helvetica so WebKit measures the same
// content the Core Text metric did. Output goes to stdout —
// `./a.out > spec.html`, open, compare against the Metal render.
import std/store
import std/io

// world.dd — currently-open div depth while walking (the </div>
// analogue of clay's close-to(d)).
std/store:new(world) { dd: 0[i64] }

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
                                                            | row _ |> std/store:insert(spec) { d: 1, kind: "row", dock: "", ws: "", w: 0.0, hs: "star", h: 1.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 1, gr: 0, tx: "", fs: 0.0 }
                                                                | row _ |> std/store:insert(spec) { d: 1, kind: "row", dock: "", ws: "", w: 0.0, hs: "star", h: 1.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 2, tx: "", fs: 0.0 }
                                                                    | row _ |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "", w: 0.0, hs: "", h: 0.0, dir: "ttb", gap: 3, pad: 4, ax: "start", ay: "start", r: 120.0, g: 80.0, b: 200.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 2, pid: 1, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                                        | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "fix", w: 14.0, hs: "fix", h: 10.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 220.0, g: 220.0, b: 240.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 2, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                                            | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "fix", w: 22.0, hs: "fix", h: 6.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 60.0, g: 60.0, b: 70.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 2, gc: 0, gr: 0, tx: "", fs: 0.0 }
                                                                                | row _ |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "fix", w: 0.0, hs: "star", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 200.0, g: 150.0, b: 60.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 1, tx: "auto hugs text", fs: 12.0 }
                                                                                    | row _ |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "fix", w: 20.0, hs: "star", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 60.0, g: 170.0, b: 160.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 0, gr: 2, tx: "", fs: 0.0 }
                                                                                        | row _ |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "star", w: 0.0, hs: "fix", h: 18.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 190.0, g: 80.0, b: 80.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 1, gr: 0, tx: "", fs: 0.0 }
                                                                                            | row _ |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "star", w: 0.0, hs: "star", h: 0.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 80.0, g: 110.0, b: 200.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 1, gr: 1, tx: "", fs: 0.0 }
                                                                                                | row _ |> std/store:insert(spec) { d: 1, kind: "cell", dock: "", ws: "fix", w: 18.0, hs: "fix", h: 14.0, dir: "", gap: 0, pad: 0, ax: "center", ay: "center", r: 90.0, g: 180.0, b: 90.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0, mw: 0.0, mh: 0.0, cw: 0.0, ch: 0.0, cc: 0, id: 0, pid: 1, gc: 1, gr: 2, tx: "", fs: 0.0 }
// <style>: one grid rule per grid row — col/row def rows become the
// track templates (fix→px, star→Nfr, auto→auto). Newlines inside a
// declaration are legal CSS, so track tokens print one per line.
for(&[_]i64{ 0 })
    ! each _ |> std/io:print.ln("<html><head><meta charset='utf-8'><style>")
        |> std/io:print.ln("body { background:rgb(20,20,28); margin:0; font-family:Helvetica; }")
        |> std/store:query(spec)
            ! query g when g.kind == "grid"
                |> std/io:print.ln("#g{{ g.id:d }} { display:grid; position:absolute; left:{{ g.fx:d }}px; top:{{ g.fy:d }}px; width:{{ g.w:d }}px; height:{{ g.h:d }}px; gap:{{ g.gap:d }}px; padding:{{ g.pad:d }}px; background:rgb({{ g.r:d }},{{ g.g:d }},{{ g.b:d }});")
                |> std/io:print.ln("  grid-template-columns:")
                |> std/store:query(spec)
                    ! query c when c.pid == g.id and c.kind == "col"
                        |> if (c.ws == "auto")
                            | then |> std/io:print.ln("    auto")
                        |> if (c.ws == "star")
                            | then |> std/io:print.ln("    {{ c.w:d }}fr")
                        |> if (c.ws != "auto" and c.ws != "star")
                            | then |> std/io:print.ln("    {{ c.w:d }}px")
                |> std/io:print.ln("  ; grid-template-rows:")
                |> std/store:query(spec)
                    ! query c when c.pid == g.id and c.kind == "row"
                        |> if (c.hs == "auto")
                            | then |> std/io:print.ln("    auto")
                        |> if (c.hs == "star")
                            | then |> std/io:print.ln("    {{ c.h:d }}fr")
                        |> if (c.hs != "auto" and c.hs != "star")
                            | then |> std/io:print.ln("    {{ c.h:d }}px")
                |> std/io:print.ln("  ; }")
        |> std/io:print.ln("</style></head><body>")
// <body>: skip track defs (consumed into the style rules), close divs
// to the row's depth — the </div> analogue of close-to(d) — then emit.
        |> std/store:query(spec)
            ! query s when s.kind != "col" and s.kind != "row"
                |> for(0..@as(usize, @intCast(world.dd - s.d)))
                    ! each _ |> std/io:print.ln("</div>")
                |> std/store:stored { world.dd: s.d + 1 }
                |> if (s.kind == "dock")
                    | then |> std/io:print.ln("<div style='position:absolute; left:{{ s.fx:d }}px; top:{{ s.fy:d }}px; width:{{ s.w:d }}px; display:flex; flex-direction:column; background:rgb({{ s.r:d }},{{ s.g:d }},{{ s.b:d }})'>")
                |> if (s.kind == "grid")
                    | then |> std/io:print.ln("<div id='g{{ s.id:d }}'>")
                |> if (s.kind == "cell")
                    | then |> std/io:print("<div style='grid-column:{{ s.gc + 1:d }}; grid-row:{{ s.gr + 1:d }}; background:rgb({{ s.r:d }},{{ s.g:d }},{{ s.b:d }});")
                        |> if (s.dir == "ttb")
                            | then |> std/io:print(" display:flex; flex-direction:column; gap:{{ s.gap:d }}px; padding:{{ s.pad:d }}px;")
                        |> if (s.ws == "fix" and s.w != 0.0)
                            | then |> std/io:print(" width:{{ s.w:d }}px; justify-self:start;")
                        |> if (s.hs == "fix" and s.h != 0.0)
                            | then |> std/io:print(" height:{{ s.h:d }}px; align-self:start;")
                        |> if (s.ax == "center")
                            | then |> std/io:print(" justify-self:center;")
                        |> if (s.ay == "center")
                            | then |> std/io:print(" align-self:center;")
                        |> if (s.tx != "")
                            | then |> std/io:print(" font:{{ s.fs:d }}px Helvetica; color:rgb(230,230,235); width:max-content;")
                        |> std/io:print("'>")
                        |> if (s.tx != "")
                            | then |> std/io:print("{{ s.tx:s }}")
                        |> std/io:print.ln("")
                |> if (s.kind == "stack")
                    | then |> std/io:print.ln("<div style='display:flex; flex-direction:column; gap:{{ s.gap:d }}px; padding:{{ s.pad:d }}px; flex:1; background:rgb({{ s.r:d }},{{ s.g:d }},{{ s.b:d }})'>")
                |> if (s.kind != "dock" and s.kind != "grid" and s.kind != "cell" and s.kind != "stack")
                    | then |> std/io:print("<div style='background:rgb({{ s.r:d }},{{ s.g:d }},{{ s.b:d }});")
                        |> if (s.hs == "fix" and s.h != 0.0)
                            | then |> std/io:print(" height:{{ s.h:d }}px;")
                        |> if (s.ws == "fix" and s.w != 0.0)
                            | then |> std/io:print(" width:{{ s.w:d }}px;")
                        |> if (s.tx != "")
                            | then |> std/io:print(" font:{{ s.fs:d }}px Helvetica; color:rgb(230,230,235); width:max-content;")
                        |> std/io:print("'>")
                        |> if (s.tx != "")
                            | then |> std/io:print("{{ s.tx:s }}")
                        |> std/io:print.ln("")
        |> for(0..@as(usize, @intCast(world.dd)))
            ! each _ |> std/io:print.ln("</div>")
        |> std/io:print.ln("</body></html>")
