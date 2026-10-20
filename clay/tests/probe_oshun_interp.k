// probe_oshun_interp — mixed `{{ }}` parts in quoted attrs and element
// text lower through fmt:ln → from-page | ok → take; the row's char[N]
// field reads v.data (bytes copy, overflow truncates per 690_052) and
// free discharges the String inside the row arm. Whole `{{ p:t }}` stays
// a typed reference; mixed on a non-text column refuses (unconsumed).
import std/store
import std/io
import std/fmt
import std/string
import libs/oshun

[tree]std/store:new(spec, capacity: 64) {
    d: i64, kind: char[8], tx: char[40], ord: i64, hid: i64,
}

libs/oshun:component(seed, spec) {
    <panel>
        <text tx="clicks: {{ n:d }}"/>
        <text>row {{ r:d }} up</text>
    </panel>
}

seed(n: 42, r: 7)
|> std/store:preorder(spec, order: "ord")
    ! preorder { [row]e, [id]h } |> std/io:print.ln("row {{ e.ord:d }} {{ e.tx:s }} hid{{ e.hid:d }}")
