// Walking skeleton: open a window, run frames through the `! frame` effect
// branch (MSL triangle drawn into the live encoder each frame), close.
// Asymmetric lifecycle: window.open grants <opened!>, frames consumes it and
// re-mints <active!> through `| done`, window.close accepts only <!active>.
// The frame handle is a per-frame borrow of the render encoder that cannot
// escape the frame body.
//
// Callbacks as effect branches: `! key-down` fires when the ObjC view's
// keyDown: IMP pushes the mailbox and frames drains it; `! close` fires when
// the window's isVisible goes false. Escape (keyCode 53) quits, as does
// closing the window. Count is a backstop so the test halts unattended.

import libs/metal
import std/io

libs/metal:window.open(width: 640, height: 400, title: "koru metal — esc to quit")
| win w |> libs/metal:window.clear.color(win: w, r: 0.08, g: 0.1, b: 0.2) |> libs/metal:frames(win: w, count: 3600)
    ! frame f |> libs/metal:draw.triangle(f)
    ! key-down k when k.code == 53 |> libs/metal:quit()
    ! close |> libs/metal:quit()
    | done w2 |> libs/metal:window.close(win: w2) |> std/io:print.ln("metal: ran event loop, closed")
| err e |> std/io:print.ln("metal init failed: {{ e:s }}")
