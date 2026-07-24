// Probe — koru/vaxis:pulse fills a window from uv × time (fragment rung one).
//
//   koruc run examples/shader_pulse.k
//
// Compiles the paint substrate; eyeballs live in koru-examples/shader-toy.

import std/io
import std/store
import koru/vaxis

std/store:new(ui) { ms: 0[i64] }

koru/vaxis:run(title: "pulse")
! draw w |> koru/vaxis:pulse(win: w, t: ui.ms)
    |> koru/vaxis:write-at(x: 2, y: 0, text: "pulse — q quits")
! tick ms |> std/store:stored { ui.ms: ms }
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("pulse failed: {{ e:s }}")
