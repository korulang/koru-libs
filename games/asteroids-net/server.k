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
    RCVBUF: 4194304
    DRAIN: 512
}

// Run receipts: packets in, snapshots out, heartbeat counter, beat clock
// (ns as f64 — the tick rate is the load signal: 60Hz nominal, overruns sag).
// simms/bcastms accumulate per-tick phase times so the beat says WHERE the
// budget went — drain is the remainder (it includes per-packet sim:drive).
std/grid:new(tally, size: 1) { pkts: 0[i32], sent: 0[i32], beats: 0.0[f32], lastbeat: 0.0[f64], simms: 0.0[f64], bcastms: 0.0[f64] }

// The shared world row: score/wave/census/spawn-queue/LCG-seed/pid-counter.
std/store:insert(game) { score: 0.0, wave: 0.0, rocks: 0.0, pending: 0.0, seed: 7.0, nextpid: 1.0 }
    | row _ |> _
    | full |> std/io:print.ln("game store full at init")

tor handle { p: *libs/udp:Packet<packet>, t: f32 }

handle = libs/udp:packet.data(p): d
    |> libs/udp:packet.key(p): k
    |> wire:input.decode(d): inp
    |> if (inp.ok)
        | then |> sim:drive(key: k, tick: t, seq: @as(f32, @floatFromInt(inp.seq)), inp.left, inp.right, thrusting: inp.thrust, firing: inp.fire)
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
    ! query p |> wire:snap.send(s: sn, sock: s, p.key, you: p.pid, indrop: p.drops)
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
    | then |> std/time:now(): tn
        |> std/time:elapsed(start: @as(i128, @intFromFloat(tally[0].lastbeat))): el
        |> std/grid:stored { tally[0].beats: 0.0, tally[0].lastbeat: @as(f64, @floatFromInt(tn)) }
        |> sim:dump-game()
        |> sim:dump-players()
        |> std/io:print.ln("beat: {{ tally[0].pkts:d }} pkts in, {{ tally[0].sent:d }} snaps out, {{ el.ms:f }}ms — {{ 600000.0 / el.ms:f }}Hz (sim {{ tally[0].simms:f }}ms bcast {{ tally[0].bcastms:f }}ms)")
        |> std/grid:stored { tally[0].simms: 0.0, tally[0].bcastms: 0.0 }
    | else |> std/grid:stored { tally[0].beats: tally[0].beats + 1.0 }

// The measured wall (N=100, +18,284 kernel buffer drops/run): drain cap
// 64 < ~100 pkts/tick meant a structural backlog — the deficit filled the
// kernel buffer and the counter moved. DRAIN now exceeds the 128-session
// ceiling; SO_RCVBUF buys burst headroom. Report the GRANTED size.
tor set-rcvbuf { s: *libs/udp:Socket<bound> }

set-rcvbuf = libs/udp:socket.rcvbuf(sock: s, bytes: RCVBUF)
    | ok |> libs/udp:socket.rcvsize(sock: s): got
        |> std/io:print.ln("rcvbuf: asked {{ RCVBUF:d }}, granted {{ got:d }}")
    | err e |> std/io:print.ln("rcvbuf err {{ e:s }}")

libs/udp:bind(port: PORT)
| bound s |> std/io:print.ln("asteroids-net server on :{{ PORT:d }} — no tick bound, runs until killed")
    |> set-rcvbuf(s)
    |> std/time:now(): t0
    |> std/grid:stored { tally[0].lastbeat: @as(f64, @floatFromInt(t0)) }
    |> clock:ticks()
        ! each t |> libs/udp:packets(sock: s, max: DRAIN)
            ! packet p |> handle(p, t: @as(f32, @floatFromInt(t)))
            | done |> std/time:now(): t1
                |> sim:tick()
                |> sim:harvest()
                |> sim:harvest-rocks()
                |> sim:respawn-ship()
                |> sim:respawn-tick()
                |> sim:maybe-revive()
                |> sim:wave-check()
                |> sim:spawn-tick()
                |> sim:sweep-stale(tick: @as(f32, @floatFromInt(t)), timeout: STALE_TICKS)
                |> std/time:now(): t2
                |> std/grid:stored { tally[0].simms: tally[0].simms + @as(f64, @floatFromInt(t2 - t1)) / 1000000.0 }
                |> broadcast(s, t: @as(i32, @intCast(t)))
                |> std/time:now(): t3
                |> std/grid:stored { tally[0].bcastms: tally[0].bcastms + @as(f64, @floatFromInt(t3 - t2)) / 1000000.0 }
                |> heartbeat()
                |> std/time:sleep-ms(ms: 16)
            | err e |> std/io:print.ln("drain err {{ e:s }}")
    | done |> libs/udp:close(sock: s)
| err e |> std/io:print.ln("bind err {{ e:s }}")
