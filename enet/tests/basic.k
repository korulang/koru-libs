// enet loopback: server host + client host on one thread, dial, reliable
// "hello koru" up on channel 0, "ack" back down, graceful disconnect — every
// hop asserted through the service effect borrows. Real libenet over real
// UDP, localhost, no fixtures. Mirrors udp/tests/basic.k's shape: both sides
// pump each pump round, because a blocking dial would deadlock one thread.

import libs/enet
import std/io
import std/grid
import std/time

std/grid:new(seen, size: 1) {
    sconn: 0[i32], skey: 0[i64], spkts: 0[i32], sbytes: 0[i32],
    cconn: 0[i32], cpid: 0[i64], cpkts: 0[i32], cbytes: 0[i32],
    sdisc: 0[i32], cdisc: 0[i32]
}

libs/enet:host(port: 28700, peers: 8, channels: 3, down: 0, up: 0)
| up srv |> libs/enet:client(channels: 3)
    | up cli |> libs/enet:dial(host: cli, ip: "127.0.0.1", port: 28700, channels: 3)
        | dialing ck |> for(0..25)
                    ! each _ |> libs/enet:service(host: srv, timeout_ms: 10)
                        ! connect sp |> libs/enet:peer.key(p: sp): sk
                            |> std/grid:stored { seen[0].sconn: seen[0].sconn + 1, seen[0].skey: sk }
                        ! packet pk |> libs/enet:packet.data(p: pk): d
                            |> libs/enet:packet.peer-key(p: pk): pkey
                            |> std/grid:stored { seen[0].spkts: seen[0].spkts + 1, seen[0].sbytes: @as(i32, @intCast(d.len)) }
                            |> libs/enet:send.key(host: srv, key: pkey, channel: 0, data: "ack", reliable: true)
                                | sent |> libs/enet:flush(host: srv)
                                | err e |> std/io:print.ln("srv reply err {{ e:s }}")
                        ! disconnect sd |> std/grid:stored { seen[0].sdisc: 1 }
                        | idle |> libs/enet:service(host: cli, timeout_ms: 10)
                            ! connect cp |> libs/enet:peer.pid(p: cp): pid
                                |> std/grid:stored { seen[0].cconn: seen[0].cconn + 1, seen[0].cpid: pid }
                                |> libs/enet:send.peer(p: cp, channel: 0, data: "hello koru", reliable: true)
                                    | sent |> libs/enet:flush(host: cli)
                                    | err e |> std/io:print.ln("cli send err {{ e:s }}")
                            ! packet cpk |> libs/enet:packet.data(p: cpk): cd
                                |> std/grid:stored { seen[0].cpkts: seen[0].cpkts + 1, seen[0].cbytes: @as(i32, @intCast(cd.len)) }
                            ! disconnect cdd |> std/grid:stored { seen[0].cdisc: 1 }
                            | idle |> _
                            | err e |> std/io:print.ln("cli svc err {{ e:s }}")
                        | err e |> std/io:print.ln("srv svc err {{ e:s }}")
                    | done |> libs/enet:peer.disconnect-key(host: cli, key: ck, code: 0)
                        |> for(0..25)
                            ! each _ |> libs/enet:service(host: srv, timeout_ms: 10)
                                ! connect sp |> _
                                ! packet pk |> _
                                ! disconnect sd |> std/grid:stored { seen[0].sdisc: 1 }
                                | idle |> libs/enet:service(host: cli, timeout_ms: 10)
                                    ! connect cp |> _
                                    ! packet cpk |> _
                                    ! disconnect cdd |> std/grid:stored { seen[0].cdisc: 1 }
                                    | idle |> _
                                    | err e |> std/io:print.ln("cli svc err {{ e:s }}")
                                | err e |> std/io:print.ln("srv svc err {{ e:s }}")
                            | done |> std/io:print.ln("srv conn {{ seen[0].sconn:d }} key {{ seen[0].skey:d }} pkts {{ seen[0].spkts:d }} bytes {{ seen[0].sbytes:d }}; cli conn {{ seen[0].cconn:d }} pid {{ seen[0].cpid:d }} pkts {{ seen[0].cpkts:d }} bytes {{ seen[0].cbytes:d }}; disc s{{ seen[0].sdisc:d }} c{{ seen[0].cdisc:d }}")
                                |> libs/enet:close(host: cli)
                                |> libs/enet:close(host: srv)
                                |> std/io:print.ln("closed")
        | err e |> std/io:print.ln("dial err {{ e:s }}")
    | err e |> std/io:print.ln("client err {{ e:s }}")
| err e |> std/io:print.ln("host err {{ e:s }}")
