// FRONTIER REPRO — Charm Bubbles spinner natural shape (COMPONENT replay 04).
//
// The natural Charm consumer: `<spinner/>` + `<text>` inside a stack-panel,
// glyph cycling living inside the widget boundary (ms interval), `! tick`
// pulses driving repaint. Every wall this file once hit is now closed:
//
//   `! ?tick i64` on run            — shipped (pulses + repaint)
//   `koru/vaxis:spinner { win, ms }` — shipped (MiniDot, own frame clock)
//   `<text>` inside `<stack-panel>`  — a painted row, not a component call
//     (was KORU040 `<consumer>:text` — the inner walk lacked the text branch)
//
//   koruc run tests/frontier/charm_spinner_natural.k   (q quit)

import std/io
import std/store
import koru/vaxis

std/store:new(spin) { ms: 0[i64] }

koru/vaxis:component(app) {
    <stack-panel>
        <spinner ms={{ ms:d }}/>
        <text>q quit</text>
    </stack-panel>
}

koru/vaxis:run(title: "spinner-frontier")
! draw w |> app(win: w, spin.ms)
! tick ms |> std/store:stored { spin.ms: ms }
! char k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
