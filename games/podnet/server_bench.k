// podnet server_bench — bench variant of server.k. Identical logic; the
// only changes are capacity/duration constants so N=64 sessions fit:
//   MAXP 8 -> 64, players grid 8 -> 64, enet peers 32 -> 64,
//   TICKS 36000 -> 5000000 (bench.sh kills it; the loop must not end
//   mid-window since TICKS counts serve calls, not seconds).
// The committed server.k panics on the 9th connect (grid OOB, pid>=8).

import libs/enet
import std/io
import std/grid
import wire
import sim

const {
    PORT: 28801
    TICKS: 5000000
    MAXP: 64
}

std/grid:new(players, size: 64) {
    used: 0[i32], key: 0[i64], thrust: 0[i32], turn: 0[i32],
    x: 0[i32], y: 0[i32], a: 0[i32], v: 0[i32]
}

tor serve { srv: *libs/enet:Host<host> }

tor tick { srv: *libs/enet:Host<host> }

tick = for(0..MAXP)
    ! each i |> if (players[i].used == 1)
        | then |> sim:step(x: players[i].x, y: players[i].y, a: players[i].a, v: players[i].v, thrust: players[i].thrust, turn: players[i].turn): s
            |> std/grid:stored {
                    players[i].x: s.x, players[i].y: s.y, players[i].a: s.a, players[i].v: s.v }
                |> wire:pos(cn: @as(i32, @intCast(i)), s.x, s.y, s.a, s.v): m
                |> for(0..MAXP)
                    ! each j |> if (players[j].used == 1)
                        | then |> libs/enet:send.key(host: srv, key: players[j].key, channel: 0, data: m, reliable: false)
                            | sent |> _
                            | err _ |> _
    | done |> libs/enet:flush(host: srv)

serve = libs/enet:service(host: srv, timeout_ms: 50)
    ! connect p |> libs/enet:peer.key(p): k
        |> libs/enet:peer.pid(p): pid
        |> if (players[pid].used == 0)
            | then |> std/grid:stored {
                    players[pid].used: 1, players[pid].key: k, players[pid].thrust: 0, players[pid].turn: 0,
                    players[pid].x: 0, players[pid].y: 0, players[pid].a: 0, players[pid].v: 0 }
                |> std/io:print.ln("join cn {{ pid:d }}")
            | else |> std/io:print.ln("join cn {{ pid:d }} (slot busy)")
    ! packet pk |> libs/enet:packet.data(p: pk): d
        |> libs/enet:packet.peer-pid(p: pk): ppid
        |> wire:nmc(d): code
        |> if (code == 1)
            | then |> wire:input.decode(d)
                | input inp |> std/grid:stored {
                        players[ppid].thrust: @as(i32, inp.thrust), players[ppid].turn: @as(i32, inp.turn) }
                | bad |> _
    ! disconnect dp |> libs/enet:peer.pid(p: dp): dpid
        |> std/grid:stored { players[dpid].used: 0 }
        |> std/io:print.ln("leave cn {{ dpid:d }}")
    | idle |> tick(srv)
    | err e |> std/io:print.ln("svc err {{ e:s }}")

libs/enet:host(port: PORT, peers: 64, channels: 3, down: 0, up: 0)
| up srv |> std/io:print.ln("podnet bench on :{{ PORT:d }}")
    |> for(0..TICKS)
        ! each _ |> serve(srv)
        | done |> libs/enet:close(host: srv) |> std/io:print.ln("server done")
| err e |> std/io:print.ln("host err {{ e:s }}")
