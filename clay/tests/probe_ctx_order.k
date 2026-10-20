// probe_ctx_order — the ctx flow TEXTUALLY PRECEDES the component decl.
// If the pre-stage fixed point is positional, ctx fires before card
// exists as a decl and the prop injection must fail or skip.
import std/store
import std/io
import std/ctx
import libs/oshun

std/store:new(theme, capacity: 8) { accent: f64, fs: f64 }
std/store:new(hands) { cardh: i64 }
std/store:new(spec, capacity: 256) { d: i64, ord: i64, kind: char[8], tx: char[40], fs: f64 }

std/io:print.ln("seed")
|> std/store:insert(theme) { accent: 0.9, fs: 15.0 }
    | row r |> std/ctx(theme[r]) |> card()
        |> std/io:print.ln("card fs: {{ spec[hands.cardh].fs:f }}")

libs/oshun:component(card, spec) {
    <text tx="hi" fs={{ fs:f }} bind="hands.cardh"/>
}
