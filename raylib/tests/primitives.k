// Vector primitives walkthrough: line, triangle-lines, circle, circle-lines.
// Exercises the float draw surface (DrawLineEx / DrawTriangleLines /
// DrawCircleV / DrawCircleLines) through the `! frame` effect branch, inside
// the same hidden-window lifecycle as basic.k.

import libs/raylib
import std/io

libs/raylib:window.open.hidden(width: 320, height: 200, title: "koru raylib primitives")
| win w |> libs/raylib:frames(win: w, count: 20)
    ! frame f |> libs/raylib:color(r: 8, g: 10, b: 14): bg |> libs/raylib:draw.clear(f, col: bg)
        |> libs/raylib:color(r: 255, g: 255, b: 255): white
        |> libs/raylib:draw.line(f, x1: 10.0, y1: 10.0, x2: 120.0, y2: 90.0, thickness: 2.0, col: white)
        |> libs/raylib:draw.triangle.lines(f, x1: 160.0, y1: 20.0, x2: 140.0, y2: 60.0, x3: 180.0, y3: 60.0, col: white)
        |> libs/raylib:draw.circle(f, x: 60.0, y: 140.0, r: 4.0, col: white)
        |> libs/raylib:draw.circle.lines(f, x: 200, y: 140, r: 30.0, col: white)
    | done w2 |> libs/raylib:window.close(win: w2) |> std/io:print.ln("primitives: drew line, triangle, circle, circle-lines")
| err e |> std/io:print.ln("raylib init failed: {{ e:s }}")