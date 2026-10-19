// probe_ctx_trans — transitivity: a call-site ctx scope crosses the subflow
// boundary via keyed clone specialization. needs-scope's body calls
// ctxprobe() unfilled; called under ctx(inner) it is cloned to
// needs-scope__ctx_inner whose body's call is injected from the scope.
import std/store
import std/io
import std/ctx

std/store:new(inner) { a: i64, b: i64, c: i64 }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }} b={{ b:d }} c={{ c:d }}")

pub tor needs-scope { }
needs-scope = ctxprobe()

std/io:print.ln("seed")
|> std/store:stored { inner.a: 9, inner.b: 8, inner.c: 7 }
|> std/ctx(inner) |> needs-scope()
