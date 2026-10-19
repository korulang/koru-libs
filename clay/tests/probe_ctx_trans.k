// probe_ctx_trans — the documented boundary: a call-site ctx scope does
// NOT reach into the callee's own body. needs-scope's inner ctxprobe()
// is lexically outside the ctx subtree, so a/b/c stay unfilled -> KORU080.
import std/store
import std/io
import std/ctx

std/store:new(inner) { a: i64, b: i64, c: i64 }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("unreached")

pub tor needs-scope { }
needs-scope = ctxprobe()

std/io:print.ln("seed")
|> std/store:stored { inner.a: 9, inner.b: 8, inner.c: 7 }
|> std/ctx(inner) |> needs-scope()
