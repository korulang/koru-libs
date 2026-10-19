// bench_ctx — the zero-cost claim for std/ctx, measured two ways.
//
// The claim under test: an injected argument is a compile-time arg fill —
// the emitted call reads a store cell directly — so ctx(outer) |> probe()
// should cost the same per call as probe(a: 1, b: 2, c: 3).
//
// FOLD arms (probe): acc += a + b + c with constant args — the closed
// form. If ctx injection were a runtime mechanism, the foldable arm could
// not fold; LLVM folding the injected reads to the same residue as the
// literals IS the zero-cost receipt, and the exact checksums prove the
// fold stayed semantically correct.
//
// REAL arms (probe-r): acc = acc*31 + a + b + c, c = k — a serial
// dependence chain plus a per-iteration varying arg, so the calls must
// actually run. Here the ns/call delta isolates arg provenance:
//   LIT — literals:      probe-r(a: 1, b: 2, c: @as(i64, @intCast(k)))
//   CTX — whole store:   ctx(outer) |> probe-r(c: @as(i64, @intCast(k)))   → a,b injected
//   ROW — subscript:     ctx(rows[r]) |> probe-r(c: @as(i64, @intCast(k))) → a,b via rows[r]
//
// Gate: every arm's acc checksum is recomputed and must match its peers
// — lit and ctx arms must agree, proving the bench reads the same values
// both ways.
import std/store
import std/io
import std/benchmarking
import std/ctx

std/store:new(outer) { a: 1[i64], b: 2[i64], c: 3[i64] }
std/store:new(rows, capacity: 8) { a: i64, b: i64, c: i64 }
std/store:new(acc) { n: 0[i64] }

pub tor probe { a: i64, b: i64, c: i64 }
probe = std/store:stored { acc.n: acc.n + a + b + c }

pub tor probe-r { a: i64, b: i64, c: i64 }
probe-r = std/store:stored { acc.n: acc.n * 31 + a + b + c }

std/store:insert(rows) { a: 1, b: 2, c: 3 }
    | row r |> std/benchmarking:run(seconds: 2)
        ! pass |> for(0..2000)
            ! each _ |> probe(a: 1, b: 2, c: 3)
        | done d |> std/io:print.ln("fold-lit {{ d.seconds * 1000000000.0 / @as(f64, @floatFromInt(d.passes)) / 2000.0:f }}ns/call passes={{ d.passes:d }} acc={{ acc.n:d }}")
            |> std/store:stored { acc.n: 0 }
            |> std/benchmarking:run(seconds: 2)
                ! pass |> std/ctx(outer) |> for(0..2000)
                    ! each _ |> probe()
                | done e |> std/io:print.ln("fold-ctx {{ e.seconds * 1000000000.0 / @as(f64, @floatFromInt(e.passes)) / 2000.0:f }}ns/call passes={{ e.passes:d }} acc={{ acc.n:d }}")
                    |> std/store:stored { acc.n: 0 }
                    |> std/benchmarking:run(seconds: 2)
                        ! pass |> std/ctx(rows[r]) |> for(0..2000)
                            ! each _ |> probe()
                        | done f |> std/io:print.ln("fold-row {{ f.seconds * 1000000000.0 / @as(f64, @floatFromInt(f.passes)) / 2000.0:f }}ns/call passes={{ f.passes:d }} acc={{ acc.n:d }}")
                            |> std/store:stored { acc.n: 0 }
                            |> std/benchmarking:run(seconds: 2)
                                ! pass |> for(0..2000)
                                    ! each k |> probe-r(a: 1, b: 2, c: @as(i64, @intCast(k)))
                                | done g |> std/io:print.ln("real-lit {{ g.seconds * 1000000000.0 / @as(f64, @floatFromInt(g.passes)) / 2000.0:f }}ns/call passes={{ g.passes:d }} acc={{ acc.n:d }}")
                                    |> std/store:stored { acc.n: 0 }
                                    |> std/benchmarking:run(seconds: 2)
                                        ! pass |> std/ctx(outer) |> for(0..2000)
                                            ! each k |> probe-r(c: @as(i64, @intCast(k)))
                                        | done h |> std/io:print.ln("real-ctx {{ h.seconds * 1000000000.0 / @as(f64, @floatFromInt(h.passes)) / 2000.0:f }}ns/call passes={{ h.passes:d }} acc={{ acc.n:d }}")
                                            |> std/store:stored { acc.n: 0 }
                                            |> std/benchmarking:run(seconds: 2)
                                                ! pass |> std/ctx(rows[r]) |> for(0..2000)
                                                    ! each k |> probe-r(c: @as(i64, @intCast(k)))
                                                | done m |> std/io:print.ln("real-row {{ m.seconds * 1000000000.0 / @as(f64, @floatFromInt(m.passes)) / 2000.0:f }}ns/call passes={{ m.passes:d }} acc={{ acc.n:d }}")
