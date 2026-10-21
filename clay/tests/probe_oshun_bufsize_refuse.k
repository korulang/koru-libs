// probe_oshun_bufsize_refuse — `bufsize` on an element with no mixed
// values does nothing, so the transform refuses it rather than letting
// it drop silently: the decl stays unconsumed and the compile fails.
import std/store
import std/io
import std/fmt
import std/string
import oshun

[tree]std/store:new(spec, capacity: 64) {
    d: i64, kind: char[8], tx: char[40], ord: i64, hid: i64,
}

oshun:component(seed, spec) {
    <panel>
        <text tx="plain" bufsize="16k"/>
    </panel>
}

seed()
|> std/store:preorder(spec, order: "ord")
    ! preorder { [row]e, [id]h } |> std/io:print.ln("row {{ e.ord:d }}")
