// probe_ctx_fail — ctx scope that can't fill: inner provides only `a`,
// b and c stay unfilled → ordinary missing-param refusal.
import std/store
import std/io
import libs/ui

std/store:new(inner) { a: i64 }

std/io:print.ln("seed")
|> std/store:stored { inner.a: 9 }
|> libs/ui:ctx(inner) |> libs/ui:ctxprobe()
