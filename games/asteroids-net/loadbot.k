// loadbot.k — one cell of the scale probe. A real client over a real
// datagram socket: joins, streams thrust input every tick for the whole
// run, drains snapshots, and reports what it heard. load.sh spawns N of
// these as separate processes — each bind(port: 0) lands a distinct
// ephemeral port, so each is a distinct session key to the server.
//
// Unlike bot.k there is no silent phase: the probe measures throughput
// and loss under sustained load, not staleness. seq = client tick — at
// scale, socket-buffer pressure can drop real packets, and indrop counts
// them honestly rather than by injection.

import libs/udp
import wire
import clock
import std/io
import std/grid
import std/time

std/grid:new(rep, size: 1) { snaps: 0[i32], lastn: 0[i32], me: 0.0[f32], indrop: 0.0[f32] }

tor observe { d: string }

observe = wire:snap.count(d): n
    |> wire:snap.you(d): me
    |> wire:snap.indrop(d): dr
    |> std/grid:stored { rep[0].snaps: rep[0].snaps + 1, rep[0].lastn: n, rep[0].me: me, rep[0].indrop: dr }

tor drain { s: *libs/udp:Socket<bound> }

drain = libs/udp:packets(sock: s, max: 8)
    ! packet p |> libs/udp:packet.data(p): d |> observe(d)
    | done |> _
    | err e |> std/io:print.ln("drain err {{ e:s }}")

tor send-tick { s: *libs/udp:Socket<bound>, t: i64 }

send-tick = wire:input.encode(seq: @as(i32, @intCast(t)), left: false, right: false, thrust: true, fire: @mod(t, 90) == 0): pkt
    |> libs/udp:send.ip(sock: s, ip: "127.0.0.1", port: 7777, data: pkt)
    | sent |> drain(s) |> std/time:sleep-ms(ms: 16)
    | err e |> std/io:print.ln("send err {{ e:s }}")

// 700 ticks ≈ 11.6s — long enough for at least one server heartbeat
// (BEAT=600) to land inside the window and print the aggregate receipts.
libs/udp:bind(port: 0)
| bound s |> clock:ticks(count: 700)
    ! each t |> send-tick(s, t: @as(i64, @intCast(t)))
    | done |> std/io:print.ln("loadbot: {{ rep[0].snaps:d }} snaps, pid {{ rep[0].me:d }}, last count {{ rep[0].lastn:d }}, indrop {{ rep[0].indrop:d }}")
        |> libs/udp:close(sock: s)
| err e |> std/io:print.ln("bind err {{ e:s }}")
