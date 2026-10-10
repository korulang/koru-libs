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

// Round trip, one shot each — print both outputs to eyeball equality.
std/json:parse(input: "{\"service\":\"search-api\",\"port\":8443,\"tls\":true,\"weight\":0.75,\"limits\":{\"rps\":1200,\"conns\":5000},\"tags\":[\"prod\",\"us-east\",\"blue\"],\"region\":{\"dc\":\"iad\",\"az\":\"us-east-1a\"},\"retry\":{\"max\":3,\"backoff\":1.5},\"junk\":{\"deep\":[1,2,{\"x\":null}],\"s\":\"pad\"}}")
| malformed { message, offset } |> std/io:print.ln("parse fail {{ offset:d }}: {{ message:s }}")
| ok { service: string, port: i64, limits: { rps: i64 }, tls: bool, weight: f64 }
    |> std/json:emit(value: { service, port, limits: { rps }, tls, weight }): body
    |> std/io:print.ln("schema: {{ body:s }}")
    |> std/json:emit.free(text: body)

koru/yyjson:parse(text: "{\"service\":\"search-api\",\"port\":8443,\"tls\":true,\"weight\":0.75,\"limits\":{\"rps\":1200,\"conns\":5000},\"tags\":[\"prod\",\"us-east\",\"blue\"],\"region\":{\"dc\":\"iad\",\"az\":\"us-east-1a\"},\"retry\":{\"max\":3,\"backoff\":1.5},\"junk\":{\"deep\":[1,2,{\"x\":null}],\"s\":\"pad\"}}")
| err _ |> _
| ok doc |> koru/yyjson:root(doc): rv
    |> koru/yyjson:object.get(doc, v: rv, key: "service")
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
                                | ok rps |> koru/yyjson:object.get(doc, v: rv, key: "weight")
                                    | not-found |> koru/yyjson:close(doc)
                                    | found wv |> koru/yyjson:as.double(doc, v: wv)
                                        | wrong-type |> koru/yyjson:close(doc)
                                        | ok weight |> koru/yyjson:object.get(doc, v: rv, key: "tls")
                                            | not-found |> koru/yyjson:close(doc)
                                            | found bv |> koru/yyjson:as.bool(doc, v: bv)
                                                | wrong-type |> koru/yyjson:close(doc)
                                                | ok tls |> koru/yyjson:build(): b
                                                    |> koru/yyjson:new.object(doc: b): obj
                                                    |> koru/yyjson:new.string(doc: b, text: service): sn |> koru/yyjson:object.set(doc: b, v: obj, key: "service", value: sn)
                                                    |> koru/yyjson:new.int(doc: b, value: port): pn |> koru/yyjson:object.set(doc: b, v: obj, key: "port", value: pn)
                                                    |> koru/yyjson:new.object(doc: b): lim |> koru/yyjson:new.int(doc: b, value: rps): rn |> koru/yyjson:object.set(doc: b, v: lim, key: "rps", value: rn) |> koru/yyjson:object.set(doc: b, v: obj, key: "limits", value: lim)
                                                    |> koru/yyjson:new.bool(doc: b, value: tls): bn |> koru/yyjson:object.set(doc: b, v: obj, key: "tls", value: bn)
                                                    |> koru/yyjson:new.double(doc: b, value: weight): wn |> koru/yyjson:object.set(doc: b, v: obj, key: "weight", value: wn)
                                                    |> koru/yyjson:root.set(doc: b, v: obj)
                                                    |> koru/yyjson:render(doc: b)
                                                        | ok body |> std/io:print.ln("yyjson: {{ body:s }}") |> koru/yyjson:render.free(text: body) |> koru/yyjson:build.close(doc: b) |> koru/yyjson:close(doc)
                                                        | err _ |> koru/yyjson:build.close(doc: b) |> koru/yyjson:close(doc)

// Write-side arms: full round trip per pass — parse the same document,
// emit the same 5-field object (service/port/limits.rps/tls/weight),
// consume the produced bytes observably.
std/grid:stored { acc[0].n: 0 }
std/grid:stored { acc[0].c: 0 }
std/grid:stored { acc[0].f: 0 }

std/benchmarking:run(seconds: 3)
! pass |> std/json:parse(input: "{\"service\":\"search-api\",\"port\":8443,\"tls\":true,\"weight\":0.75,\"limits\":{\"rps\":1200,\"conns\":5000},\"tags\":[\"prod\",\"us-east\",\"blue\"],\"region\":{\"dc\":\"iad\",\"az\":\"us-east-1a\"},\"retry\":{\"max\":3,\"backoff\":1.5},\"junk\":{\"deep\":[1,2,{\"x\":null}],\"s\":\"pad\"}}")
    | malformed { message, offset } |> std/io:print.ln("parse fail {{ offset:d }}: {{ message:s }}")
    | ok { service: string, port: i64, limits: { rps: i64 }, tls: bool, weight: f64 }
        |> std/json:emit(value: { service, port, limits: { rps }, tls, weight }): body
        |> std/grid:stored { acc[0].n: acc[0].n + port + rps } |> std/grid:stored { acc[0].f: acc[0].f + weight } |> if(body.len == 83)
            | then |> std/grid:stored { acc[0].c: acc[0].c + 1 } |> std/json:emit.free(text: body)
            | else |> std/json:emit.free(text: body)
| done r |> std/io:print.ln("schema-rt:    {{ r.passes:d }} passes in {{ r.seconds:f }}s  acc={{ acc[0].n:d }}/{{ acc[0].c:d }}/{{ acc[0].f:f }}")

std/grid:stored { acc[0].n: 0 }
std/grid:stored { acc[0].c: 0 }
std/grid:stored { acc[0].f: 0 }

std/benchmarking:run(seconds: 3)
! pass |> koru/yyjson:parse(text: "{\"service\":\"search-api\",\"port\":8443,\"tls\":true,\"weight\":0.75,\"limits\":{\"rps\":1200,\"conns\":5000},\"tags\":[\"prod\",\"us-east\",\"blue\"],\"region\":{\"dc\":\"iad\",\"az\":\"us-east-1a\"},\"retry\":{\"max\":3,\"backoff\":1.5},\"junk\":{\"deep\":[1,2,{\"x\":null}],\"s\":\"pad\"}}")
    | err _ |> _
    | ok doc |> koru/yyjson:root(doc): rv
        |> koru/yyjson:object.get(doc, v: rv, key: "service")
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
                                    | ok rps |> koru/yyjson:object.get(doc, v: rv, key: "weight")
                                        | not-found |> koru/yyjson:close(doc)
                                        | found wv |> koru/yyjson:as.double(doc, v: wv)
                                            | wrong-type |> koru/yyjson:close(doc)
                                            | ok weight |> koru/yyjson:object.get(doc, v: rv, key: "tls")
                                                | not-found |> koru/yyjson:close(doc)
                                                | found bv |> koru/yyjson:as.bool(doc, v: bv)
                                                    | wrong-type |> koru/yyjson:close(doc)
                                                    | ok tls |> koru/yyjson:build(): b
                                                        |> koru/yyjson:new.object(doc: b): obj
                                                        |> koru/yyjson:new.string(doc: b, text: service): sn |> koru/yyjson:object.set(doc: b, v: obj, key: "service", value: sn)
                                                        |> koru/yyjson:new.int(doc: b, value: port): pn |> koru/yyjson:object.set(doc: b, v: obj, key: "port", value: pn)
                                                        |> koru/yyjson:new.object(doc: b): lim |> koru/yyjson:new.int(doc: b, value: rps): rn |> koru/yyjson:object.set(doc: b, v: lim, key: "rps", value: rn) |> koru/yyjson:object.set(doc: b, v: obj, key: "limits", value: lim)
                                                        |> koru/yyjson:new.bool(doc: b, value: tls): bn |> koru/yyjson:object.set(doc: b, v: obj, key: "tls", value: bn)
                                                        |> koru/yyjson:new.double(doc: b, value: weight): wn |> koru/yyjson:object.set(doc: b, v: obj, key: "weight", value: wn)
                                                        |> koru/yyjson:root.set(doc: b, v: obj)
                                                        |> koru/yyjson:render(doc: b)
                                                            | err _ |> koru/yyjson:build.close(doc: b) |> koru/yyjson:close(doc)
                                                            | ok body |> std/grid:stored { acc[0].n: acc[0].n + port + rps } |> std/grid:stored { acc[0].f: acc[0].f + weight } |> if(body.len == 83)
                                                                | then |> std/grid:stored { acc[0].c: acc[0].c + 1 } |> koru/yyjson:render.free(text: body) |> koru/yyjson:build.close(doc: b) |> koru/yyjson:close(doc)
                                                                | else |> koru/yyjson:render.free(text: body) |> koru/yyjson:build.close(doc: b) |> koru/yyjson:close(doc)
| done r |> std/io:print.ln("yyjson-rt:    {{ r.passes:d }} passes in {{ r.seconds:f }}s  acc={{ acc[0].n:d }}/{{ acc[0].c:d }}/{{ acc[0].f:f }}")
