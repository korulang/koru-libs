// Skunkworks — vaxis styling (option B: a reusable Style value).
//
// Boolean attrs + packed RGB fg/bg (0xRRGGBB; 0 = default). See also
// examples/style_color.k for Charm-ish meter runes + color.
//
//   koruc run examples/style_vaxis.k       (q to quit)

import std/io
import koru/vaxis

koru/vaxis:run(title: "styles")
! draw _ |> koru/vaxis:write-styled(x: 2, y: 2, text: "TODO", style: { bold: true })
    |> koru/vaxis:write-at(x: 2, y: 4, text: "buy milk")
    |> koru/vaxis:write-styled(x: 2, y: 5, text: "walk the dog", style: { dim: true, strikethrough: true })
    |> koru/vaxis:write-at(x: 2, y: 7, text: "q to quit")
    |> koru/vaxis:render()
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
