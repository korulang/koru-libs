// Skunkworks — reuse the SAME Style value across many rows (option B's payoff).
//
// `style(…): style` builds one dim+strikethrough style, bound once. The two
// "done" rows carry NO style arg — they auto-pun `style` from the binding (the
// subtree scalar-bind pun). The TODO row passes an explicit style, overriding
// the pun. One value, many applications — the reason B beats flat params.
//
//   koruc run examples/style_reuse.k       (q to quit)

import std/io
import koru/vaxis

koru/vaxis:run(title: "reuse")
! ready |> koru/vaxis:style(bold: false, dim: true, italic: false, strikethrough: true): style
    |> koru/vaxis:write-styled(x: 2, y: 2, text: "TODO", style: { bold: true })
    |> koru/vaxis:write-at(x: 2, y: 4, text: "buy milk")
    |> koru/vaxis:write-styled(x: 2, y: 5, text: "walk the dog")
    |> koru/vaxis:write-styled(x: 2, y: 6, text: "do laundry")
    |> koru/vaxis:write-at(x: 2, y: 8, text: "q to quit")
    |> koru/vaxis:render()
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
