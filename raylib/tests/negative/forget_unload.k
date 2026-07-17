// NEGATIVE TEST — must NOT compile with --auto-discharge=disable.
//
// A texture is generated and drawn but never unloaded — in raw raylib that
// is a silent VRAM leak. Here <loaded!> is symmetric (see index.kz texture
// section for why the asymmetric model does not fit textures):
//
//   - Default: auto-discharge inserts the unique discharger texture.unload.
//   - Strict:  koruc run raylib/tests/negative/forget_unload.k --auto-discharge=disable
//     -> KORU030 naming libs.raylib:texture.unload

import libs/raylib
import std/io

libs/raylib:window.open.hidden(width: 320, height: 200, title: "leak vram")
| win w |> libs/raylib:color(r: 0, g: 255, b: 0): green |> libs/raylib:texture.gen.color(win: w, width: 4, height: 4, col: green)
    | tex t |> libs/raylib:frames(win: w, count: 1)
        ! frame f |> libs/raylib:draw.texture(f, tex: t, x: 0, y: 0, tint: green)
        | done w2 |> libs/raylib:window.close(win: w2) |> std/io:print.ln("BUG: reached here without unloading t")
    // Zero-frame ceremony: see texture.k's DESIGN HOLE note (opened has no
    // legal error-path exit under the asymmetric model, pending ruling).
    | err e |> libs/raylib:frames(win: w, count: 0)
        | done wx |> libs/raylib:window.close(win: wx) |> std/io:print.ln("texture failed: {{ e:s }}")
| err e2 |> std/io:print.ln("init failed: {{ e2:s }}")
