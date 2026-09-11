// PROBE B: .k, vaxis-only, but HANDLE ! draw. Separates "handling ready"
// from ".kz file mode" as the trigger for the missing alias prelude.
import std/io
import koru/vaxis

koru/vaxis:run(title: "probe")
! draw _ |> koru/vaxis:write-at(x: 2, y: 2, text: "hi")
! char k when k.ch == 'q' |> koru/vaxis:quit()
| err _ |> std/io:print.ln("failed")
