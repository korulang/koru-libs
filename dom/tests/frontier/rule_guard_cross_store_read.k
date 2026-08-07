// FRONTIER REPRO — a CROSS-STORE singleton read in a rule arm's `when` GUARD
// is spliced as its raw surface text, BOTH lanes:
//
//   --lang=js:    if (!(op.code == 1)) return;   -> ReferenceError: op is not defined
//   koruc run:    error: use of undeclared identifier 'op'   (emitted Zig)
//
// The store objects are named __koru_store_op / __koru_store_rows in both
// emissions; the guard path never applies the rename. The SAME read lowers
// correctly in an insert literal (690_192), in a body-if condition, and in a
// fmt interpolation — the guard is the one position that misses.
//
// Sibling of 690_013 (cross-store guard closure, aspirational): that pin is
// about REACTIVITY (writes to the guarded store firing nothing); this one is
// earlier — the read does not even lower. Row-LOCAL guards (`when e.pos ==
// 0`, `when @mod(e.pos, 10) == 0`) lower fine on both lanes.
//
// Why it matters: op dispatch ("this sweep is a clear, that one a swap") is
// naturally a guard on an op register. The round-2 vehicle dispatches in
// body-ifs instead, which lower the same read correctly.

import std/io
import std/store

std/store:new(rows, capacity: 4) { id: i64 }
std/store:new(op) { code: 1[i64] }

std/store:insert(rows) { id: 7 }

std/store:rule(rows)
! row e when op.code == 1 |> std/io:print.ln("hit {{ e.id:d }}")
