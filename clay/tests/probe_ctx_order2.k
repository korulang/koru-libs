import std/store
import std/io
import std/ctx
import libs/oshun

std/store:new(hands) { cardh: i64 }
std/store:new(spec, capacity: 256) { d: i64, ord: i64, kind: char[8], tx: char[40], fs: f64 }

std/io:print.ln("seed")
|> card(fs: 15.0)
    |> std/io:print.ln("card fs: {{ spec[hands.cardh].fs:f }}")

libs/oshun:component(card, spec) {
    <text tx="hi" fs={{ fs:f }} bind="hands.cardh"/>
}
