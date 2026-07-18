// Does it compose? vaxis key input + store + reactivity, ~15 lines.
//
// A store singleton holds the click count. A watch on it is the whole UI:
// every keypress that isn't 'q' writes the store (+1), the write fires the
// watch, and the watch prints the running total. vaxis supplies the keys;
// the store supplies the state and the reaction. 'q' quits.

import std/io
import std/store
import koru/vaxis

std/store:new(counter) { clicks: 0[i64] }

std/store:watch(counter)
! clicks c |> std/io:print.ln("clicked {{ c:d }} times")

koru/vaxis:run(title: "counter")
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key _ |> std/store:stored { counter.clicks: counter.clicks + 1 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
