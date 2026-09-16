// vaxis as a std/pump participant — the composition the verbs exist for.
// init/deinit bracket the pump; the join carries the whole `!` surface
// under `! step` — the same arms `vaxis:run` would take, at the same names.
//
// (Compile probe: a `| err` exit path would leave the pump joined over an
// un-initialized module — the honest lifecycle wants init's failure to
// cancel the composition, which is run-as-transform territory.)

import std/io
import std/pump
import koru/vaxis

koru/vaxis:init(title: "pump-vaxis")
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")

std/pump:create(ui)
| drained |> koru/vaxis:deinit()

std/pump(ui)
! step |> koru/vaxis:step()
    ! draw _ |> koru/vaxis:write-styled(x: 2, y: 2, text: "pumped", style: { bold: false, dim: false, italic: false, strikethrough: false, fg: 0x5A56E0 })
        |> koru/vaxis:render()
    ! char k when k.ch == 'q' |> koru/vaxis:quit()
! live |> koru/vaxis:live()
! wait i |> koru/vaxis:wait(i)

std/pump:run(ui)
