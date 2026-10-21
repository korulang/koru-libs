// probe_oshun_bufsize_tight — `bufsize="64"` tightens the scratch for
// THIS element's mixed values. The tx value produces ~90 bytes, so the
// synthesized ln.impl panics — and the panic names the configured 64
// bytes, proving the attr is live, not advisory.
import std/store
import std/io
import std/fmt
import std/string
import oshun

[tree]std/store:new(spec, capacity: 64) {
    d: i64, kind: char[8], tx: char[80], ord: i64, hid: i64,
}

oshun:component(seed, spec) {
    <panel>
        <text tx="tight: {{ s:s }}" bufsize="64"/>
    </panel>
}

seed(s: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
|> std/store:preorder(spec, order: "ord")
    ! preorder { [row]e, [id]h } |> std/io:print.ln("row {{ e.ord:d }} {{ e.tx:s }} hid{{ e.hid:d }}")
