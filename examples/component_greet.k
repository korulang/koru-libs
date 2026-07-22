// COMPONENT — a named view that synthesizes a real koru event.
//
// `component(greet) { <text>{{ name:s }}</text> }` is a declaration. The
// `{{ name:s }}` placeholder BECOMES the event's typed input — a `greet { name:
// string }` event is synthesized, with an implementing flow that paints it.
// Then `greet(name: "Lars")` is a normal koru call. Props from placeholders,
// event synthesis, and it's-just-a-koru-invocation — the whole component model
// in one step. If "Lars" paints, koru `if`/`for`/nesting over components all
// follow for free.
//
//   koruc run examples/component_greet.k       (q to quit)

import std/io
import koru/vaxis

koru/vaxis:component(greet) {
    <text>{{ name:s }}</text>
}

koru/vaxis:run(title: "component")
! draw w |> greet(win: w, name: "Lars")
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
