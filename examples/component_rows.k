// COMPONENTS TAKE A WINDOW — placement is the caller's, not the component's.
//
// Every component now paints into a `win` it's handed (its canvas), at
// win-LOCAL coords. So the SAME component invoked twice lands in two places
// when handed two windows — the overlap-at-row-0 problem is gone. `run` hands
// the root window in via `! draw w`; `box` slices it into positioned regions.
//
//   ! draw w
//     |> box(y: 0): r0 |> todo(win: r0, label: "buy milk")
//     |> box(y: 1): r1 |> todo(win: r1, label: "walk the dog")
//
// If both rows paint on their OWN lines (not stacked on row 0), components-take
// -a-window is proven — and a `StackPanel` that computes these row-windows for
// you is the very next step.
//
//   koruc run examples/component_rows.k       (q to quit)

import std/io
import koru/vaxis

koru/vaxis:component(todo) {
    <text>{{ label:s }}</text>
}

koru/vaxis:run(title: "component rows")
! draw _ |> koru/vaxis:box(x: 2, y: 1, w: 30, h: 1, border: false): r0
    |> todo(win: r0, label: "buy milk")
    |> koru/vaxis:box(x: 2, y: 2, w: 30, h: 1, border: false): r1
    |> todo(win: r1, label: "walk the dog")
    |> koru/vaxis:box(x: 2, y: 3, w: 30, h: 1, border: false): r2
    |> todo(win: r2, label: "ship the layout engine")
    |> koru/vaxis:render()
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
