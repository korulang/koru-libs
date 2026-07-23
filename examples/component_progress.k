// progress-bar — Charm-class meter (COMPONENT_CHALLENGE Bridge).
//
// PUBLIC SURFACE (the catalog tag):
//   <progress-bar value={{ value:d }} max={{ max:d }}/>
//   koru/vaxis:progress-bar { win, value: i64, max: i64 }
//
// Craft: proportional ▌/░, purple→pink half-block blend, trailing %, width
// from win. Colors/runes/% are Bubbles defaults (not yet props — event
// defaults / optional params are a language gap). Spring deferred (ticks).
//
//   koruc run examples/component_progress.k       (space +10  q quit)
//   eyes: koru-examples/gallery

import std/io
import std/store
import koru/vaxis

std/store:new(meter) { value: 0[i64] }

koru/vaxis:component(hint) {
    <text>space +10  |  q quit</text>
}

// Thin host chrome around the catalog tag — the widget is progress-bar.
koru/vaxis:component(app) {
    <stack-panel>
        <progress-bar value={{ value:d }} max={{ max:d }}/>
        <hint/>
    </stack-panel>
}

koru/vaxis:run(title: "progress-bar")
! draw w |> app(win: w, meter.value, max: 100)
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == ' ' |> std/store:stored { meter.value: meter.value + 10 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
