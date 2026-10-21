// Smoke: does clay.h translate and solve? One fixed rect inside a padded
// root, then read back its box. No window — pure solver.
import libs/clay
import std/io

libs/clay:init(width: 400, height: 300)
| cl h |> libs/clay:layout(cl: h)
    ! tree t
        |> libs/clay:el.open(t)
        |> libs/clay:el.cfg(t, wk: 3, w: 300, hk: 3, h: 200, dir: 1, gap: 0, padl: 10, padr: 10, padt: 10, padb: 10, ax: 0, ay: 0, r: 40, g: 40, b: 50, a: 255, fl: 0, fx: 0, fy: 0, eid: 0, ovr: 0.0, ovg: 0.0, ovb: 0.0, ova: 0.0)
        |> libs/clay:el.open(t)
        |> libs/clay:el.cfg(t, wk: 3, w: 60, hk: 3, h: 30, dir: 0, gap: 0, padl: 0, padr: 0, padt: 0, padb: 0, ax: 0, ay: 0, r: 200, g: 80, b: 80, a: 255, fl: 0, fx: 0, fy: 0, eid: 0, ovr: 0.0, ovg: 0.0, ovb: 0.0, ova: 0.0)
    | solved cls |> libs/clay:cmd.count(cl: cls): n
        |> std/io:print.ln("cmds: {{ n:d }}")
        |> libs/clay:each(cl: cls)
            ! cmd rc |> std/io:print.ln("cmd {{ rc.kind:d }} at {{ rc.x:f }},{{ rc.y:f }} {{ rc.w:f }}x{{ rc.h:f }}")
            | drained |> libs/clay:drop(cl: h)
                |> std/io:print.ln("done")
| err e |> std/io:print.ln("clay init failed: {{ e:s }}")
