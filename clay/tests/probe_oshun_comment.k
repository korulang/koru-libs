// probe_oshun_comment — falsifier for `<!-- -->` in Oshun markup.
// The comment must seed NO row and NO text — the same three preorder
// rows as probe_component or it fails.
import std/store
import std/io
import libs/oshun

[tree]std/store:new(spec, capacity: 64) {
    d: i64, kind: char[8], ws: char[8], tx: char[40], uid: i64, ord: i64, hid: i64,
}

libs/oshun:component(seed, spec) {
    <!-- the strip: one panel, two leaves -->
    <panel ws="star">
        <!-- a comment nested inside the panel -->
        <text tx="hello"/>
        <tab tx="alpha" uid="200"/> <!-- trailing comment -->
    </panel>
}

seed()
|> std/store:preorder(spec, order: "ord")
    ! preorder { [row]e, [id]h } |> std/io:print.ln("row {{ e.ord:d }} d{{ e.d:d }} {{ e.kind:s }}:{{ e.tx:s }} uid{{ e.uid:d }} hid{{ e.hid:d }}")
