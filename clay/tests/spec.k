// OMNI spike S5 — layout as DATA, in the panel dialect. Each row is one
// element declared in WPF vocabulary: `kind` names the panel, `dock` is a
// child's dock slot, `ws`/`hs` are Auto|fix|star|pct words, `dir` is the
// stack orientation, `fl`+`fx`/`fy` is canvas semantics (float at a field
// position). The walk is close-to(d) + panel — the dialect lives in the
// rows, libs/ui lowers the words, libs/clay solves, Metal draws.
import libs/metal
import libs/clay
import libs/ui
import std/store
import std/io

std/store:new(world) { frame: 0[i64], drew: 0[i64] }

// One row = one element in the dialect. d: tree depth. kind: stack|leaf —
// declared intent for readers/tooling. dock: ""|top|bottom|left|right|fill
// (a dock slot derives the cross-axis sizing). ws/hs: auto|fix|star|pct.
// dir: ttb|ltr. ax/ay: start|end|center. fl: 1 = canvas — float at (fx,fy).
std/store:new(spec, capacity: 64) {
    d: i64, kind: char[8], dock: char[8],
    ws: char[8], w: f64, hs: char[8], h: f64,
    dir: char[8], gap: i64, pad: i64, ax: char[8], ay: char[8],
    r: f64, g: f64, b: f64, a: f64,
    fl: i64, fx: f64, fy: f64,
}

libs/clay:init(width: 640, height: 400)
| cl h |> libs/metal:window.open(width: 640, height: 400, title: "omni s5 — spec-driven layout")
    | win w |> libs/metal:window.clear.color(win: w, r: 0.08, g: 0.08, b: 0.11)
            |> libs/metal:frames(win: w, count: 9999)
        ! frame f
            |> std/store:stored { world.frame: world.frame + 1 }
            |> if (world.frame == 1)
                | then |> std/store:insert(spec) { d: 0, kind: "dock", dock: "", ws: "fix", w: 220.0, hs: "auto", h: 0.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 30.0, g: 32.0, b: 42.0, a: 255.0, fl: 1, fx: 60.0, fy: 70.0 }
                    | row _ |> std/store:insert(spec) { d: 1, kind: "leaf", dock: "top", ws: "", w: 0.0, hs: "fix", h: 24.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 62.0, g: 74.0, b: 96.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                        | row _ |> std/store:insert(spec) { d: 1, kind: "stack", dock: "fill", ws: "", w: 0.0, hs: "", h: 0.0, dir: "ttb", gap: 6, pad: 10, ax: "start", ay: "start", r: 24.0, g: 26.0, b: 34.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                            | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 120.0, g: 126.0, b: 142.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 96.0, g: 101.0, b: 118.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                    | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 76.0, g: 80.0, b: 96.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                        | row _ |> std/store:insert(spec) { d: 0, kind: "dock", dock: "", ws: "fix", w: 220.0, hs: "auto", h: 0.0, dir: "ttb", gap: 0, pad: 0, ax: "start", ay: "start", r: 42.0, g: 32.0, b: 28.0, a: 255.0, fl: 1, fx: 60.0, fy: 250.0 }
                                            | row _ |> std/store:insert(spec) { d: 1, kind: "leaf", dock: "top", ws: "", w: 0.0, hs: "fix", h: 24.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 104.0, g: 74.0, b: 56.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                | row _ |> std/store:insert(spec) { d: 1, kind: "stack", dock: "fill", ws: "", w: 0.0, hs: "", h: 0.0, dir: "ttb", gap: 6, pad: 10, ax: "start", ay: "start", r: 34.0, g: 26.0, b: 22.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                    | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 150.0, g: 118.0, b: 92.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                        | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "star", w: 0.0, hs: "fix", h: 8.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 118.0, g: 94.0, b: 74.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                            | row _ |> std/store:insert(spec) { d: 0, kind: "stack", dock: "", ws: "auto", w: 0.0, hs: "auto", h: 0.0, dir: "ltr", gap: 4, pad: 6, ax: "start", ay: "start", r: 20.0, g: 22.0, b: 30.0, a: 255.0, fl: 1, fx: 340.0, fy: 70.0 }
                                                                | row _ |> std/store:insert(spec) { d: 1, kind: "stack", dock: "", ws: "auto", w: 0.0, hs: "auto", h: 0.0, dir: "ttb", gap: 4, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                    | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "fix", w: 30.0, hs: "fix", h: 26.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 120.0, g: 80.0, b: 200.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                        | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "fix", w: 30.0, hs: "fix", h: 26.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 200.0, g: 150.0, b: 60.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                            | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "fix", w: 30.0, hs: "fix", h: 26.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 60.0, g: 170.0, b: 160.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                                | row _ |> std/store:insert(spec) { d: 1, kind: "stack", dock: "", ws: "auto", w: 0.0, hs: "auto", h: 0.0, dir: "ttb", gap: 4, pad: 0, ax: "start", ay: "start", r: 0.0, g: 0.0, b: 0.0, a: 0.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                                    | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "fix", w: 30.0, hs: "fix", h: 26.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 190.0, g: 80.0, b: 80.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                                        | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "fix", w: 30.0, hs: "fix", h: 26.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 80.0, g: 110.0, b: 200.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
                                                                                            | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", dock: "", ws: "fix", w: 30.0, hs: "fix", h: 26.0, dir: "", gap: 0, pad: 0, ax: "start", ay: "start", r: 90.0, g: 180.0, b: 90.0, a: 255.0, fl: 0, fx: 0.0, fy: 0.0 }
            |> libs/clay:layout(cl: h)
                ! tree t
                    |> std/store:query(spec)
                        ! query s |> libs/clay:el.close-to(t, s.d)
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
