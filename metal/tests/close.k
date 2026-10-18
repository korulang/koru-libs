// metal lifecycle smoke: open a window, run five frames, walk the | done
// path through window.close. Exercises the close+release sequence that
// segfaulted when a closed NSWindow was messaged after release.
import libs/metal
import std/io

libs/metal:window.open(width: 640, height: 480, title: "close test")
| win w |> libs/metal:frames(win: w, count: 5)
    ! frame f |> libs/metal:draw.rect(f, x: 10.0, y: 10.0, w: 20.0, h: 20.0, r: 0.5, g: 0.5, b: 0.5, a: 1.0)
    ! key-down k when k.code == 53 |> libs/metal:quit()
    ! close |> libs/metal:quit()
    | done w2 |> libs/metal:window.close(win: w2) |> std/io:print.ln("closed")
| err e |> std/io:print.ln("metal init failed: {{ e:s }}")
