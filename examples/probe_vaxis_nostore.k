// PROBE (not a shipping example): isolate why hello_vaxis.kz fails at `ready`
// undeclared while counter_vaxis.k builds. This is vaxis-only (NO store) and
// OMITS `! draw`. Two outcomes:
//   builds  → the alias prelude emits fine for a vaxis-only flow → the trigger
//             is HANDLING `! draw` (a void optional branch), or the .kz mode.
//   fails   → a vaxis-only flow never gets the alias prelude → the store
//             coordinator is what emits it, and counter only builds by accident.
import std/io
import koru/vaxis

koru/vaxis:run(title: "probe")
! char k when k.ch == 'q' |> koru/vaxis:quit()
| err _ |> std/io:print.ln("failed")
