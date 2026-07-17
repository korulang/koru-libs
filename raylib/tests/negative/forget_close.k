// NEGATIVE TEST — must NOT compile with --auto-discharge=disable.
//
// It opens a window, runs frames, and never calls window.close. In raw
// raylib C that leaks the window / GL context. In Koru the window can NEVER
// leak, in either mode:
//
//   - Default: auto-discharge sees exactly ONE discharger for <active!>
//     (window.close) and inserts it at flow end — the program compiles and
//     the window is closed for you.
//   - Strict:  koruc run raylib/tests/negative/forget_close.k --auto-discharge=disable
//     -> KORU030 naming libs.raylib:window.close
//
// (Contrast open_never_used.k: an <opened!> window that never rendered has
// NO discharge path and fails in BOTH modes — the asymmetric model.)
//
// (Same convention as ai/tests/negative/forgotten_free.kz. Contrast evp's
// forget_finalize.kz, which fails even under defaults: <hashing!> has TWO
// dischargers — final.hex / final.bytes — so auto-discharge cannot pick.)

import libs/raylib
import std/io

libs/raylib:window.open.hidden(width: 320, height: 200, title: "leak")
| win w |> libs/raylib:frames(win: w, count: 1)
    ! frame f |> libs/raylib:draw.clear(f, r: 0, g: 0, b: 0)
    | done w2 |> std/io:print.ln("BUG: reached here without closing w2")
| err e |> std/io:print.ln("init failed: {{ e:s }}")
