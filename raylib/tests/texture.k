// Texture obligation cycle: generate a GPU texture (borrowing the OPENED
// window — before any frame has run, exercising the <opened|active> union
// borrow), draw it inside ! frame bodies, unload it exactly once, close.

import libs/raylib
import std/io

libs/raylib:window.open.hidden(width: 320, height: 200, title: "texture smoke")
| win w |> libs/raylib:color(r: 255, g: 0, b: 255): magenta |> libs/raylib:texture.gen.color(win: w, width: 4, height: 4, col: magenta)
    | tex t |> libs/raylib:frames(win: w, count: 2)
        ! frame f |> libs/raylib:color(r: 255, g: 255, b: 255): white |> libs/raylib:draw.texture(f, tex: t, x: 10, y: 10, tint: white)
        | done w2 |> libs/raylib:texture.unload(tex: t) |> libs/raylib:window.close(win: w2) |> std/io:print.ln("texture: generated, drew 2 frames, unloaded, closed")
    // DESIGN HOLE (flagged 2026-07-17, awaiting ruling): under the asymmetric
    // model an <opened!> window has NO legal exit on an error path — close
    // accepts only <!active>, so this branch runs a ceremonial zero-frame
    // `frames` to transition before closing. Candidate fix: an explicit-only
    // `window.abandon <!opened>` discharger that auto-discharge may never
    // insert (needs koru support for auto-walk exclusion).
    | err e |> libs/raylib:frames(win: w, count: 0)
        | done wx |> libs/raylib:window.close(win: wx) |> std/io:print.ln("texture failed: {{ e:s }}")
| err e2 |> std/io:print.ln("init failed: {{ e2:s }}")
