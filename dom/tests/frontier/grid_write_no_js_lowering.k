// FRONTIER REPRO — std/grid has NO JavaScript lowering: a grid write emits a
// synthesized `__grid_write_L*` event with no |js proc, immediate, or subflow
// body, and the JS emitter PANICS (js_emitter.zig:514, NoJsProcBody):
//
//     [js_emitter] event '__grid_write_L4_4f1' has no |js proc, immediate, or subflow body
//     thread ... panic: js_emitter.emit failed: NoJsProcBody
//
// Why it matters to the DOM gauntlet: 690_253 established the grid-of-handles
// as THE spellable position->handle index ("a row is reachable by position,
// through a grid of handles"), and table order is exactly such an index. With
// no grid on this target, the round-2 vehicle keeps position as a store
// column (`pos`) maintained by compaction sweeps instead — spellable, but it
// re-derives per-remove what the grid would hold.
//
// The same program compiles and runs on the Zig lane.

import std/grid

std/grid:new(xref, size: 4) { h: 0[i64] }

std/grid:stored { xref[1].h: 5 }
