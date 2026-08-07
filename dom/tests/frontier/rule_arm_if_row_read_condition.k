// FRONTIER REPRO — a ROW-BINDING read in an `if` CONDITION inside a rule arm
// body is spliced as its raw surface text under --lang=js:
//
//     if (e.id == 7) {        -> ReferenceError: e is not defined
//
// at ANY if depth (depth 1 shown; nested ifs identical). The boundary, probed
// 2026-08-07: the same read lowers correctly in the rule's own `when` guard,
// as a call argument to a Koru subflow, as a `stored` write address/value,
// and in a fmt interpolation. The if CONDITION is the one position that
// misses the qbody rewrite — the arm's row cursor (__koru_qrow) is threaded
// into the body handler, but the condition expression never gets rewritten
// through it.
//
// The Zig lane lowers the READ correctly here but fails differently: the
// body-if under a rule arm emits a call to `koru_std.koru_control.if_event`,
// and the emitted runtime module has no `koru_control` member (measured,
// same file under `koruc run`, with std/control imported) — body-ifs under
// rule arms appear to have no green path on either lane except through the
// bind-first idiom.
//
// Workaround (the round-2 vehicle ships on it): bind first, 320_128's idiom —
// `echo(v: e.pos): p |> if(p == op.a)` — the call-argument read lowers
// correctly and the condition then reads a plain local.

import std/io
import std/store
import std/control

std/store:new(rows, capacity: 4) { id: i64 }

std/store:insert(rows) { id: 7 }

std/store:rule(rows)
! row e |> if(e.id == 7)
    | then |> std/io:print.ln("hit {{ e.id:d }}")
    | else |> _
