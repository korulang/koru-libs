// progress — Charm-class meter as a reusable component tag.
//
// Thesis: `<progress/>` owns proportional ▌/░ fill, purple→pink blend, and
// trailing %, via builtin `<progress-bar/>` (fill math inside the boundary).
// Host passes reactive value/max; never paints meter chrome in ! draw.
//
//   koruc run examples/component_progress.k       (space +10  q quit)

import std/io
import std/store
import koru/vaxis

std/store:new(meter) { value: 0[i64] }

koru/vaxis:component(hint) {
    <text>space +10  |  q quit</text>
}

koru/vaxis:component(progress) {
    <stack-panel>
        <progress-bar value={{ value:d }} max={{ max:d }}/>
        <hint/>
    </stack-panel>
}

koru/vaxis:run(title: "progress")
! draw w |> progress(win: w, meter.value, max: 100)
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == ' ' |> std/store:stored { meter.value: meter.value + 10 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
