// A keyboard-driven counter — a small but real vaxis + store app.
//
// The value lives in a std/store. Each key writes the store; the store's
// watch fires at the write site and redraws the frame, with the count
// interpolated through std/fmt:ln into the vaxis surface. k up, j down,
// r reset, q quit.
//
//   keypress ─> store write ─> watch fires ─> fmt:ln ─> write-at ─> render
//
// Build & run (needs a real terminal):
//   koruc run examples/counter_vaxis_app.k

import std/io
import std/fmt
import std/store
import koru/vaxis

std/store:new(counter) { value: 0[i64] }

// The reaction IS the UI: every store write redraws the frame in place.
std/store:watch(counter)
! value v |> koru/vaxis:clear()
    |> koru/vaxis:write-at(x: 2, y: 2, text: "k = up   j = down   r = reset   q = quit")
    |> std/fmt:ln("value: {{ v:d }}"): l
    |> koru/vaxis:write-at(x: 2, y: 4, l.text)
    |> koru/vaxis:render()

koru/vaxis:run(title: "counter")
! draw _ |> koru/vaxis:write-at(x: 2, y: 2, text: "k = up   j = down   r = reset   q = quit")
    |> koru/vaxis:write-at(x: 2, y: 4, text: "value: 0")
    |> koru/vaxis:render()
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == 'k' |> std/store:stored { counter.value: counter.value + 1 }
! key k when k.ch == 'j' |> std/store:stored { counter.value: counter.value - 1 }
! key k when k.ch == 'r' |> std/store:stored { counter.value: 0 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
