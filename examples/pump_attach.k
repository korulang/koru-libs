// Probe — named pump + attach fuse (effect-only sugar).
//
//   koruc run examples/pump_attach.k
//
// `koru/vaxis(demo)` hangs `! key` beside the run; they fuse into one `__H`.
// q quits. Join key = run title (quotes stripped) ↔ attach name.

import std/io
import koru/vaxis

koru/vaxis:run(title: "demo")
! draw _ |> koru/vaxis:write-at(x: 2, y: 2, text: "pump attach — q quits")
    |> koru/vaxis:render()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")

koru/vaxis(demo)
! key k when k.ch == 'q' |> koru/vaxis:quit()
