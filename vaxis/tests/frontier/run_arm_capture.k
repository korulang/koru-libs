// FRONTIER — an outer arm binding captured inside a nested
// `! query` subflow, under the `vaxis:run` transform.
//
// The shape KOPIUM's headed.k runs: `! char k` binds k, and a nested
// `std/store:query` arm uses `k` in its subflow body. The subflow's
// generated Input must carry `k` as a captured field — the
// pre-transform run emitted exactly that. The transform rehomes the
// arms onto a generated `vaxis:step()` call; run claims descendants so
// the rehome lands before inner transforms (query's capture then reads
// `char`'s payload type off `step`'s decl, not `run`'s transform
// signature — which declares no `char` branch at all).

import std/io
import std/store
import koru/vaxis

std/store:new(keys, capacity: 4) { ch: 0[i64] }
std/store:insert(keys) { ch: 0 }

koru/vaxis:run(title: "capture-frontier")
! char k |> std/store:query(keys)
    ! query d |> std/store:stored { d.ch: k.ch }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
