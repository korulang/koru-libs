// By-value C struct across the event boundary: `color` returns raylib's
// Color BY VALUE, the binding flows into draw calls as a value param —
// including inside the inlined ! frame body. No pointers, no obligations.

import libs/raylib
import std/io

libs/raylib:color(r: 200, g: 40, b: 40): red |> libs/raylib:window.open.hidden(width: 320, height: 200, title: "color probe")
| win w |> libs/raylib:frames(win: w, count: 1)
    ! frame f |> libs/raylib:draw.clear(f, col: red)
    | done w2 |> libs/raylib:window.close(win: w2) |> std/io:print.ln("color value crossed the boundary")
| err e |> std/io:print.ln("init failed: {{ e:s }}")
