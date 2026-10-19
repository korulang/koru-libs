// probe_ctx_local — ctx scope declared INSIDE a tor's own body.
// If the transform's walk reaches impl bodies, local()'s inner ctx
// scope injects into the nested ctxprobe call.
import std/store
import std/io
import std/ctx

std/store:new(inner) { a: i64, b: i64, c: i64 }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }} b={{ b:d }} c={{ c:d }}")

pub tor local { }
local = std/ctx(inner) |> ctxprobe()

std/io:print.ln("seed")
|> std/store:stored { inner.a: 9, inner.b: 8, inner.c: 7 }
|> local()
