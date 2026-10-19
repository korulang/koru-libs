// probe_ctx — consumer-side falsifier for std/ctx lexical injection.
// Expected: a=1 b=2 c=3 (all outer), then a=9 shadow + b,c from outer,
// then a=9, b=42 explicit wins over both scopes, c=3.
import std/store
import std/io
import std/ctx

std/store:new(outer) { a: i64, b: i64, c: i64 }
std/store:new(inner) { a: i64 }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }} b={{ b:d }} c={{ c:d }}")

std/io:print.ln("seed")
|> std/store:stored { outer.a: 1, outer.b: 2, outer.c: 3 }
|> std/store:stored { inner.a: 9 }
|> std/ctx(outer) |> ctxprobe()
|> std/ctx(inner) |> ctxprobe()
|> ctxprobe(b: 42)
