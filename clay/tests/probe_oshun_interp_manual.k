// probe_oshun_interp_manual — hand-written version of what a mixed
// `tx="clicks: {{ n:s }}"` row should emit. fmt:ln binds scratch text,
// from-page+take copies out an owned String, the insert writes v.data
// into char[40] (runtime bytes truncate per 690_052), free discharges.
// If this compiles and prints, the transform's job is emitting it.
import std/store
import std/io
import std/fmt
import std/string

[tree]std/store:new(spec, capacity: 64) {
    d: i64, kind: char[8], tx: char[40], ord: i64, hid: i64,
}

pub tor seed { n: i64 }
seed = std/fmt:ln("clicks: {{ n:d }}"): f
    |> std/string:from-page(f.text)
    | ok s |> std/string:take(s): v
        |> std/store:insert(spec) { d: 0, kind: "text", tx: v.data, ord: 0, hid: 0 }
        | row _ |> std/string:free(s: v)
    | err _ |> _

seed(n: 42)
|> std/store:preorder(spec, order: "ord")
    ! preorder { [row]e, [id]h } |> std/io:print.ln("row {{ e.ord:d }} {{ e.tx:s }} hid{{ e.hid:d }}")
