import koru/regressions

koru/regressions:run()
koru/regressions:expect(text: "expected err:")
koru/regressions:expect-not(text: "unexpected tick success")
//
// B2 pin: tick without init hits the honest err branch.

import koru/signal
import std/io

koru/signal:tick(Breath, pass_rate: 90.0)
| out _ |> std/io:print.ln("unexpected tick success")
| err e |> std/io:print.ln("expected err: {{ e:s }}")
