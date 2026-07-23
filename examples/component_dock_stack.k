// <dock> with nested <stack-panel dock="fill"> — chrome + list in ONE markup tree.
// Static children flatten into the fill window (container still owns y).
//
//   koruc run examples/component_dock_stack.k

import std/io
import koru/vaxis

koru/vaxis:component(topbar) {
    <text>{{ title:s }}</text>
}

koru/vaxis:component(statusbar) {
    <text>{{ hint:s }}</text>
}

koru/vaxis:component(row) {
    <text>{{ label:s }}</text>
}

koru/vaxis:component(app) {
    <dock>
        <topbar dock="top" h="1" title="== dock + stack =="/>
        <statusbar dock="bottom" h="1" hint="q to quit"/>
        <stack-panel dock="fill">
            <row label="buy milk"/>
            <row label="ship StackPanel-as-fill"/>
        </stack-panel>
    </dock>
}

koru/vaxis:run(title: "dock-stack")
! draw w |> app(win: w)
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
