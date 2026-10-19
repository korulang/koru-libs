// probe_ctx_type_refuse — the ONLY `a` in scope is f64; the callee wants
// i64. The mistyped column must not inject; the call stays unfilled and
// refuses through the ordinary missing-input path.
import std/store
import std/io
import std/ctx

std/store:new(inner) { a: f64 }

pub tor want-int { a: i64 }
want-int = std/io:print.ln("unreached")

std/store:stored { inner.a: 1.5 }
|> std/ctx(inner) |> want-int()
