// probe_oshun_malformed — a bare attr (`dangling`, no `=`) makes the
// markup malformed: the decl stays unconsumed and the compiler refuses
// it downstream instead of silently seeding a truncated row.
import std/store
import std/io
import oshun

[tree]std/store:new(spec, capacity: 64) {
    d: i64, kind: char[8], ws: char[8], tx: char[40], uid: i64, ord: i64, hid: i64,
}

oshun:component(seed, spec) {
    <panel ws="star" dangling>
        <text tx="hello"/>
    </panel>
}

seed()
|> std/io:print.ln("unreached")
