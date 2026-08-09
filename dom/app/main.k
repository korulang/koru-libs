// The DOM gauntlet vehicle — krausest/js-framework-benchmark (keyed), on
// koru/dom. Round 2 wires all nine click operations through the store: the
// store is the model, and every DOM mutation is driven by the store's own
// write path — lifecycle interceptors (inserted/removed), a field watch
// (selection), and standing rules fired by the momentary `stripe` sweep.
//
// The model: rows { id, pos }. `pos` is the row's position in table order,
// written at insert from the `cnt` counter and maintained by the compaction
// sweep after a remove (vanilla's array order, kept as a column — the ruled
// "externally maintained index kept current by the store's own writeback"
// shape). `seq.next` is the reference's monotonic id counter (Main.js:65).
// `op` is the pending-operation register: click arms stage an op code (and
// operands a/b), run the sweep, and reset. Sweeps dispatch on op.code.
//
// ⛔ THIS HEADER ONCE LISTED FIVE SHAPES AS "FORCED BY PINNED JS-LANE WALLS".
// All five walls were FIXED IN THE COMPILER THE SAME NIGHT they were found
// (690_258/259/260/261/262, green on the board), and the workarounds sat here
// for a day afterwards describing them in the present tense. The cost is not
// hypothetical: a later session read this header, believed it, and reasoned
// from a dead constraint while designing the next piece of work. A shape kept
// past its reason does not just sit there — it teaches.
//
// So: state what is true, and say why a shape exists on its own terms.
//
//   - `clear` and the click arms call `std/store:stripe(rows)` where they mean
//     it. The chain survives it (690_258); it used to be swallowed.
//   - rule arms read `e.pos` / `e.id` where the value is used. The bind-first
//     `echo` dance is gone (690_260, 690_262).
//   - `swap-rows` is called directly; the forwarding tors that existed only to
//     keep a row read away from a |js body are gone (690_262). `mark-row` is
//     gone entirely — see below.
//   - op dispatch STILL lives in body-`if`s rather than `when` guards — and
//     this one is now a real choice, not a dodge. `stripe` fires ONE FULL
//     SWEEP PER RULE, so splitting the four op cases into four guarded rules
//     would cost four passes over every row instead of one. Cross-store reads
//     in a guard lower correctly today (690_259); the shape stays for its own
//     reason.
//   - std/grid still has NO JS lowering (dom/tests/frontier/grid_write_no_js_lowering.k
//     — the one wall still standing), so the position index is the `pos`
//     column, not a grid of handles.
//
// A row's label LIVES IN THE STORE (`label: char[48]`), and marking it is a
// store write — `e.label: "{{ e.label:s }} !!!"` — followed by `Row-repaint`,
// which pushes the new value back through the same markup that painted it.
// There is no hand-written DOM mutation for marking any more.
//
// That took three compiler changes that landed the same day and are pinned:
// a written value may build text (690_268), that value survives inside an `if`
// arm (690_269), and a rule arm stops rewriting string literals (690_267).

import std/store
import std/control
import koru/dom

// The krausest row (vanillajs Main.js:7-9), as markup Koru compiles: the
// static structure becomes a module-level <template> built once, the
// {{ id:d }} / {{ label:s }} placeholders become the typed input of the
// synthesized `Row` event, and every lowercase tag passes through untouched
// (ruled 2026-08-07: capital = ours, anything else is not inspected).
koru/dom:component(Row) {
    <tr>
        <td class="col-md-1">{{ id:d }}</td>
        <td class="col-md-4"><a data-action="8">{{ label:s }}</a></td>
        <td class="col-md-1"><a data-action="7"><span class="glyphicon glyphicon-remove" aria-hidden="true"></span></a></td>
        <td class="col-md-6"></td>
    </tr>
}

// The row's HANDLE is what ties the store's row to the element painted for
// it: `[id]h` on both lifecycle arms is the same value, and it survives the
// swap-remove that moves a row between slots. So the component is keyed on it
// at birth and the library is told to let go of it at death — neither side
// ever searches the page for a row.
// The label column is sized from the reference's own arithmetic, not guessed.
// Its word lists top out at "inexpensive yellow sandwich" — 27 characters — and
// the partial-update benchmark clicks four times, appending " !!!" each time for
// 16 more. 43 is the real maximum; 40 silently truncated it, so roughly twelve
// rows in a thousand rendered the wrong text on every run and the reference
// harness aborted on row 991. 48 covers 43 with one mark of slack.
std/store:new(rows, capacity: 16384) { id: i64, pos: i64, label: char[48] }
! inserted { id, label, [id]h } |> Row(parent: "#tbody", key: h, id, label)
! removed { [id]h } |> koru/dom:drop(key: h) |> std/store:stored { cnt.n: cnt.n - 1 }
! cleared _ |> koru/dom:drop-all() |> std/store:stored { cnt.n: 0 }

std/store:new(seq) { next: 1[i64] }
std/store:new(cnt) { n: 0[i64] }
std/store:new(op) { code: 0[i64], a: 0[i64], b: 0[i64], ida: 0[i64], idb: 0[i64] }
std/store:new(sel) { cur: 0[i64] }

std/store:watch(sel)
! cur c |> select-row(id: c)

pub tor make-label {} -> string
pub tor select-row { id: i64 }
pub tor swap-rows { a: i64, b: i64 }

tor clear {}
clear = std/store:clear(rows)

tor build { n: i64 }

build = for(0..n)
! each _ |> make-label(): l |> std/store:insert(rows) { id: seq.next, pos: cnt.n, label: l }
    | row _ |> std/store:stored { seq.next: seq.next + 1 } |> std/store:stored { cnt.n: cnt.n + 1 }
    | full |> _

// Partial update: every 10th row in table order (Main.js:75-80). The guard is
// row-local (legal); the op dispatch is a body-if (forced, see header).
[name(tenth)]std/store:rule(rows)
! row { [row]e, [id]h } when @mod(e.pos, 10) == 0 |> if(op.code == 4)
    | then |> std/store:stored { e.label: "{{ e.label:s }} !!!" } |> Row-repaint-label(key: h, e.label)
    | else |> _

// The op sweep, now only two cases wide. Swap (6) exchanges the pos values of
// the rows at positions op.a/op.b and stashes their HANDLES so the DOM move can
// address the elements it has to reorder; compact (77) closes the pos gap a
// removal left.
//
// Removal used to be the third case here, and it was the expensive one: a full
// sweep comparing every row's id against the clicked one, purely to find a row
// the user had just pointed at. The click carries the row's handle now, so the
// removal addresses it directly and that whole pass is gone.
[name(ops)]std/store:rule(rows)
! row { [row]e, [id]h } |> if(op.code == 6)
    | then |> if(e.pos == op.a)
        | then |> std/store:stored { e.pos: op.b } |> std/store:stored { op.ida: h }
        | else |> if(e.pos == op.b)
            | then |> std/store:stored { e.pos: op.a } |> std/store:stored { op.idb: h }
            | else |> _
    | else |> if(op.code == 77)
            | then |> if(e.pos > op.b)
                | then |> std/store:stored { e.pos: e.pos - 1 }
                | else |> _
            | else |> _

koru/dom:run(title: "Koru-DOM (keyed)")
! click { action } when action == 1 |> clear() |> build(n: 1000)
! click { action } when action == 2 |> clear() |> build(n: 10000)
! click { action } when action == 3 |> build(n: 1000)
! click { action } when action == 4 |> std/store:stored { op.code: 4 } |> std/store:stripe(rows) |> std/store:stored { op.code: 0 }
! click { action } when action == 5 |> clear()
! click { action } when action == 6 |> if(cnt.n > 998)
    | then |> std/store:stored { op.code: 6 } |> std/store:stored { op.a: 1 } |> std/store:stored { op.b: 998 } |> std/store:stripe(rows) |> swap-rows(a: op.ida, b: op.idb) |> std/store:stored { op.code: 0 }
    | else |> _
! click { action, key } when action == 7 |> std/store:stored { op.b: rows[key].pos } |> std/store:take(rows[key])
    | item _ |> std/store:stored { op.code: 77 } |> std/store:stripe(rows) |> std/store:stored { op.code: 0 }
! click { action, key } when action == 8 |> std/store:stored { sel.cur: key }
