// Selection list — store-driven rows, keyboard cursor, koru `if` picks row chrome.
//
// Thesis: a live `<stack-panel dock="fill"/>` inside `<dock>` can sweep a store
// and branch per-row (`row == ui.sel`) into two leaf components — selection
// state lives in a sibling store, keys mutate it, vaxis auto-repaints on damage.
//
//   koruc run examples/component_selection_list.k       (k/j navigate, q quit)

import std/io
import std/string
import std/store
import std/fmt
import koru/vaxis

std/store:new(items, capacity: 8) {
    label: *std/string:String<instance!>
}

std/store:new(ui) { sel: 0[i64] }

koru/vaxis:component(list-row) {
    <text>  {{ label:s }}</text>
}

koru/vaxis:component(list-row-selected) {
    <text>> {{ label:s }}</text>
}

koru/vaxis:component(title-bar) {
    <text>{{ title:s }}</text>
}

koru/vaxis:component(hint-bar) {
    <text>sel {{ sel:d }}/{{ total:d }}  |  k up  j down  q quit</text>
}

koru/vaxis:component(app) {
    <dock>
        <title-bar dock="top" h="1" title="== selection list =="/>
        <hint-bar dock="bottom" h="1" sel={{ sel:d }} total={{ total:d }}/>
        <stack-panel dock="fill"/>
    </dock>
}

std/string:from-page(text: "buy milk")
| ok a |> std/string:take(s: a): s0 |> std/store:insert(items) { label: s0 }
    | row _ |> std/string:from-page(text: "walk the dog")
        | ok b |> std/string:take(s: b): s1
            |> std/store:insert(items) { label: s1 }
                | row _ |> std/string:from-page(text: "ship the layout engine")
                    | ok c |> std/string:take(s: c): s2
                        |> std/store:insert(items) { label: s2 }
                            | row _ |> std/string:from-page(text: "green the compiler")
                                | ok d |> std/string:take(s: d): s3
                                    |> std/store:insert(items) { label: s3 }
                                        | row _ |> _
| err _ |> _

koru/vaxis:run(title: "selection-list")
! draw w |> app(win: w, ui.sel, total: 4): panel
    |> std/store:sweep(items)
    ! sweep { entity.label, row } |> std/string:read(s: label): text
        |> std/fmt:ln("{{ text:s }}"): line
        |> if(row == ui.sel)
            | then |> koru/vaxis:stack-row(stack: panel): rw
                |> list-row-selected(win: rw, label: line.text)
            | else |> koru/vaxis:stack-row(stack: panel): rw
                |> list-row(win: rw, label: line.text)
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == 'k' |> if(ui.sel > 0)
    | then |> std/store:stored { ui.sel: ui.sel - 1 }
    | else |> _
! key k when k.ch == 'j' |> if(ui.sel < 3)
    | then |> std/store:stored { ui.sel: ui.sel + 1 }
    | else |> _
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
