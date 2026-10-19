import std/store
import std/io
import std/ctx

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }} b={{ b:d }} c={{ c:d }}")

std/io:print.ln("seed")
|> std/ctx(late) |> ctxprobe()

std/store:new(late) { a: i64, b: i64, c: i64 }
|> std/store:insert(late) { a: 1, b: 2, c: 3 }
