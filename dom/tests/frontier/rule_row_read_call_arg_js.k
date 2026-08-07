// FRONTIER REPRO — a rule arm's row-binding column read (`e.id`), passed as
// a call argument to a |JS-IMPLEMENTED proc, emits the ZIG read expression
// into the JavaScript output.
//
// `koruc <this file> --lang=js` emits, into output_emitted.js:
//     const id = (&__koru_store_rows.id)[@as(usize, @intCast(__koru_sdix_rule_L*))];
// — not JavaScript; the browser dies at `Unexpected token '&'`.
//
// The boundary, probed to one variable (2026-08-07):
//   - callee is a KORU SUBFLOW            → JS-correct read
//     (`(__koru_store_rows.id)[((__koru_sdix_rule_L*))]`)
//   - read in a fmt INTERPOLATION         → JS-correct read (690_005's qbody)
//   - callee is a |js PROC (host splice)  → ZIG read spliced (this file)
// So the parameter binding rendered for an opaque host-body splice is the one
// path that renders the row read with the Zig lowering under --lang=js.
//
// The JS-clean spelling of the same semantic is the `inserted` lifecycle
// interceptor (690_041), which threads column VALUES as payload — that is
// what dom/app/main.k ships on. This repro pins the rule-side gap.
// Companion |js facet: rule_row_read_call_arg_js.kjs.

import std/store

std/store:new(rows, capacity: 8) { id: i64 }

std/store:rule(rows)
! row e |> mk(): l |> show(e.id, label: l)

pub tor mk {} -> string
pub tor show { id: i64, label: string }

std/store:insert(rows) { id: 41 }
