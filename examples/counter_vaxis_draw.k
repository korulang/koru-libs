// Reactive counter that draws INTO the vaxis surface.
//
// Same composition proven by counter_vaxis.k (store <- keys, watch <- store),
// but the watch's reaction renders the count onto vaxis's managed screen with
// write-at instead of scrolling it to stdout via print.ln. One renderer owns
// the terminal, the number updates in place — no interleaved mess.
//
// Multi-step arm bodies are a single-line `|>` chain (koru pin 210_066: the
// body must be inline after `|>`; several steps sequence with more `|>`).

import std/io
import std/store
import koru/vaxis

std/store:new(counter) { clicks: 0[i64] }

// The reaction IS the UI: every store write redraws the frame.
std/store:watch(counter)
! clicks c |> koru/vaxis:clear() |> koru/vaxis:write-at(x: 2, y: 2, text: "Press any key to count. q to quit.") |> koru/vaxis:write-at(x: 2, y: 4, text: "clicked {{ c:d }} times") |> koru/vaxis:render()

koru/vaxis:run(title: "counter")
! ready |> koru/vaxis:write-at(x: 2, y: 2, text: "Press any key to count. q to quit.") |> koru/vaxis:render()
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key _ |> std/store:stored { counter.clicks: counter.clicks + 1 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
