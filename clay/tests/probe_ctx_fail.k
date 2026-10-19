// probe_ctx_fail — ctx scope that can't fill: inner provides only `a`,
// b and c stay unfilled → ordinary missing-param refusal.
import std/store
import std/io
import std/ctx

std/store:new(inner) { a: i64 }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("unreached")

std/io:print.ln("seed")
|> std/store:stored { inner.a: 9 }
|> std/ctx(inner) |> ctxprobe()
