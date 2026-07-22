// TRACER — the `view` DSL's first end-to-end proof.
//
// `view { <text>hi</text> }` is markup. At COMPILE TIME the `view` transform
// parses it and lowers it to a real `write-at(x: 0, y: 0, text: "hi")` koru
// invocation — composed out of the existing write-at event, not reimplemented.
// If "hi" paints top-left, the whole Svelte-for-terminal lowering path is real.
//
//   koruc run examples/view_tracer.k       (q to quit)

import std/io
import koru/vaxis

koru/vaxis:run(title: "view tracer")
! draw _ |> koru/vaxis:view { <text>hi</text> }
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
