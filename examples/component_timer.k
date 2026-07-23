// timer — Charm-class COUNTDOWN clock (COMPONENT_CHALLENGE Bridge).
//
// PUBLIC SURFACE (the catalog tag):
//   <timer remaining_ms={{ remaining:d }} running={{ running:d }}/>
//   koru/vaxis:timer { win, remaining_ms: i64, running: i64 }
//
// Craft: ports bubbles/timer. The widget paints the REMAINING duration as a Go
// time.Duration.String() ("1m2s" / "500ms" / "0s" taste) and owns all chrome —
// purple #5A56E0 while running, dim #606060 when paused, and when it reaches 0
// it is TIMED OUT: "0s" painted bold in Charm pink #EE6FF8. The host store owns
// the remaining ms + running flag (same host-owned model as spinner) and
// decrements by the real wall-ms delta on each `! tick`, so the digits count
// down at 1× real time on a live TTY.
//
// Keys: space or `s` toggle run/pause; `r` reset to 15s.
//
// Holes: `running` rides the i64 store rail (0/1) — no bool store field yet;
// display shows true sub-second fraction each frame (Charm's default 1s
// interval would quantize to whole seconds); custom timeout/colors deferred
// (hardcoded Bubbles-ish defaults, same pattern as progress-bar).
//
//   koruc run examples/component_timer.k     (space/s pause  r reset  q quit)

import std/io
import std/store
import koru/vaxis

// Host state — the countdown lives here; the timer widget only paints from it.
// `last` holds the previous tick's monotonic ms so the delta is real wall time.
std/store:new(tmr) {
    remaining: 15000[i64],
    last:      0[i64],
    running:   1[i64]
}

koru/vaxis:component(hint) {
    <text>space/s pause · resume    r reset    q quit</text>
}

// Thin host chrome around the catalog tag — the widget is timer.
koru/vaxis:component(app) {
    <stack-panel>
        <timer remaining_ms={{ remaining:d }} running={{ running:d }}/>
        <hint/>
    </stack-panel>
}

koru/vaxis:run(title: "timer")
! draw w |> app(win: w, tmr.remaining, tmr.running)
! tick ms when tmr.last == 0 |> std/store:stored { tmr.last: ms }
! tick ms when tmr.running == 1 and tmr.remaining > 0 and tmr.last > 0 |> std/store:stored { tmr.remaining: tmr.remaining - (ms - tmr.last), tmr.last: ms }
! tick ms when tmr.last > 0 |> std/store:stored { tmr.last: ms }
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == ' ' and tmr.running == 1 |> std/store:stored { tmr.running: 0 }
! key k when k.ch == ' ' and tmr.running == 0 |> std/store:stored { tmr.running: 1 }
! key k when k.ch == 's' and tmr.running == 1 |> std/store:stored { tmr.running: 0 }
! key k when k.ch == 's' and tmr.running == 0 |> std/store:stored { tmr.running: 1 }
! key k when k.ch == 'r' |> std/store:stored { tmr.remaining: 15000 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
