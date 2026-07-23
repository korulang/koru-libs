// Live StackPanel — runtime stack cursor for store-driven rows.
//
// Static `<stack-panel>` comptime-folds fixed children. Live rows arrive from
// `sweep` at draw time; `stack` / `stack-row` make layout the container's job
// (children never pass `y:`). Same thesis as markup StackPanel, draw-time twin.
//
//   koruc run examples/component_stack_live.k       (q to quit)

import std/io
import std/string
import std/store
import std/fmt
import koru/vaxis

std/store:new(todos, capacity: 8) {
    label: *std/string:String<instance!>,
    done: i64
}

koru/vaxis:component(todo-row) {
    <text>{{ text:s }}</text>
}

std/string:from-page(text: "buy milk")
| ok a |> std/string:take(s: a): m |> std/store:insert(todos) { label: m, done: 0 }
    | row _ |> std/string:from-page(text: "walk the dog")
        | ok b |> std/string:take(s: b): label
            |> std/store:insert(todos) { label, done: 0 }
                | row _ |> _
| err _ |> _

koru/vaxis:run(title: "stack live")
! draw w |> koru/vaxis:stack(parent: w): panel
    |> std/store:sweep(todos)
    ! sweep { entity.label } |> std/string:read(s: label): text
        |> koru/vaxis:stack-row(stack: panel): rw
        |> std/fmt:ln("{{ text:s }}"): line |> todo-row(win: rw, line.text)
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
