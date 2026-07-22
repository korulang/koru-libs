// PROP FORWARDING — the component graph carries DATA parent→child.
//
// `page`'s child tag uses `name={{ who:s }}` — not a literal. The `{{ who:s }}`
// makes `who: string` a PROP of `page`, and forwards it into the child call:
// `greet(name: who)`. So `page(who: "Lars")` flows its `who` down into `greet`,
// which paints it. Data crosses the component boundary through a real koru
// invocation arg — the graph edge carries a value, not just a call.
//
// If "Lars" paints, prop forwarding is proven: page's prop → greet's param.
//
//   koruc run examples/component_forward.k       (q to quit)

import std/io
import koru/vaxis

koru/vaxis:component(greet) {
    <text>{{ name:s }}</text>
}

koru/vaxis:component(page) {
    <greet name={{ who:s }}/>
}

koru/vaxis:run(title: "prop forward")
! draw w |> page(win: w, who: "Lars")
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
