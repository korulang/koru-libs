// udp loopback: bind two ephemeral sockets, send a datagram a -> b, drain b,
// reply b -> a, drain a. Everything asserted through packet.data/key — real
// syscalls, localhost, no fixtures.
//
// scratch is the extract-scalar-from-query idiom the games already use: the
// ! packet arm writes what it saw into the grid, the tail prints it.

import libs/udp
import std/io
import std/grid
import std/time

std/grid:new(seen, size: 1) {
    n: 0[i32], bytes: 0[i32], key: 0[i64],
    rbytes: 0[i32], rkey: 0[i64]
}

libs/udp:bind(port: 0)
| bound a |> libs/udp:bind(port: 0)
    | bound b |> libs/udp:socket.port(sock: b): bport
        |> libs/udp:socket.port(sock: a): aport
        |> std/io:print.ln("a:{{ aport:d }} b:{{ bport:d }}")
        |> libs/udp:send.ip(sock: a, ip: "127.0.0.1", port: bport, data: "hello koru")
        | sent |> std/time:sleep-ms(ms: 20) |> libs/udp:packets(sock: b, max: 8)
            ! packet p |> libs/udp:packet.data(p): d
                |> libs/udp:packet.key(p): k
                |> std/grid:stored { seen[0].n: seen[0].n + 1, seen[0].bytes: @as(i32, @intCast(d.len)), seen[0].key: k }
                |> libs/udp:send.ip(sock: b, ip: "127.0.0.1", port: aport, data: "ack")
                | sent |> _
                | err e |> std/io:print.ln("reply err {{ e:s }}")
            | done |> std/time:sleep-ms(ms: 20) |> libs/udp:packets(sock: a, max: 8)
                ! packet rp |> libs/udp:packet.data(p: rp): rd
                    |> libs/udp:packet.key(p: rp): rk
                    |> std/grid:stored { seen[0].rbytes: @as(i32, @intCast(rd.len)), seen[0].rkey: rk }
                | done |> std/io:print.ln("recv {{ seen[0].n:d }} pkt, {{ seen[0].bytes:d }} bytes, key {{ seen[0].key:d }}; ack {{ seen[0].rbytes:d }} bytes, rkey {{ seen[0].rkey:d }}")
                    |> libs/udp:close(sock: b) |> libs/udp:close(sock: a) |> std/io:print.ln("closed")
                | err e |> std/io:print.ln("drain-a err {{ e:s }}")
            | err e |> std/io:print.ln("drain-b err {{ e:s }}")
        | err e |> std/io:print.ln("send err {{ e:s }}")
    | err e |> std/io:print.ln("bind b err {{ e:s }}")
| err e |> std/io:print.ln("bind a err {{ e:s }}")
