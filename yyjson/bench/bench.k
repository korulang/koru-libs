// bench: std/json:parse (compile-time schema-directed) vs koru/yyjson (DOM).
//
// One document, identical field reads per pass:
//   service (string), port (i64), limits.rps (i64), tags (array len),
//   tls (bool), weight (f64) — unknown keys region/retry/junk are
//   skipped-and-validated by both.
// The acc grid cell keeps the reads observable; it is printed after each arm.

import std/io
import std/json
import koru/yyjson
import std/grid
import std/benchmarking

std/grid:new(acc, size: 1) { n: 0[i64], c: 0[i64], f: 0[f64] }

std/benchmarking:run(seconds: 3)
! pass |> std/json:parse(input: "{\"service\":\"search-api\",\"port\":8443,\"tls\":true,\"weight\":0.75,\"limits\":{\"rps\":1200,\"conns\":5000},\"tags\":[\"prod\",\"us-east\",\"blue\"],\"region\":{\"dc\":\"iad\",\"az\":\"us-east-1a\"},\"retry\":{\"max\":3,\"backoff\":1.5},\"junk\":{\"deep\":[1,2,{\"x\":null}],\"s\":\"pad\"}}")
    | ok { service: string, port: i64, limits: { rps: i64 }, tags: []string, tls: bool, weight: f64 } |> std/grid:stored { acc[0].n: acc[0].n + port + rps } |> std/grid:stored { acc[0].f: acc[0].f + weight } |> if(service == "search-api" and tls and tags.len == 3)
        | then |> std/grid:stored { acc[0].c: acc[0].c + 1 }
| done r |> std/io:print.ln("schema-parse: {{ r.passes:d }} passes in {{ r.seconds:f }}s  acc={{ acc[0].n:d }}/{{ acc[0].c:d }}/{{ acc[0].f:f }}")

std/grid:stored { acc[0].n: 0 }
std/grid:stored { acc[0].c: 0 }
std/grid:stored { acc[0].f: 0 }

std/benchmarking:run(seconds: 3)
! pass |> koru/yyjson:parse(text: "{\"service\":\"search-api\",\"port\":8443,\"tls\":true,\"weight\":0.75,\"limits\":{\"rps\":1200,\"conns\":5000},\"tags\":[\"prod\",\"us-east\",\"blue\"],\"region\":{\"dc\":\"iad\",\"az\":\"us-east-1a\"},\"retry\":{\"max\":3,\"backoff\":1.5},\"junk\":{\"deep\":[1,2,{\"x\":null}],\"s\":\"pad\"}}")
    | err _ |> _
    | ok doc |> koru/yyjson:root(doc): rv |> koru/yyjson:object.get(doc, v: rv, key: "service")
        | not-found |> koru/yyjson:close(doc)
        | found sv |> koru/yyjson:as.borrow(doc, v: sv)
            | wrong-type |> koru/yyjson:close(doc)
            | ok service |> koru/yyjson:object.get(doc, v: rv, key: "port")
                | not-found |> koru/yyjson:close(doc)
                | found pv |> koru/yyjson:as.int(doc, v: pv)
                    | wrong-type |> koru/yyjson:close(doc)
                    | ok port |> koru/yyjson:object.get(doc, v: rv, key: "limits")
                        | not-found |> koru/yyjson:close(doc)
                        | found lv |> koru/yyjson:object.get(doc, v: lv, key: "rps")
                            | not-found |> koru/yyjson:close(doc)
                            | found rpsv |> koru/yyjson:as.int(doc, v: rpsv)
                                | wrong-type |> koru/yyjson:close(doc)
                                | ok rps |> koru/yyjson:object.get(doc, v: rv, key: "tags")
                                    | not-found |> koru/yyjson:close(doc)
                                    | found tv |> koru/yyjson:array.len(doc, v: tv)
                                        | not-an-array |> koru/yyjson:close(doc)
                                        | ok tags |> koru/yyjson:object.get(doc, v: rv, key: "weight")
                                            | not-found |> koru/yyjson:close(doc)
                                            | found wv |> koru/yyjson:as.double(doc, v: wv)
                                                | wrong-type |> koru/yyjson:close(doc)
                                                | ok weight |> koru/yyjson:object.get(doc, v: rv, key: "tls")
                                                    | not-found |> koru/yyjson:close(doc)
                                                    | found bv |> koru/yyjson:as.bool(doc, v: bv)
                                                        | wrong-type |> koru/yyjson:close(doc)
                                                        | ok tls |> std/grid:stored { acc[0].n: acc[0].n + port + rps } |> std/grid:stored { acc[0].f: acc[0].f + weight } |> if(service == "search-api" and tls and tags == 3)
                                                            | then |> std/grid:stored { acc[0].c: acc[0].c + 1 } |> koru/yyjson:close(doc)
| done r |> std/io:print.ln("yyjson-dom:   {{ r.passes:d }} passes in {{ r.seconds:f }}s  acc={{ acc[0].n:d }}/{{ acc[0].c:d }}/{{ acc[0].f:f }}")
