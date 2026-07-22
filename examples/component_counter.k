// COMPONENT with a FORMATTED prop — `{{ n:d }}` is an i64, not a string.
//
// The `{{ n:d }}` placeholder makes `counter { n: i64 }`; because the text is
// mixed (literal + a typed hole), the synthesized impl routes it through
// std/fmt:ln and paints the result — safe now that write-at owns its bytes.
// So `counter(n: 42)` formats and renders "clicked 42 times".
//
//   koruc run examples/component_counter.k       (q to quit)

import std/io
import std/fmt
import koru/vaxis

koru/vaxis:component(counter) {
    <text>clicked {{ n:d }} times</text>
}

koru/vaxis:run(title: "component counter")
! draw w |> counter(win: w, n: 42)
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
