// probe_ctx_comp — a component's {{ prop }} params are declared tor
// inputs, so a ctx scope injects them at the call site: card() under
// ctx(theme[r]) emits card(fs: theme[r].fs) and the synthesized impl
// forwards the prop into the spec row. The component author writes no
// ctx — the scope reaches the generated body through the declared param.
// Pins three findings: the prop ident must not be f64-normalized
// (fs → fs, never fs.0); a prop whose value IS the column name emits
// the bare pun; and `| row r` on the edge INTO a ctx step must inherit
// onto the promoted kid after the ctx node splices out.
import std/store
import std/io
import std/ctx
import libs/ui

std/store:new(theme, capacity: 8) { accent: f64, fs: f64 }
std/store:new(hands) { cardh: i64 }
std/store:new(spec, capacity: 256) { d: i64, ord: i64, kind: char[8], tx: char[40], fs: f64 }

libs/ui:component(card, spec) {
    <text tx="hi" fs={{ fs:f }} bind="hands.cardh"/>
}

std/io:print.ln("seed")
|> std/store:insert(theme) { accent: 0.9, fs: 15.0 }
    | row r |> std/ctx(theme[r]) |> card()
        |> std/io:print.ln("card fs: {{ spec[hands.cardh].fs:f }}")
