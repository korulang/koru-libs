// probe_ctx_type — same field name, different types across two scopes.
// inner.a is f64, outer.a is i64. Pins typed matching: a callee wanting
// i64 skips the mistyped inner shadow and answers from outer; a callee
// wanting f64 takes inner.a. Neither scope "wins" the name — the
// innermost COMPATIBLE scope wins.

import std/store
import std/io
import std/ctx

std/store:new(outer) { a: i64, b: i64 }
std/store:new(inner) { a: f64 }

pub tor want-int { a: i64, b: i64 }
want-int = std/io:print.ln("want-int a={{ a:d }} b={{ b:d }}")

pub tor want-float { a: f64 }
want-float = std/io:print.ln("want-float a={{ a:f }}")

std/store:stored { outer.a: 7, outer.b: 8 }
|> std/store:stored { inner.a: 1.5 }
|> std/ctx(outer) |> std/ctx(inner) |> want-int()
|> want-float()
