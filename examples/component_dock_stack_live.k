// Live StackPanel as Dock fill — empty <StackPanel dock="fill"/> returns a
// Stack cursor; draw-time sweep pushes rows via stack-row.
//
//   koruc run examples/component_dock_stack_live.k

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

koru/vaxis:component(topbar) {
    <text>{{ title:s }}</text>
}

koru/vaxis:component(statusbar) {
    <text>{{ hint:s }}</text>
}

koru/vaxis:component(app) {
    <Dock>
        <topbar dock="top" h="1" title="== live fill =="/>
        <statusbar dock="bottom" h="1" hint="q quit"/>
        <StackPanel dock="fill"/>
    </Dock>
}

std/string:from-page(text: "buy milk")
| ok a |> std/string:take(s: a): m |> std/store:insert(todos) { label: m, done: 0 }
    | row _ |> std/string:from-page(text: "walk the dog")
        | ok b |> std/string:take(s: b): label
            |> std/store:insert(todos) { label, done: 0 }
                | row _ |> _
| err _ |> _

koru/vaxis:run(title: "dock-stack-live")
! draw w |> app(win: w): panel
    |> std/store:sweep(todos)
    ! sweep { entity.label } |> std/string:read(s: label): text
        |> koru/vaxis:stack-row(stack: panel): rw
        |> std/fmt:ln("{{ text:s }}"): line |> todo-row(win: rw, line.text)
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
