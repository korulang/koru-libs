// Probe — C1 shader: glyph + truecolor fg/bg (omit bg = D3 stack-friendly).
//
//   koruc run examples/shader_frag.k

import std/io
import std/store
import koru/vaxis

std/store:new(ui) { ms: 0[i64] }

koru/vaxis:shader(soft) {
    glyph = "·"
    fg = rgb(0.5 + 0.3 * sin(t), 0.4, 0.9)
}

koru/vaxis:run(title: "soft")
! draw w |> soft(win: w, t: ui.ms)
! tick ms |> std/store:stored { ui.ms: ms }
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("soft failed: {{ e:s }}")
