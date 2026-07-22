// COMPONENT NESTING — a component uses another component (the A-uses-B graph).
//
// `page`'s markup contains `<greet name="World"/>` — a CHILD tag that is NOT
// `<text>`. That lowers to a real invocation of `greet`'s synthesized event:
// `page`'s impl calls `greet(name: "World")`. So composition is a real koru
// invocation graph in the AST, not opaque template text — cycle / render-order /
// dead-component analysis all come for free, because it's just calls.
//
// If "World" paints, component-uses-component is proven: `page()` fired `greet`.
//
//   koruc run examples/component_nest.k       (q to quit)

import std/io
import koru/vaxis

koru/vaxis:component(greet) {
    <text>{{ name:s }}</text>
}

koru/vaxis:component(page) {
    <greet name="World"/>
}

koru/vaxis:run(title: "component nest")
! ready |> page()
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
