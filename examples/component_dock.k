// <Dock> — the second LAYOUT CONTAINER, and the one that earns its keep: it can
// PIN a child to the bottom edge of the screen without any manual math. Each
// child declares an edge + height (dock="top"/"bottom", h="N"); a fill child
// takes the middle band. The container computes every slot from the running
// top/bottom bands PLUS the parent's runtime height — so the bottom bar stays
// glued to the last row and the body grows/shrinks as the terminal resizes.
//
//   component(app) {
//       <Dock>
//           <topbar    dock="top"    h="1"/>  → sub(win, y:0, h:1): r0 |> topbar(win: r0)
//           <statusbar dock="bottom" h="1"/>  → sub-from-bottom(win, up:1, h:1): r1 |> statusbar(win: r1)
//           <body      dock="fill"/>          → sub-fill(win, top:1, bottom:1): r2 |> body(win: r2)
//       </Dock>
//   }
//
// Top rows are pure comptime offsets (like StackPanel); the bottom edge and the
// fill height are the only runtime reads (parent.height), because those are the
// one thing that can't be folded — the terminal resizes. Survives resize because
// `! draw` repaints. `q` to quit.
//
//   koruc run examples/component_dock.k

import std/io
import koru/vaxis

koru/vaxis:component(topbar) {
    <text>{{ title:s }}</text>
}

koru/vaxis:component(statusbar) {
    <text>{{ hint:s }}</text>
}

koru/vaxis:component(body) {
    <text>{{ msg:s }}</text>
}

koru/vaxis:component(app) {
    <Dock>
        <topbar dock="top" h="1" title="== koru dock =="/>
        <statusbar dock="bottom" h="1" hint="q to quit  |  status pinned to the bottom row"/>
        <body dock="fill" msg="the body fills the middle band and resizes with the terminal"/>
    </Dock>
}

koru/vaxis:run(title: "dock")
! draw w |> app(win: w)
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
