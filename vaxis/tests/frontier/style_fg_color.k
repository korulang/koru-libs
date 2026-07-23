// FRONTIER REPRO (historical) — Style.fg was missing; now should compile.
// Prefer examples/style_color.k for the positive probe.
//
//   koruc examples/…  (or copy beside a koru.json)

import std/io
import koru/vaxis

koru/vaxis:run(title: "frontier-style-fg")
! draw _ |> koru/vaxis:write-styled(x: 2, y: 2, text: "▌", style: { bold: false, dim: false, italic: false, strikethrough: false, fg: 0x5A56E0 })
    |> koru/vaxis:render()
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
