// refuse probe — mixed value on an i64 column must leave the decl
// unconsumed: loud refusal, not silent stringify.
import std/store
import std/io
import std/fmt
import std/string
import oshun

[tree]std/store:new(spec, capacity: 64) {
    d: i64, kind: char[8], tx: char[40], ord: i64, hid: i64,
}

oshun:component(seed, spec) {
    <panel ord="o_{{ n:d }}"/>
}

seed(n: 42)
|> std/store:preorder(spec, order: "ord")
    ! preorder { [row]e, [id]h } |> std/io:print.ln("{{ e.ord:d }}")
