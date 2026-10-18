// Store-scan unit-cost probe — how much does one row-visit cost?
// Three runs: (1) a bare sweep over spec — pure row-visit + one stored
// write; (2) the nested shape the walk uses — an inner query inside a
// query body, guarded so it early-rejects — the per-(outer,inner) cost;
// (3) an empty pass — harness floor. The walk's cost decomposes into
// these units; the question is whether the unit is slow or the count
// is large.
import std/store
import std/io
import std/benchmarking

std/store:new(spec, capacity: 64) { d: i64, kind: char[8], v: i64 }
std/store:new(scratch) { n: 0[i64] }

std/store:insert(spec) { d: 0, kind: "dock", v: 0 }
    | row _ |> std/store:insert(spec) { d: 1, kind: "leaf", v: 1 }
        | row _ |> std/store:insert(spec) { d: 1, kind: "stack", v: 2 }
            | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", v: 3 }
                | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", v: 4 }
                    | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", v: 5 }
                        | row _ |> std/store:insert(spec) { d: 0, kind: "dock", v: 6 }
                            | row _ |> std/store:insert(spec) { d: 1, kind: "leaf", v: 7 }
                                | row _ |> std/store:insert(spec) { d: 1, kind: "stack", v: 8 }
                                    | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", v: 9 }
                                        | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", v: 10 }
                                            | row _ |> std/store:insert(spec) { d: 0, kind: "grid", v: 11 }
                                                | row _ |> std/store:insert(spec) { d: 1, kind: "col", v: 12 }
                                                    | row _ |> std/store:insert(spec) { d: 1, kind: "col", v: 13 }
                                                        | row _ |> std/store:insert(spec) { d: 1, kind: "row", v: 14 }
                                                            | row _ |> std/store:insert(spec) { d: 1, kind: "row", v: 15 }
                                                                | row _ |> std/store:insert(spec) { d: 1, kind: "row", v: 16 }
                                                                    | row _ |> std/store:insert(spec) { d: 1, kind: "cell", v: 17 }
                                                                        | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", v: 18 }
                                                                            | row _ |> std/store:insert(spec) { d: 2, kind: "leaf", v: 19 }
                                                                                | row _ |> std/store:insert(spec) { d: 1, kind: "cell", v: 20 }
                                                                                    | row _ |> std/store:insert(spec) { d: 1, kind: "cell", v: 21 }
                                                                                        | row _ |> std/store:insert(spec) { d: 1, kind: "cell", v: 22 }
                                                                                            | row _ |> std/store:insert(spec) { d: 1, kind: "cell", v: 23 }
                                                                                                | row _ |> std/store:insert(spec) { d: 1, kind: "cell", v: 24 }

std/benchmarking:run(seconds: 2)
    ! pass |> std/store:query(spec)
        ! query s |> std/store:stored { scratch.n: s.d }
    | done d |> std/io:print.ln("bare scan (25 rows): {{ d.seconds * 1000000.0 / @as(f64, @floatFromInt(d.passes)):f }}us")
        |> std/benchmarking:run(seconds: 2)
            ! pass |> std/store:query(spec)
                ! query s |> std/store:query(spec)
                    ! query t when t.v == s.d |> std/store:stored { scratch.n: t.v }
            | done e |> std/io:print.ln("nested scan (25x25): {{ e.seconds * 1000000.0 / @as(f64, @floatFromInt(e.passes)):f }}us")
                |> std/benchmarking:run(seconds: 2)
                    ! pass |> std/store:stored { scratch.n: scratch.n + 1 }
                    | done f |> std/io:print.ln("harness floor: {{ f.seconds * 1000000.0 / @as(f64, @floatFromInt(f.passes)):f }}us")
