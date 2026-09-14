// bot.k — the headless scripted client: no raylib, just a socket and a
// script, in two phases:
//
//   ticks   0..99  — send input every tick (thrust held 10..69, fire at 40),
//                    drain snapshots.
//   ticks 100..219 — silent, drain only. The staleness half of the test:
//                    ~90 ticks after the last packet the server should take
//                    the session row AND the ship (lastn drops to rocks-only).
//
// Receipts park in `rep`: snapshots seen, last entity count, first-vs-last
// observed ship position — drift is the proof the server's sim moved it.
// (An effect arm can't capture the enclosing loop's locals — measured, zig
// nested fn — so observe reads the SERVER's tick off the wire instead, and
// the conditional capture rides if-EXPRESSIONS inside stored.)

import libs/udp
import wire
import std/io
import std/grid
import std/time

std/grid:new(rep, size: 1) {
    snaps: 0[i32], lastn: 0[i32],
    first_x: 0.0[f32], first_y: 0.0[f32], last_x: 0.0[f32], last_y: 0.0[f32]
}

tor observe { d: string }

observe = wire:snap.count(d): n
    |> wire:snap.ent(d, i: 0): e
    |> std/grid:stored { rep[0].snaps: rep[0].snaps + 1, rep[0].lastn: n, rep[0].first_x: (if (rep[0].snaps == 0 and n > 0) e.x else rep[0].first_x), rep[0].first_y: (if (rep[0].snaps == 0 and n > 0) e.y else rep[0].first_y), rep[0].last_x: (if (n > 0) e.x else rep[0].last_x), rep[0].last_y: (if (n > 0) e.y else rep[0].last_y) }

tor drain { s: *libs/udp:Socket<bound> }

drain = libs/udp:packets(sock: s, max: 8)
    ! packet p |> libs/udp:packet.data(p): d |> observe(d)
    | done |> std/time:sleep-ms(ms: 16)
    | err e |> std/io:print.ln("drain err {{ e:s }}")

libs/udp:bind(port: 0)
| bound s |> std/io:print.ln("bot up")
    |> for(0..100)
        ! each t |> wire:input.encode(left: false, right: false, thrust: t >= 10 and t < 70, fire: t == 40): pkt
            |> libs/udp:send.ip(sock: s, ip: "127.0.0.1", port: 7777, data: pkt)
            | sent |> drain(s)
            | err e |> std/io:print.ln("send err {{ e:s }}")
    | done |> for(0..120)
        ! each _ |> drain(s)
        | done |> std/io:print.ln("bot: {{ rep[0].snaps:d }} snaps, last count {{ rep[0].lastn:d }}")
            |> std/io:print.ln("ship first ({{ rep[0].first_x:f }},{{ rep[0].first_y:f }}) last ({{ rep[0].last_x:f }},{{ rep[0].last_y:f }})")
            |> libs/udp:close(sock: s)
| err e |> std/io:print.ln("bind err {{ e:s }}")
