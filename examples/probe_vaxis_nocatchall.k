// PROBE D: probe B MINUS the `! key _` catch-all — a guarded `! key when`
// with no fallback (exactly hello's shape). Single variable vs building B.
import std/io
import koru/vaxis

koru/vaxis:run(title: "probe")
! ready |> koru/vaxis:write-at(x: 2, y: 2, text: "hi")
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err _ |> std/io:print.ln("failed")
