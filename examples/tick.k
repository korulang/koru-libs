// tick — substrate probe for `! ?tick i64` on koru/vaxis:run.
//
// Frame counter advances on tick and is painted in ! draw so you can SEE it.
// Presence-gated ~60 Hz when this handler is installed.
//
//   koruc run examples/tick.k       (q quit)

import std/io
import std/fmt
import std/store
import koru/vaxis

std/store:new(spin) { frame: 0[i64] }

koru/vaxis:component(hud) {
    <text>ticking {{ frame:d }} — q quit</text>
}

koru/vaxis:run(title: "tick-probe")
! draw w |> hud(win: w, spin.frame)
! tick _ |> std/store:stored { spin.frame: spin.frame + 1 }
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
