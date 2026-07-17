// Walking skeleton: open a hidden window, run 3 frames through the `! frame`
// effect branch (clear + text each frame), close. Asymmetric lifecycle:
// window.open.hidden grants <opened!>, frames consumes it and re-mints
// <active!> through `| done`, window.close accepts only <!active>. The frame
// handle is a per-frame borrow that cannot escape the frame body.

import libs/raylib
import std/io

libs/raylib:window.open.hidden(width: 320, height: 200, title: "koru raylib smoke")
| win w |> libs/raylib:frames(win: w, count: 3)
    ! frame f |> libs/raylib:color(r: 30, g: 30, b: 30): bg |> libs/raylib:draw.clear(f, col: bg) |> libs/raylib:color(r: 255, g: 255, b: 255): white |> libs/raylib:draw.text(f, text: "koru", x: 10, y: 10, size: 20, col: white)
    | done w2 |> libs/raylib:window.close(win: w2) |> std/io:print.ln("raylib: opened hidden, ran 3 frames, closed")
| err e |> std/io:print.ln("raylib init failed: {{ e:s }}")
