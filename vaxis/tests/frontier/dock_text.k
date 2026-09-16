// FRONTIER — `<text>` inside `<dock>`: a status line pinned to an edge is
// painted content in the carved slice, not a component call. Same class as
// the stack-panel row fix; the dock path carves top/bottom/fill slots.

import std/io
import koru/vaxis

koru/vaxis:component(app) {
    <dock>
        <text dock="top" h="1">kopium — dock frontier</text>
        <text dock="bottom" h="1">q quit</text>
    </dock>
}

koru/vaxis:run(title: "dock-text-frontier")
! draw w |> app(win: w)
! char k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
