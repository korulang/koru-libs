// <stack-panel> — the first LAYOUT CONTAINER. The container lays its children out.
//
// `app`'s markup is a `<stack-panel>` of `<todo/>` children. The container slices
// its own window into full-width, 1-row sub-windows (`sub(parent: win, y: i)`)
// and invokes each child INTO its slice. The children never know their y — layout
// is the CONTAINER's job, exactly like XAML/Svelte. And because the arrangement
// is fixed-row, it's all compile-time koru arithmetic over the Window: the layout
// evaporates to constant offsets, no runtime layout engine.
//
//   component(app) {
//       <stack-panel>
//           <todo label="…"/>   → sub(parent: win, y:0, h:1): r0 |> todo(win: r0, …)
//           <todo label="…"/>   → sub(parent: win, y:1, h:1): r1 |> todo(win: r1, …)
//       </stack-panel>
//   }
//
// If the todos stack on their own rows with NO manual box calls (the caller just
// says `app(win: w)`), the container is real — the first XAML-family layout, as
// koru. And it survives resize, because `! draw` repaints it.
//
//   koruc run examples/component_stack.k       (q to quit)

import std/io
import koru/vaxis

koru/vaxis:component(todo) {
    <text>{{ label:s }}</text>
}

koru/vaxis:component(app) {
    <stack-panel>
        <todo label="buy milk"/>
        <todo label="walk the dog"/>
        <todo label="ship StackPanel"/>
    </stack-panel>
}

koru/vaxis:run(title: "stackpanel")
! draw w |> app(win: w)
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
