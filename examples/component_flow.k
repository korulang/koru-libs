// KORU-FLOW OVER COMPONENTS — compose components with real koru `if`.
//
// The experiment: components are now real koru EVENTS (door 1). So koru's own
// control flow should compose them with ZERO new machinery — `if` picks which
// component to invoke, exactly as it would pick between any two events.
//
//   ! ready |> if(show_hello)
//       | then |> hello()
//       | else |> bye()
//
// If the right component paints, composition-is-koru-flow is proven: no
// template `{% if %}`, no view-engine branching — just the language.
//
//   koruc run examples/component_flow.k       (q to quit)

import std/io
import koru/vaxis

koru/vaxis:component(hello) {
    <text>hello there — flow chose me</text>
}

koru/vaxis:component(bye) {
    <text>goodbye now — flow chose me</text>
}

const {
    show_hello: true
}

koru/vaxis:run(title: "flow over components")
! ready |> if(show_hello)
    | then |> hello()
    | else |> bye()
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
