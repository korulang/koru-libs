// The DOM gauntlet vehicle — krausest/js-framework-benchmark (keyed), on
// koru/dom. Round 1 wires the create path: #run (action 1) and #add (action 3)
// each build 1,000 rows through the store.
//
// The model is the store, per the gauntlet thesis: rows exist as store rows
// first, and the DOM row is written by the store's own write path — the
// `inserted` lifecycle interceptor (690_041: "everything reactive compiles
// down into these same interceptor branches"), producer owns the if, no
// framework diff pass. It is the interceptor and not `rule` because of a
// pinned defect, not a preference: a rule arm's row-binding read passed to a
// |js-BODIED proc (`! row e |> f(e.id)` where f's body is host JS) emits the
// ZIG column read (`(&store.col)[@as(usize, ...)]`) into the JS output; the
// same read lowers correctly into a Koru-subflow callee or a fmt
// interpolation (690_005's emitted qbody). Repro:
// dom/tests/frontier/rule_row_read_call_arg_js.k. The interceptor
// destructure threads column VALUES as payload and is JS-clean on all paths.
//
// What the store canNOT carry on the JS target today is the label: a char[N]
// column's generated host code contains Zig (`@import`) and the JS emitter
// refuses the program (probe-pinned; 690_052 is the Zig-lane shape). So the
// label is minted by `make-label` at insert time and threaded as an effect
// payload — a measured escape, counted in js_escape, and the first
// feature-mining find of the gauntlet.
//
// Ids are sequential from 1 and continue across creates (Main.js:65
// `id: this.id++`); `seq.next` is that counter as a singleton store.
//
// Unwired actions (runlots 2, update 4, clear 5, swaprows 6, remove 7,
// select 8) fire `! click` and match no arm: those operations are
// unimplemented this round and their closer ops fail loudly, which is the
// honest board.

import std/store
import std/control
import koru/dom

std/store:new(rows, capacity: 16384) { id: i64 }
! inserted { id } |> make-label(): l |> append-row(id, label: l)

std/store:new(seq) { next: 1[i64] }

pub tor make-label {} -> string
pub tor append-row { id: i64, label: string }

tor build { n: i64 }

build = for(0..n)
    ! each _ |> std/store:insert(rows) { id: seq.next }
        | row _ |> std/store:stored { seq.next: seq.next + 1 }
        | full |> _

koru/dom:run(title: "Koru-DOM (keyed)")
! click { action } when action == 1 |> build(n: 1000)
! click { action } when action == 3 |> build(n: 1000)
