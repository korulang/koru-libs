// driver.k — the active half of the isolation probe. Sends input EVERY
// tick for the whole run (thrust held, turns and fires on a schedule) so
// a foreign-input leak has ~6 seconds of thrust to leak into the
// watcher's parked ship. Never goes silent inside the window — that is
// the point: while watcher listens, this stream is live.

import libs/udp
import wire
import clock
import std/io
import std/grid
import std/time

std/grid:new(rep, size: 1) { snaps: 0[i32], lastn: 0[i32] }

tor observe { d: string }

observe = wire:snap.count(d): n
    |> std/grid:stored { rep[0].snaps: rep[0].snaps + 1, rep[0].lastn: n }

tor drain { s: *libs/udp:Socket<bound> }

drain = libs/udp:packets(sock: s, max: 8)
    ! packet p |> libs/udp:packet.data(p): d |> observe(d)
    | done |> _
    | err e |> std/io:print.ln("drain err {{ e:s }}")

libs/udp:bind(port: 0)
| bound s |> std/io:print.ln("driver up")
    |> clock:ticks(count: 360)
        ! each t |> wire:input.encode(left: t >= 60 and t < 120, right: t >= 200 and t < 260, thrust: true, fire: t == 100 or t == 200 or t == 300): pkt
            |> libs/udp:send.ip(sock: s, ip: "127.0.0.1", port: 7777, data: pkt)
            | sent |> drain(s) |> std/time:sleep-ms(ms: 16)
            | err e |> std/io:print.ln("send err {{ e:s }}")
    | done |> std/io:print.ln("driver: {{ rep[0].snaps:d }} snaps, last count {{ rep[0].lastn:d }}")
        |> libs/udp:close(sock: s)
| err e |> std/io:print.ln("bind err {{ e:s }}")
