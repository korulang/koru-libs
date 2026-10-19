// bench_ctx — the zero-cost claim for std/ctx, measured three ways.
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
//   ROW — subscript:     ctx(rows[h0]) |> probe-r(c: @as(i64, @intCast(k))) → a,b via rows[h0]
//
// VAR arms — the un-hoistable case: the scope's row handle itself
// alternates per iteration (even k → h0, odd k → h1), so every call pays
// a real resolve + row load that cannot fold. The comparison that
// matters is not lit-vs-ctx — literals can't index — it is hand-written
// vs injected:
//   VAR-HAND — if even: probe-r(a: rows[h0].a, ...) else rows[h1]...
//   VAR-CTX  — if even: ctx(rows[h0]) |> probe-r(...) else ctx(rows[h1])...
// If VAR-CTX's emitted code is identical to VAR-HAND's, injection is free
// even at the indirection level — the scope is literally the spelling of
// the read.
//
// Gate: acc checksums — fold arms must equal passes × K × 6 exactly;
// VAR-HAND/VAR-CTX fold the same row-value sequence, so equal pass
// counts give equal acc; emitted-code diff verifies identical arg text.
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

std/store:insert(rows) { a: 11, b: 12, c: 3 }
    | row h0 |> std/store:insert(rows) { a: 21, b: 22, c: 3 }
        | row h1 |> std/benchmarking:run(seconds: 2)
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
                            ! pass |> std/ctx(rows[h0]) |> for(0..2000)
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
                                                    ! pass |> std/ctx(rows[h0]) |> for(0..2000)
                                                        ! each k |> probe-r(c: @as(i64, @intCast(k)))
                                                    | done m |> std/io:print.ln("real-row {{ m.seconds * 1000000000.0 / @as(f64, @floatFromInt(m.passes)) / 2000.0:f }}ns/call passes={{ m.passes:d }} acc={{ acc.n:d }}")
                                                        |> std/store:stored { acc.n: 0 }
                                                        |> std/benchmarking:run(seconds: 2)
                                                            ! pass |> for(0..2000)
                                                                ! each k |> if (@mod(@as(i64, @intCast(k)), 2) == 0)
                                                                    | then |> probe-r(a: rows[h0].a, b: rows[h0].b, c: @as(i64, @intCast(k)))
                                                                    | else |> probe-r(a: rows[h1].a, b: rows[h1].b, c: @as(i64, @intCast(k)))
                                                            | done p |> std/io:print.ln("var-hand {{ p.seconds * 1000000000.0 / @as(f64, @floatFromInt(p.passes)) / 2000.0:f }}ns/call passes={{ p.passes:d }} acc={{ acc.n:d }}")
                                                                |> std/store:stored { acc.n: 0 }
                                                                |> std/benchmarking:run(seconds: 2)
                                                                    ! pass |> for(0..2000)
                                                                        ! each k |> if (@mod(@as(i64, @intCast(k)), 2) == 0)
                                                                            | then |> std/ctx(rows[h0]) |> probe-r(c: @as(i64, @intCast(k)))
                                                                            | else |> std/ctx(rows[h1]) |> probe-r(c: @as(i64, @intCast(k)))
                                                                    | done q |> std/io:print.ln("var-ctx {{ q.seconds * 1000000000.0 / @as(f64, @floatFromInt(q.passes)) / 2000.0:f }}ns/call passes={{ q.passes:d }} acc={{ acc.n:d }}")
