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
// Shapes forced by pinned JS-lane walls (reproductions in dom/tests/frontier/):
//   - `sweep`/`clear` wrap `stripe` terminally in a tor body because a chain
//     NEVER survives past stripe() — the tail is silently dropped, BOTH lanes
//     (stripe_swallows_chain_tail.k). Round-1 walls 1-4 still stand.
//   - rule arms bind row reads FIRST (`echo(v: e.pos): p`) because a row
//     read inside a nested if CONDITION emits the raw binding name `e.pos`
//     into the JS output (rule_row_read_in_nested_if_condition_js.k) —
//     the bind-first idiom of 320_128, forced rather than chosen.
//   - op dispatch lives in body-`if`s, not `when` guards, because a
//     cross-store singleton read in a rule GUARD emits the bare store name
//     (`op.code`, unrenamed) into the JS output
//     (rule_guard_cross_store_read_js.k). Row-local guards lower fine.
//   - mark/swapdom forward through Koru tors before any |js body, because a
//     row read passed straight to a |js-bodied proc splices the Zig read
//     (round-1 wall 3, rule_row_read_call_arg_js.k).
//   - std/grid has NO JS lowering (grid_write_no_js_lowering.k), so the
//     position index is the `pos` column, not a grid of handles.
//
// The label still cannot live in the store (string columns are refused by
// KORU161; char[N] has no JS lowering — round-1 wall 2), so it is minted at
// insert and updated in place by mark-row; the store selects WHICH rows.

import std/store
import std/control
import koru/dom

// The krausest row (vanillajs Main.js:7-9), as markup Koru compiles: the
// static structure becomes a module-level <template> built once, the
// {{ id:d }} / {{ label:s }} placeholders become the typed input of the
// synthesized `Row` event, and every lowercase tag passes through untouched
// (ruled 2026-08-07: capital = ours, anything else is not inspected).
koru/dom:component(Row) {
    <tr data-id={{ id:d }}>
        <td class="col-md-1">{{ id:d }}</td>
        <td class="col-md-4"><a data-action="8" data-id={{ id:d }}>{{ label:s }}</a></td>
        <td class="col-md-1"><a data-action="7" data-id={{ id:d }}><span class="glyphicon glyphicon-remove" aria-hidden="true"></span></a></td>
        <td class="col-md-6"></td>
    </tr>
}

// The row's HANDLE is what ties the store's row to the element painted for
// it: `[id]h` on both lifecycle arms is the same value, and it survives the
// swap-remove that moves a row between slots. So the component is keyed on it
// at birth and the library is told to let go of it at death — neither side
// ever searches the page for a row.
std/store:new(rows, capacity: 16384) { id: i64, pos: i64 }
! inserted { id, [id]h } |> make-label(): l |> Row(parent: "#tbody", key: h, id, label: l)
! removed { [id]h } |> koru/dom:drop(key: h) |> std/store:stored { cnt.n: cnt.n - 1 }

std/store:new(seq) { next: 1[i64] }
std/store:new(cnt) { n: 0[i64] }
std/store:new(op) { code: 0[i64], a: 0[i64], b: 0[i64], ida: 0[i64], idb: 0[i64] }
std/store:new(sel) { cur: 0[i64] }

std/store:watch(sel)
! cur c |> select-row(id: c)

pub tor make-label {} -> string
pub tor select-row { id: i64 }
pub tor mark-row { id: i64 }
pub tor swap-rows { a: i64, b: i64 }

tor mark { id: i64 }
mark = mark-row(id)

tor swapdom { a: i64, b: i64 }
swapdom = swap-rows(a, b)

tor echo { v: i64 } -> i64
echo -> v

tor sweep {}
sweep = std/store:stripe(rows)

tor clear {}
clear = std/store:stored { op.code: 5 } |> sweep() |> std/store:stored { op.code: 0 }

tor build { n: i64 }

build = for(0..n)
! each _ |> std/store:insert(rows) { id: seq.next, pos: cnt.n }
    | row _ |> std/store:stored { seq.next: seq.next + 1 } |> std/store:stored { cnt.n: cnt.n + 1 }
    | full |> _

// Partial update: every 10th row in table order (Main.js:75-80). The guard is
// row-local (legal); the op dispatch is a body-if (forced, see header).
[name(tenth)]std/store:rule(rows)
! row e when @mod(e.pos, 10) == 0 |> if(op.code == 4)
    | then |> mark(e.id)
    | else |> _

// The op sweep: clear (5) takes every row; swap (6) exchanges the pos values
// of the rows at positions op.a/op.b and stashes their ids for the DOM move;
// remove (7) takes the row with id op.a and stashes its pos; compact (77)
// closes the pos gap the remove left.
[name(ops)]std/store:rule(rows)
! row e |> echo(v: e.pos): p |> echo(v: e.id): rid |> if(op.code == 5)
    | then |> std/store:take(rows[e])
        | item _ |> _
    | else |> if(op.code == 6)
        | then |> if(p == op.a)
            | then |> std/store:stored { e.pos: op.b } |> std/store:stored { op.ida: rid }
            | else |> if(p == op.b)
                | then |> std/store:stored { e.pos: op.a } |> std/store:stored { op.idb: rid }
                | else |> _
        | else |> if(op.code == 7)
            | then |> if(rid == op.a)
                | then |> std/store:stored { op.b: p } |> std/store:take(rows[e])
                    | item _ |> _
                | else |> _
            | else |> if(op.code == 77)
                | then |> if(p > op.b)
                    | then |> std/store:stored { e.pos: p - 1 }
                    | else |> _
                | else |> _

koru/dom:run(title: "Koru-DOM (keyed)")
! click { action } when action == 1 |> clear() |> build(n: 1000)
! click { action } when action == 2 |> clear() |> build(n: 10000)
! click { action } when action == 3 |> build(n: 1000)
! click { action } when action == 4 |> std/store:stored { op.code: 4 } |> sweep() |> std/store:stored { op.code: 0 }
! click { action } when action == 5 |> clear()
! click { action } when action == 6 |> if(cnt.n > 998)
    | then |> std/store:stored { op.code: 6 } |> std/store:stored { op.a: 1 } |> std/store:stored { op.b: 998 } |> sweep() |> swapdom(a: op.ida, b: op.idb) |> std/store:stored { op.code: 0 }
    | else |> _
! click { action, id } when action == 7 |> std/store:stored { op.code: 7 } |> std/store:stored { op.a: id } |> sweep() |> std/store:stored { op.code: 77 } |> sweep() |> std/store:stored { op.code: 0 }
! click { action, id } when action == 8 |> std/store:stored { sel.cur: id }
