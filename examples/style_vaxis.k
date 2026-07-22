// Skunkworks — vaxis styling (option B: a reusable Style value).
//
// Static text, boolean attrs only — deliberately sidesteps both the Color
// union (next decision) and the allocation-lifetime bug (literals live
// forever). The question this probe answers: does a Style value attach to a
// write, and does an inline record literal `{ dim: true, ... }` fill it?
//
//   koruc run examples/style_vaxis.k       (q to quit)

import std/io
import koru/vaxis

koru/vaxis:run(title: "styles")
! ready |> koru/vaxis:write-styled(x: 2, y: 2, text: "TODO", style: { bold: true })
    |> koru/vaxis:write-at(x: 2, y: 4, text: "buy milk")
    |> koru/vaxis:write-styled(x: 2, y: 5, text: "walk the dog", style: { dim: true, strikethrough: true })
    |> koru/vaxis:write-at(x: 2, y: 7, text: "q to quit")
    |> koru/vaxis:render()
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
