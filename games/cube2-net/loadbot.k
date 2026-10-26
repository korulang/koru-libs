// loadbot.k — the bench instrument: a real enet client that hammers Ping→Pong
// (nmc 30/31 — the one message both waiter and cube2-net fully support), then
// reports sends/replies. Point at either server; the number that comes out is
// request/response throughput, comparable apples-to-apples.

import libs/enet
import std/io
import std/args
import std/string
import std/grid
import wire

std/grid:new(tally, size: 1) {
    sent: 0[i32], ponged: 0[i32], rounds: 0[i32], other: 0[i32]
}

tor run { port: i32 }

run = libs/enet:client(channels: 3)
| up cli |> libs/enet:dial(host: cli, ip: "127.0.0.1", port: @as(u16, @intCast(port)), channels: 3)
    | dialing ck |> for(0..2000)
        ! each _ |> libs/enet:service(host: cli, timeout_ms: 1)
            ! connect cp |> std/grid:stored { tally[0].rounds: tally[0].rounds + 1 }
            ! packet pk |> libs/enet:packet.data(p: pk): d
                |> wire:nmc(d): code
                |> if (code == 1)
                    | then |> libs/enet:packet.peer-key(p: pk): pkey
                        |> wire:tryjoin.encode(name: "loadbot", model: 0, authdom: "", authname: ""): tj
                        |> libs/enet:send.key(host: cli, key: pkey, channel: 1, data: tj, reliable: true)
                            | sent |> _
                            | err _ |> _
                    | else |> if (code == 31)
                        | then |> std/grid:stored { tally[0].ponged: tally[0].ponged + 1 }
                        | else |> std/grid:stored { tally[0].other: tally[0].other + 1 }
            ! disconnect dp |> _
            | idle |> wire:ping(v: tally[0].sent): pg
                |> libs/enet:send.key(host: cli, key: ck, channel: 1, data: pg, reliable: false)
                | sent |> libs/enet:flush(host: cli) |> std/grid:stored { tally[0].sent: tally[0].sent + 1 }
                | err _ |> _
            | err _ |> _
        | done |> std/io:print.ln("loadbot: {{ tally[0].sent:d }} sent, {{ tally[0].ponged:d }} ponged, {{ tally[0].other:d }} other pkts")
            |> libs/enet:close(host: cli)
    | err e |> std/io:print.ln("dial err {{ e:s }}")
| err e |> std/io:print.ln("client err {{ e:s }}")

std/args:get(index: 1)
| arg portstr |> std/string:parse-int(s: portstr)
    | ok port |> run(port: @as(i32, @intCast(port)))
    | err _ |> run(port: 28785)
| out-of-bounds |> run(port: 28785)
