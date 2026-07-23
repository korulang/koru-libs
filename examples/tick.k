// tick — substrate probe for `! ?tick i64` on koru/vaxis:run.
//
// COMPONENT replay 04 Frontier wall; mom/dad fixed. Presence-gated ~60 Hz
// loop when this handler is installed; apps without `! tick` stay blocking.
//
//   koruc run examples/tick.k       (q quit)

import std/io
import std/store
import koru/vaxis

std/store:new(spin) { frame: 0[i64] }

koru/vaxis:run(title: "tick-probe")
! draw _ |> koru/vaxis:write-at(x: 2, y: 2, text: "ticking — q quit")
! tick _ |> std/store:stored { spin.frame: spin.frame + 1 }
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
