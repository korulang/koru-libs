// PROBE C: identical to probe_vaxis_nostore.k (which BUILDS) but as .kz with
// the ~ host-switch. Isolates the .k vs .kz axis as the trigger.
import std/io
import koru/vaxis

koru/vaxis:run(title: "probe")
! char k when k.ch == 'q' |> koru/vaxis:quit()
| err _ |> std/io:print.ln("failed")
