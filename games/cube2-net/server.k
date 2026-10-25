// server.k — cube2-net's authoritative half. Minimal handshake slice:
// enet connect → ServerInfo (cn := the peer's incoming index), TryJoin →
// Welcome (map/mode/timeleft/setteam). No store yet — the session row
// arrives with game state; cn rides enet's pid until then.
//
// Oracle parity target: `probe.k` must decode this server's handshake the
// same way it decodes waiter's.

import libs/enet
import std/io
import wire

const {
    PORT: 28790
    PROTO: 260
    MAPNAME: "metl3"
    MODE: 0
}

tor serve { srv: *libs/enet:Host<host> }

serve = libs/enet:service(host: srv, timeout_ms: 10)
    ! connect p |> libs/enet:peer.pid(p): cn
        |> std/io:print.ln("connect pid {{ cn:d }}")
        |> wire:serverinfo(cn: @as(i32, @intCast(cn)), proto: PROTO, session: 12345, haspass: false, desc: "koru cube2 server", authdom: ""): si
        |> libs/enet:send.peer(p, channel: 1, data: si, reliable: true)
            | sent |> libs/enet:flush(host: srv)
            | err e |> std/io:print.ln("serverinfo err {{ e:s }}")
    ! packet pk |> libs/enet:packet.data(p: pk): d
        |> libs/enet:packet.channel(p: pk): ch
        |> libs/enet:packet.peer-key(p: pk): pkey
        |> wire:nmc(d): code
        |> if (code == 0)
            | then |> wire:tryjoin.decode(d)
                | join tj |> std/io:print.ln("tryjoin \"{{ tj.name:s }}\" model {{ tj.model:d }}")
                    |> libs/enet:packet.peer-pid(p: pk): cn2
                    |> wire:welcome(map: MAPNAME, mode: MODE, needmap: false, timeleft: 600, cn: @as(i32, @intCast(cn2)), team: "good"): w
                    |> libs/enet:send.key(host: srv, key: pkey, channel: 1, data: w, reliable: true)
                        | sent |> libs/enet:flush(host: srv)
                        | err e |> std/io:print.ln("welcome err {{ e:s }}")
                | bad |> std/io:print.ln("tryjoin decode: BAD")
            | else |> std/io:print.ln("nmc {{ code:d }} ch {{ ch:d }} len {{ @as(i32, @intCast(d.len)):d }}")
    ! disconnect dp |> libs/enet:peer.pid(p: dp): dpid
        |> std/io:print.ln("disconnect pid {{ dpid:d }}")
    | idle |> _
    | err e |> std/io:print.ln("svc err {{ e:s }}")

libs/enet:host(port: PORT, peers: 32, channels: 3, down: 0, up: 0)
| up srv |> std/io:print.ln("cube2-net on :{{ PORT:d }}")
    |> for(0..600)
        ! each _ |> serve(srv)
        | done |> libs/enet:close(host: srv) |> std/io:print.ln("server done")
| err e |> std/io:print.ln("host err {{ e:s }}")
