// FRONTIER REPRO — Charm Bubbles spinner natural shape (COMPONENT replay 04).
//
// Thesis: a reusable <spinner/> needs time-driven frame ticks so glyph
// cycling lives inside the widget boundary (or a store it owns), not in
// ! key as fake chrome.
//
// Natural consumer shape (Charm TickMsg / tea.Tick):
//   koru/vaxis:run(...)
//   ! draw w |> app(win: w, frame: spin.frame)
//   ! tick _ |> std/store:stored { spin.frame: (spin.frame + 1) % 10 }
//
// Wall: koru/vaxis:run declares only ! ?draw / ! ?key / ! ?resize /
// ! ?focus-in / ! ?focus-out. No ! tick (or timer/frame) effect branch.
// Without that substrate, Charm-class animation cannot live honestly.

import std/io
import std/store
import koru/vaxis

std/store:new(spin) { frame: 0[i64] }

koru/vaxis:component(app) {
    <stack-panel>
        <spinner frame={{ frame:d }}/>
        <text>q quit</text>
    </stack-panel>
}

koru/vaxis:run(title: "spinner-frontier")
! draw w |> app(win: w, spin.frame)
! tick _ |> std/store:stored { spin.frame: (spin.frame + 1) % 10 }
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
