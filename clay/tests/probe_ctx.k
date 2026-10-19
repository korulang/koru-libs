// probe_ctx — falsifier for libs/ctx lexical injection.
// Expected: a=1 b=2 c=3 (all outer), then a=9 shadow + b,c from outer,
// then a=9, b=42 explicit wins over both scopes, c=3.
import std/store
import std/io
import libs/ctx

std/store:new(outer) { a: i64, b: i64, c: i64 }
std/store:new(inner) { a: i64 }

std/io:print.ln("seed")
|> std/store:stored { outer.a: 1, outer.b: 2, outer.c: 3 }
|> std/store:stored { inner.a: 9 }
|> libs/ctx(outer) |> libs/ctx:ctxprobe()
|> libs/ctx(inner) |> libs/ctx:ctxprobe()
|> libs/ctx:ctxprobe(b: 42)
