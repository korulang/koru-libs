// FRONTIER REPRO — a chain NEVER survives past stripe(): everything chained
// after `std/store:stripe(s)` is SILENTLY dropped, on BOTH lanes. This
// program never prints "tail survived"; the emitted JS tick/flow handler
// simply ends at the stripe call — the tail steps are absent from the
// emitted code, no diagnostic. Same on `koruc run`.
//
// 690_028 pins that `stored` joins chains "rather than swallowing its
// continuation"; stripe does not join. Every stripe in the regression corpus
// is chain-terminal (690_014/045/200/201), so the corpus cannot see this.
//
// Why it matters: a click-driven operation is exactly "stage op, sweep, then
// continue" — stage/sweep/read-results/reset is one chain. The round-2
// vehicle's workaround is to wrap the stripe terminally in a tor body
// (`sweep = std/store:stripe(rows)`) and chain after the CALL — the outer
// chain then survives, which also shows the swallow is a chain-desugar bug,
// not a runtime property of stripe.

import std/io
import std/store

std/store:new(game, capacity: 4) { hp: i64 }

std/store:insert(game) { hp: 3 }

std/store:rule(game)
! row e |> std/io:print.ln("hp {{ e.hp:d }}")

std/store:stripe(game) |> std/io:print.ln("tail survived")
