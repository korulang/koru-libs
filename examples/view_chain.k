// The `view` DSL, second increment: N sibling elements → a chain of write-ats.
//
// Three `<text>` elements lower to three real `write-at` invocations, wired as
// a `|>` pipeline and stacked one per row. If all three lines paint, the
// multi-invocation continuation-chain lowering is real — the step from a single
// element to composable flow.
//
//   koruc run examples/view_chain.k       (q to quit)

import std/io
import koru/vaxis

koru/vaxis:run(title: "view chain")
! ready |> koru/vaxis:view {
    <text>first line</text>
    <text>second line</text>
    <text>third line</text>
}
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
