// spinner — Charm-class MiniDot (COMPONENT_CHALLENGE Bridge).
//
// PUBLIC SURFACE (the catalog tag):
//   <spinner ms={{ ms:d }}/>
//   koru/vaxis:spinner { win, ms: i64 }
//
// Craft: bubbles MiniDot braille cycle (⠋⠙⠹…), Charm purple #5A56E0, MiniDot
// FPS (1000/12 ms) owned inside the spinner — host only feeds `! tick` ms.
// Spin chrome lives inside the spinner boundary — not `! key` fake animation.
//
// Holes: surface `i64 /` emits Zig `/` (needs @divTrunc) — FPS math therefore
// lives in the zig builtin (same pattern as progress fill). Optional `?u32` fg
// / spinner kind props not yet — defaults match Bubbles MiniDot + purple.
//
//   koruc run examples/component_spinner.k       (q quit)

import std/io
import std/store
import koru/vaxis

std/store:new(spin) { ms: 0[i64] }

koru/vaxis:component(hint) {
    <text>Charm MiniDot — q quit</text>
}

// Thin host chrome around the catalog tag — the widget is spinner.
koru/vaxis:component(app) {
    <stack-panel>
        <spinner ms={{ ms:d }}/>
        <hint/>
    </stack-panel>
}

koru/vaxis:run(title: "spinner")
! draw w |> app(win: w, spin.ms)
! tick ms |> std/store:stored { spin.ms: ms }
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
