// stopwatch — Charm-class COUNT-UP clock (COMPONENT_CHALLENGE Bridge).
//
// PUBLIC SURFACE (the catalog tag):
//   <stopwatch elapsed_ms={{ elapsed:d }} running={{ running:d }}/>
//   koru/vaxis:stopwatch { win, elapsed_ms: i64, running: i64 }
//
// Craft: ports bubbles/stopwatch. The widget paints the ELAPSED duration as a
// Go time.Duration.String() ("1m2s" / "500ms" / "0s" taste) and owns its chrome
// — purple #5A56E0 while running, dim #606060 when paused. The host store owns
// the elapsed ms + running flag (host-owned model, same as spinner) and
// increments by the real wall-ms delta on each `! tick`, so the digits climb at
// 1× real time on a live TTY; reset zeroes it.
//
// Keys: space or `s` toggle run/pause; `r` reset to 0.
//
// Holes: `running` rides the i64 store rail (0/1) — no bool store field yet;
// display shows true sub-second fraction each frame (Charm's default 1s
// interval would quantize to whole seconds); custom colors/laps deferred
// (hardcoded Bubbles-ish defaults, same pattern as progress-bar).
//
//   koruc run examples/component_stopwatch.k  (space/s pause  r reset  q quit)

import std/io
import std/store
import koru/vaxis

// Host state — the elapsed clock lives here; the stopwatch widget only paints
// from it. `last` holds the previous tick's monotonic ms for a real delta.
std/store:new(sw) {
    elapsed: 0[i64],
    last:    0[i64],
    running: 1[i64]
}

koru/vaxis:component(hint) {
    <text>space/s pause · resume    r reset    q quit</text>
}

// Thin host chrome around the catalog tag — the widget is stopwatch.
koru/vaxis:component(app) {
    <stack-panel>
        <stopwatch elapsed_ms={{ elapsed:d }} running={{ running:d }}/>
        <hint/>
    </stack-panel>
}

koru/vaxis:run(title: "stopwatch")
! draw w |> app(win: w, sw.elapsed, sw.running)
! tick ms when sw.last == 0 |> std/store:stored { sw.last: ms }
! tick ms when sw.running == 1 and sw.last > 0 |> std/store:stored { sw.elapsed: sw.elapsed + (ms - sw.last), sw.last: ms }
! tick ms when sw.last > 0 |> std/store:stored { sw.last: ms }
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == ' ' and sw.running == 1 |> std/store:stored { sw.running: 0 }
! key k when k.ch == ' ' and sw.running == 0 |> std/store:stored { sw.running: 1 }
! key k when k.ch == 's' and sw.running == 1 |> std/store:stored { sw.running: 0 }
! key k when k.ch == 's' and sw.running == 0 |> std/store:stored { sw.running: 1 }
! key k when k.ch == 'r' |> std/store:stored { sw.elapsed: 0 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
