// podnet client — the artifact shape: dial, send LIVE keyboard input,
// decode position broadcasts. Prints every 20th pos line.
//
// Keys: up/w thrust, left/a turn -1, right/d turn +1 (libs/kbd — termios
// cbreak + nonblocking stdin). Terminals send no key-up, so wire:input.map
// decays a press to neutral after 15 ticks without a repeat. Keys drain
// EVERY iteration — enet's `| idle` is starved whenever pos broadcasts keep
// the event queue full, so input polls first and ships one input datagram
// per tick regardless of broadcast density.

import libs/enet
import libs/kbd
import std/io
import std/grid
import std/time
import wire

std/grid:new(tally, size: 1) {
    tick: 0[i32], mycn: -1[i32], seen: 0[i32]
}

// Last decoded key + ticks since it arrived — the "held" approximation.
std/grid:new(kin, size: 1) { code: 0[i32], age: 0[i32] }

libs/kbd:raw(): _
|> libs/enet:client(channels: 3)
| up cli |> libs/enet:dial(host: cli, ip: "127.0.0.1", port: 28800, channels: 3)
    | dialing ck |> for(0..2000)
        ! each _ |> libs/kbd:keys(max: 4)
            ! key k |> std/grid:stored { kin[0].code: k.code, kin[0].age: 0 }
            | done |> std/grid:stored { kin[0].age: kin[0].age + 1, tally[0].tick: tally[0].tick + 1 }
                |> std/time:sleep-ms(ms: 10)
                |> wire:input.map(code: kin[0].code, age: kin[0].age): inp
                |> wire:input(inp.thrust, inp.turn): m
                |> libs/enet:send.key(host: cli, key: ck, channel: 0, data: m, reliable: false)
                    | sent |> libs/enet:flush(host: cli)
                    | err _ |> _
                |> libs/enet:service(host: cli, timeout_ms: 10)
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
                    | idle |> _
                    | err _ |> _
        | done |> std/io:print.ln("client done")
            |> libs/enet:close(host: cli)
            |> libs/kbd:restore(): _
    | err e |> std/io:print.ln("dial err {{ e:s }}")
| err e |> std/io:print.ln("client err {{ e:s }}")
