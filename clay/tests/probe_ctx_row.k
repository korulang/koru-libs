// probe_ctx_row — ctx scope over a ROW of a capacity-N store:
// std/ctx(outer[r]) should emit row-subscript reads, and switching the
// handle should re-point the scope.
import std/store
import std/io
import std/ctx

std/store:new(outer, capacity: 8) { a: i64, b: i64, c: i64 }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }} b={{ b:d }} c={{ c:d }}")

std/store:insert(outer) { a: 1, b: 2, c: 3 }
| row r0 |> std/store:insert(outer) { a: 10, b: 20, c: 30 }
    | row r1 |> std/io:print.ln("seed")
        |> std/ctx(outer[r0]) |> ctxprobe()
        |> std/ctx(outer[r1]) |> ctxprobe()
