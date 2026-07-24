// MUST_FAIL probe — `|` terminal on attach (effect-only)
import std/io
import koru/vaxis

koru/vaxis:run(title: "demo")
! draw _ |> koru/vaxis:write-at(x: 0, y: 0, text: "x") |> koru/vaxis:render()
| err e |> std/io:print.ln("fail")

koru/vaxis(demo)
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("nope")
