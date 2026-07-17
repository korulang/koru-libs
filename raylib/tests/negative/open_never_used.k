// NEGATIVE TEST — must NOT compile, in BOTH modes (no --auto-discharge flag
// needed). The asymmetric-model payoff:
//
// The window is opened and never rendered. <opened!> has NO disposer
// (window.close accepts only <!active>) and the auto-discharge walk cannot
// route through `frames` (it takes a `count` param) — so allocate-without-use
// is a KORU030 compile error, not a silent RAII autodrop.
//
//   koruc run raylib/tests/negative/open_never_used.k
//   -> error[KORU030]: obligation <opened!> not discharged
//
// Canonical pattern: koru tests/regression/336_OBLIGATION_MATRIX/db.kz
// (connected -> active -> close).

import libs/raylib
import std/io

libs/raylib:window.open.hidden(width: 320, height: 200, title: "never used")
| win w |> std/io:print.ln("BUG: opened a window and never rendered to it")
| err e |> std/io:print.ln("init failed: {{ e:s }}")
