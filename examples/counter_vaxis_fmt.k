// Reactive counter rendered into the vaxis TUI with an interpolated string.
//
// The number lives in a std/store. A keypress writes the store; the store's
// watch fires at the write site and redraws the frame. The count is formatted
// through std/fmt:ln — the one interpolation transform — whose result binds
// mid-pipe (`: l`) and flows straight into vaxis write-at as plain bytes, so
// vaxis needs no placeholder engine of its own. write-at is a plain |zig
// wrapper: it renders l.text verbatim, already-formatted.
//
//   keypress ─> store write ─> watch fires ─> fmt:ln ─> write-at ─> render
//
// Build & run (needs a real terminal — press any key to count, q to quit):
//   koruc run examples/counter_vaxis_fmt.k

import std/io
import std/fmt
import std/store
import koru/vaxis

std/store:new(counter) { clicks: 0[i64] }

std/store:watch(counter)
! clicks c |> koru/vaxis:clear() |> koru/vaxis:write-at(x: 2, y: 2, text: "Press any key to count. q to quit.") |> std/fmt:ln("clicked {{ c:d }} times"): l |> koru/vaxis:write-at(x: 2, y: 4, l.text) |> koru/vaxis:render()

koru/vaxis:run(title: "counter")
! ready |> koru/vaxis:write-at(x: 2, y: 2, text: "Press any key to count. q to quit.") |> koru/vaxis:render()
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key _ |> std/store:stored { counter.clicks: counter.clicks + 1 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
