// server.k — the authoritative half of asteroids-net. No raylib anywhere:
// a bound datagram socket, an unbounded tick loop, the forked sim, and one
// snapshot per client per tick.
//
// Per tick: drain the socket (each datagram is one sim:drive — find-or-join
// the session, apply input), run the world rules, sweep silent clients,
// broadcast one snapshot to every player row, sleep to ~60Hz. The tick
// source is unbounded — a server runs until killed; the heartbeat tor
// prints receipts every BEAT ticks since | done never comes.

import std/io
import std/store
import std/grid
import std/time
import libs/udp
import sim
import wire
import clock

const {
    PORT: 7777
    STALE_TICKS: 90.0
    BEAT: 600.0
}

// Run receipts: packets in, snapshots out, heartbeat counter.
std/grid:new(tally, size: 1) { pkts: 0[i32], sent: 0[i32], beats: 0.0[f32] }

// The shared world row: score/wave/census/spawn-queue/LCG-seed/pid-counter.
std/store:insert(game) { score: 0.0, wave: 0.0, rocks: 0.0, pending: 0.0, seed: 7.0, nextpid: 1.0 }
    | row _ |> _
    | full |> std/io:print.ln("game store full at init")

tor handle { p: *libs/udp:Packet<packet>, t: f32 }

handle = libs/udp:packet.data(p): d
    |> libs/udp:packet.key(p): k
    |> wire:input.decode(d): inp
    |> if (inp.ok)
        | then |> sim:drive(key: k, tick: t, inp.left, inp.right, thrusting: inp.thrust, firing: inp.fire)
            |> std/grid:stored { tally[0].pkts: tally[0].pkts + 1 }
        | else |> _

tor fill-bodies { sn: *wire:Snap<open> }

fill-bodies = std/store:query(bodies)
    ! query e |> wire:snap.entity(s: sn, e.x, e.y, e.rot, e.r, e.inv, e.seed, e.kind, e.dead, e.owner)

tor fill-trailer { sn: *wire:Snap<open> }

fill-trailer = std/store:query(game)
    ! query g |> wire:snap.trailer(s: sn, g.score, g.wave)

tor send-all { sn: *wire:Snap<open>, s: *libs/udp:Socket<bound> }

send-all = std/store:query(players)
    ! query p |> wire:snap.send(s: sn, sock: s, p.key)
        |> std/grid:stored { tally[0].sent: tally[0].sent + 1 }

// One snapshot, built once, fanned out per session row. The interest
// management question (what does THIS client need) is the next slice — v0
// sends everyone the whole field.
tor broadcast { s: *libs/udp:Socket<bound>, t: i32 }

broadcast = wire:snap.begin(tick: t): sn
    |> fill-bodies(sn)
    |> fill-trailer(sn)
    |> send-all(sn, s)
    |> wire:snap.free(s: sn)

// Receipts while the server runs — an unbounded loop's | done never
// arrives, so state dumps ride a counter that resets every BEAT ticks.
tor heartbeat {}

heartbeat = if (tally[0].beats >= BEAT)
    | then |> std/grid:stored { tally[0].beats: 0.0 }
        |> sim:dump-game()
        |> sim:dump-players()
        |> std/io:print.ln("beat: {{ tally[0].pkts:d }} pkts in, {{ tally[0].sent:d }} snaps out")
    | else |> std/grid:stored { tally[0].beats: tally[0].beats + 1.0 }

libs/udp:bind(port: PORT)
| bound s |> std/io:print.ln("asteroids-net server on :{{ PORT:d }} — no tick bound, runs until killed")
    |> clock:ticks()
        ! each t |> libs/udp:packets(sock: s, max: 64)
            ! packet p |> handle(p, t: @as(f32, @floatFromInt(t)))
            | done |> sim:tick()
                |> sim:harvest()
                |> sim:harvest-rocks()
                |> sim:respawn-ship()
                |> sim:respawn-tick()
                |> sim:maybe-revive()
                |> sim:wave-check()
                |> sim:spawn-tick()
                |> sim:sweep-stale(tick: @as(f32, @floatFromInt(t)), timeout: STALE_TICKS)
                |> broadcast(s, t: @as(i32, @intCast(t)))
                |> heartbeat()
                |> std/time:sleep-ms(ms: 16)
            | err e |> std/io:print.ln("drain err {{ e:s }}")
    | done |> libs/udp:close(sock: s)
| err e |> std/io:print.ln("bind err {{ e:s }}")
