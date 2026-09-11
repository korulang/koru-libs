// text-input — Charm-class field (COMPONENT_CHALLENGE Bridge).
//
// PUBLIC SURFACE (the catalog tag):
//   <text-input value={{ value:s }} ms={{ ms:d }}/>
//   koru/vaxis:text-input { win, value: string, ms: i64 }
//
// Craft: Bubbles prompt "> ", placeholder when empty, purple blink block
// cursor (~530ms from `! tick` ms), horizontal scroll when value overflows
// win width. Typing via std/string append-char / pop-char (pin 610_022).
// Field chrome lives inside the text-input boundary — not a store dump.
//
// Holes: mid-buffer caret / arrow keys deferred (append/pop end-only).
// Optional placeholder/fg props deferred (hardcoded Bubbles-ish defaults,
// same pattern as progress-bar). Surface i64/ still needs @divTrunc.
//
//   koruc run examples/component_text_input.k       (type  backspace  esc quit)

import std/io
import std/string
import std/fmt
import std/store
import koru/vaxis

std/store:new(clock) { ms: 0[i64] }
std/store:new(buf, capacity: 2) { *std/string:String<instance!> }

koru/vaxis:component(hint) {
    <text>type to edit  |  backspace  |  esc quit</text>
}

// Thin host chrome around the catalog tag — the widget is text-input.
koru/vaxis:component(app) {
    <stack-panel>
        <text-input value={{ value:s }} ms={{ ms:d }}/>
        <hint/>
    </stack-panel>
}

std/string:from-page(text: "")
| ok a |> std/string:take(s: a): text |> std/store:insert(buf) { text }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err _ |> _

koru/vaxis:run(title: "text-input")
! draw w |> koru/vaxis:sub(parent: w, x: 0, y: 0, w: 0, h: 0): root
    |> std/store:query(buf)
    ! query d |> std/fmt:ln("{{ d:S }}"): value
        |> app(win: root, value: value.text, clock.ms)
! tick ms |> std/store:stored { clock.ms: ms }
! escape _ |> koru/vaxis:quit()
! backspace _ |> std/store:query(buf)
    ! query d |> std/string:pop-char(s: d)
! char k when k.ch >= 32 and k.ch < 127 |> std/store:query(buf)
    ! query d |> std/string:append-char(s: d, k.ch)
        | ok |> _
        | err _ |> _
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
