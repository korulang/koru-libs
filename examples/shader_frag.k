// Probe — koru/vaxis:shader(name) { frag = … } synthesizes a fill event.
//
//   koruc run examples/shader_frag.k

import std/io
import std/store
import koru/vaxis

std/store:new(ui) { ms: 0[i64] }

koru/vaxis:shader(soft) {
    frag = 0.4 + 0.1 * sin(t)
}

koru/vaxis:run(title: "soft")
! draw w |> soft(win: w, t: ui.ms)
! tick ms |> std/store:stored { ui.ms: ms }
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("soft failed: {{ e:s }}")
