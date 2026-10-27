// podnet client_bench — bench variant of client.k. Identical logic; the
// only changes: loop bound 2000 -> 2000000 so a session outlives the
// bench window (stock clients print "client done" and exit after ~30s,
// mid-measurement), and dial port 28800 -> 28801 to match server_bench.k
// (28800 may be held by other sessions' stock servers).

import libs/enet
import std/io
import std/grid
import wire

std/grid:new(tally, size: 1) {
    tick: 0[i32], mycn: -1[i32], seen: 0[i32]
}

libs/enet:client(channels: 3)
| up cli |> libs/enet:dial(host: cli, ip: "127.0.0.1", port: 28801, channels: 3)
    | dialing ck |> for(0..2000000)
        ! each _ |> libs/enet:service(host: cli, timeout_ms: 10)
            ! connect cp |> libs/enet:peer.pid(p: cp): pid
                |> std/grid:stored { tally[0].mycn: @as(i32, @intCast(pid)) }
                |> std/io:print.ln("connected as cn {{ pid:d }}")
            ! packet pk |> libs/enet:packet.data(p: pk): d
                |> wire:nmc(d): code
                |> if (code == 2)
                    | then |> wire:pos.decode(d)
                        | pos p |> if (tally[0].seen >= 19)
                            | then |> std/io:print.ln("pos cn {{ p.cn:d }} {{ p.x:d }},{{ p.y:d }} a{{ p.a:d }} v{{ p.v:d }}")
                                |> std/grid:stored { tally[0].seen: 0 }
                            | else |> std/grid:stored { tally[0].seen: tally[0].seen + 1 }
                        | bad |> _
            ! disconnect dp |> _
            | idle |> wire:input(thrust: 5, turn: 1): m
                |> libs/enet:send.key(host: cli, key: ck, channel: 0, data: m, reliable: false)
                    | sent |> libs/enet:flush(host: cli)
                        |> std/grid:stored { tally[0].tick: tally[0].tick + 1 }
                    | err _ |> _
            | err _ |> _
        | done |> std/io:print.ln("client done")
            |> libs/enet:close(host: cli)
    | err e |> std/io:print.ln("dial err {{ e:s }}")
| err e |> std/io:print.ln("client err {{ e:s }}")
