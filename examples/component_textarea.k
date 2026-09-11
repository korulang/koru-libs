// textarea — Charm-class multi-line input (COMPONENT_CHALLENGE Bridge).
//
// PUBLIC SURFACE (the catalog tag):
//   <textarea dock="fill" value={{ value:s }} ms={{ ms:d }}/>
//   koru/vaxis:textarea { win, value: string, ms: i64 }
//
// Craft: bubbles/textarea's job — a multi-line value filling a TALL window
// behind a purple "┃ " prompt gutter down the full height; placeholder when
// empty; purple #5A56E0 blink block cursor (~530ms from `! tick` ms) at the
// end of the value; bottom-anchored vertical follow when content is taller
// than the window; long lines hard-clip except the cursor line, which
// scrolls horizontally like text-input. Enter inserts a line break: ch 13
// appended verbatim through the proven append-char path — the widget treats
// '\r' and '\n' both as hard breaks. Host store owns the buffer; the widget
// OWNS paint/chrome, NOT the `! key` pipeline.
//
// Holes: mid-buffer caret / arrow navigation deferred (append/pop end-only —
// text-input's hole); soft-wrap deferred (honest hard-clip, viewport's
// default); line numbers / char limit / focused-blurred chrome deferred.
//
//   koruc run examples/component_textarea.k   (type  enter newline  backspace  esc quit)

import std/io
import std/string
import std/fmt
import std/store
import koru/vaxis

std/store:new(clock) { ms: 0[i64] }
std/store:new(buf, capacity: 2) { *std/string:String<instance!> }

koru/vaxis:component(title) {
    <text>── textarea ────────────────────────────────</text>
}

koru/vaxis:component(hint) {
    <text>type to edit  |  enter newline  |  backspace  |  esc quit</text>
}

// Thin host chrome around the catalog tag — the widget is textarea. It
// needs a tall window (it fills whatever it is handed), so `<dock>`'s fill
// slot carries it; title and hint pin to the edges.
koru/vaxis:component(app) {
    <dock>
        <title dock="top" h="2"/>
        <textarea dock="fill" value={{ value:s }} ms={{ ms:d }}/>
        <hint dock="bottom" h="1"/>
    </dock>
}

std/string:from-page(text: "")
| ok a |> std/string:take(s: a): text |> std/store:insert(buf) { text }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err _ |> _

koru/vaxis:run(title: "textarea")
! draw w |> koru/vaxis:sub(parent: w, x: 0, y: 0, w: 0, h: 0): root
    |> std/store:query(buf)
    ! query d |> std/fmt:ln("{{ d:S }}"): value
        |> app(win: root, value: value.text, clock.ms)
! tick ms |> std/store:stored { clock.ms: ms }
! escape _ |> koru/vaxis:quit()
! backspace _ |> std/store:query(buf)
    ! query d |> std/string:pop-char(s: d)
! enter _ |> std/store:query(buf)
    ! query d |> std/string:append-char(s: d, ch: 13)
        | ok |> _
        | err _ |> _
! char k when k.ch >= 32 and k.ch < 127 |> std/store:query(buf)
    ! query d |> std/string:append-char(s: d, k.ch)
        | ok |> _
        | err _ |> _
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
