// progress-bar — reusable meter row: label + value/max readout in one widget.
//
// Thesis: a drop-in progress bar owns its two-row stack layout and formats
// value against max; the host passes reactive props and never paints meter
// chrome in the top-level draw pipeline.
//
//   koruc run examples/component_progress_bar.k       (space +10  q quit)

import std/io
import std/fmt
import std/store
import koru/vaxis

std/store:new(progress) { value: 0[i64] }

koru/vaxis:component(progress-label) {
    <text>{{ label:s }}</text>
}

koru/vaxis:component(progress-value) {
    <text>{{ value:d }} / {{ max:d }}</text>
}

koru/vaxis:component(progress-bar) {
    <stack-panel>
        <progress-label label={{ label:s }}/>
        <progress-value value={{ value:d }} max={{ max:d }}/>
    </stack-panel>
}

koru/vaxis:component(hint-line) {
    <text>space +10  |  q quit</text>
}

koru/vaxis:component(app) {
    <stack-panel>
        <progress-bar label={{ title:s }} value={{ value:d }} max={{ max:d }}/>
        <hint-line/>
    </stack-panel>
}

koru/vaxis:run(title: "progress-bar")
! draw w |> app(win: w, title: "Download", progress.value, max: 100)
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == ' ' |> std/store:stored { progress.value: progress.value + 10 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
