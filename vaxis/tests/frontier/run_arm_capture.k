// FRONTIER REPRO — an outer arm binding captured inside a nested
// `! query` subflow, under the `vaxis:run` transform.
//
// The shape KOPIUM's headed.k runs: `! char k` binds k, and a nested
// `std/store:query` arm uses `k` in its subflow body. The subflow's
// generated Input should carry `k` as a captured field — the
// pre-transform run emitted exactly that. Under the generated
// `vaxis:step()` call site the binding is an arm-pattern name the
// capture pass does not see, and the emitted Zig references bare `k`:
// `use of undeclared identifier 'k'` at backend build.

import std/io
import std/store
import koru/vaxis

std/store:new(keys, capacity: 4) { ch: 0[i64] }

koru/vaxis:run(title: "capture-frontier")
! char k |> std/store:query(keys)
    ! query d |> std/io:print.ln("saw {{ k.ch:d }}")
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
