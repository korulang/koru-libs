// FRONTIER → positive probe — Style.fg/bg + UTF-8 meter runes (walls 1+2).
//
// Charm purple #5A56E0 / pink #EE6FF8 on ▌░ and █ blocks. q to quit.
//
//   koruc run examples/style_color.k

import std/io
import koru/vaxis

koru/vaxis:run(title: "style-color")
! draw _ |> koru/vaxis:write-styled(x: 2, y: 2, text: "▌▌▌▌░░░░", style: { fg: 0x5A56E0 })
    |> koru/vaxis:write-styled(x: 2, y: 3, text: "████░░░░", style: { fg: 0xEE6FF8, bg: 0x606060 })
    |> koru/vaxis:write-at(x: 2, y: 5, text: "q quit")
    |> koru/vaxis:render()
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
