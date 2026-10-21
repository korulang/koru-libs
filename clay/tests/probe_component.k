// probe_component — minimal falsifier for oshun:component lowering.
// If generated `insert`/`stored`/`| row` sites lower like hand-written ones,
// this prints the three markup rows in preorder.
import std/store
import std/io
import oshun

[tree]std/store:new(spec, capacity: 64) {
    d: i64, kind: char[8], ws: char[8], tx: char[40], uid: i64, ord: i64, hid: i64,
}

oshun:component(seed, spec) {
    <panel ws="star">
        <text tx="hello"/>
        <tab tx="alpha" uid="200"/>
    </panel>
}

seed()
|> std/store:preorder(spec, order: "ord")
    ! preorder { [row]e, [id]h } |> std/io:print.ln("row {{ e.ord:d }} d{{ e.d:d }} {{ e.kind:s }}:{{ e.tx:s }} uid{{ e.uid:d }} hid{{ e.hid:d }}")
