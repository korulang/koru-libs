// Skunkworks — box/window VALUES: composable, positioned panels.
//
// `box(…): a` returns a Window value — a positioned, sized region. Text is
// written INTO it with box-LOCAL coords, so the same (1, 2) lands in different
// screen places for different boxes. Move the box → its contents move. That's
// the retained-layout structure: regions as first-class values, not absolute
// paint calls. Bordered so the structure is visible.
//
//   koruc run examples/box_vaxis.k       (q to quit)

import std/io
import koru/vaxis

koru/vaxis:run(title: "boxes")
! draw _ |> koru/vaxis:box(x: 3, y: 1, w: 34, h: 6, border: true): a
    |> koru/vaxis:write-in(win: a, x: 1, y: 0, text: "panel A")
    |> koru/vaxis:write-in(win: a, x: 1, y: 2, text: "text at A-local (1,2)")
    |> koru/vaxis:box(x: 42, y: 9, w: 30, h: 5, border: true): b
    |> koru/vaxis:write-in(win: b, x: 1, y: 0, text: "panel B")
    |> koru/vaxis:write-in(win: b, x: 1, y: 2, text: "independent region")
    |> koru/vaxis:write-at(x: 2, y: 0, text: "q to quit")
    |> koru/vaxis:render()
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
