// PROBE B: .k, vaxis-only, but HANDLE ! ready. Separates "handling ready"
// from ".kz file mode" as the trigger for the missing alias prelude.
import std/io
import koru/vaxis

koru/vaxis:run(title: "probe")
! ready |> koru/vaxis:write-at(x: 2, y: 2, text: "hi")
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key _ |> _
| err _ |> std/io:print.ln("failed")
