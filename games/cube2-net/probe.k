// probe.k — a koru enet client speaking Cube 2's wire protocol. The oracle
// bottle: point it at waiter (`./probe 28785`) and it decodes the real
// implementation's handshake; point it at our server (`./probe 28790`) and
// the same decode must print the same shape. Cross-implementation receipt,
// no fixtures.

import libs/enet
import std/io
import std/args
import std/string
import wire

tor run { port: i32 }

run = libs/enet:client(channels: 3)
| up cli |> libs/enet:dial(host: cli, ip: "127.0.0.1", port: @as(u16, @intCast(port)), channels: 3)
    | dialing ck |> std/io:print.ln("dialing :{{ port:d }}")
        |> for(0..80)
            ! each _ |> libs/enet:service(host: cli, timeout_ms: 50)
                ! connect cp |> std/io:print.ln("enet connected")
                ! packet pk |> libs/enet:packet.data(p: pk): d
                    |> libs/enet:packet.channel(p: pk): ch
                    |> libs/enet:packet.peer-key(p: pk): pkey
                    |> wire:nmc(d): code
                    |> if (code == 1)
                        | then |> wire:serverinfo.decode(d)
                            | info si |> std/io:print.ln("SERVERINFO cn {{ si.cn:d }} proto {{ si.proto:d }} session {{ si.session:d }} desc \"{{ si.desc:s }}\" authdom \"{{ si.authdom:s }}\"")
                                |> wire:tryjoin.encode(name: "koru-probe", model: 0, authdom: "", authname: ""): tj
                                |> libs/enet:send.key(host: cli, key: pkey, channel: 1, data: tj, reliable: true)
                                    | sent |> libs/enet:flush(host: cli)
                                    | err e |> std/io:print.ln("tryjoin err {{ e:s }}")
                            | bad |> std/io:print.ln("serverinfo decode: BAD")
                        | else |> if (code == 2)
                            | then |> std/io:print.ln("WELCOME len {{ @as(i32, @intCast(d.len)):d }}")
                                |> wire:tryspawn(): ts
                                |> libs/enet:send.key(host: cli, key: pkey, channel: 1, data: ts, reliable: true)
                                    | sent |> libs/enet:flush(host: cli)
                                    | err e |> std/io:print.ln("tryspawn err {{ e:s }}")
                            | else |> if (code == 17)
                                | then |> wire:spawnstate.decode(d)
                                    | spawned ss |> std/io:print.ln("SPAWNSTATE cn {{ ss.cn:d }} lifeseq {{ ss.lifeseq:d }} hp {{ ss.health:d }}/{{ ss.maxhealth:d }} armour {{ ss.armour:d }} weapon {{ ss.weapon:d }}")
                                        |> wire:confirmspawn(ss.lifeseq, ss.weapon): cf
                                        |> libs/enet:send.key(host: cli, key: pkey, channel: 1, data: cf, reliable: true)
                                            | sent |> libs/enet:flush(host: cli)
                                                |> wire:ping(v: 42): pg
                                                |> libs/enet:send.key(host: cli, key: pkey, channel: 1, data: pg, reliable: true)
                                                    | sent |> libs/enet:flush(host: cli)
                                                    | err e |> std/io:print.ln("ping err {{ e:s }}")
                                            | err e |> std/io:print.ln("confirm err {{ e:s }}")
                                    | bad |> std/io:print.ln("spawnstate decode: BAD")
                                | else |> if (code == 31)
                                    | then |> wire:ping.decode(d)
                                        | ping pv |> std/io:print.ln("PONG {{ pv:d }}")
                                        | bad |> _
                                    | else |> std/io:print.ln("nmc {{ code:d }} ch {{ ch:d }} len {{ @as(i32, @intCast(d.len)):d }}")
                ! disconnect dp |> std/io:print.ln("disconnected")
                | idle |> _
                | err e |> std/io:print.ln("svc err {{ e:s }}")
            | done |> libs/enet:close(host: cli) |> std/io:print.ln("probe done")
    | err e |> std/io:print.ln("dial err {{ e:s }}")
| err e |> std/io:print.ln("client err {{ e:s }}")

std/args:get(index: 1)
| arg portstr |> std/string:parse-int(s: portstr)
    | ok port |> run(port: @as(i32, @intCast(port)))
    | err e |> std/io:print.ln("bad port, using 28785") |> run(port: 28785)
| out-of-bounds |> run(port: 28785)
