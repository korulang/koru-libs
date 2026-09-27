// vaxis's natural `run` inside an open std/pump — the capture shape.
// Same spelling a standalone program uses; the run transform sees the
// open pump and emits __pump_ui_{step,live,wait,retired}_* units instead
// of its own driver. `| done` rides the retire unit; `| err` stays on
// the init part that still executes at the site. The consumer spells no
// pump verbs — `create`/`run` bracket the region and do the driving.

import std/io
import std/pump
import koru/vaxis

std/pump:create(ui)
| drained |> std/io:print.ln("pump drained")

koru/vaxis:run(title: "pump-vaxis-captured")
! draw _ |> koru/vaxis:write-styled(x: 2, y: 2, text: "captured", style: { bold: false, dim: false, italic: false, strikethrough: false, fg: 0x5A56E0 })
    |> koru/vaxis:render()
! char k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
| done |> std/io:print.ln("vaxis done")

std/pump:run(ui)
