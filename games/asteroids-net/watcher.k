// watcher.k — the listening half of the isolation probe. Joins with a
// zero-flag packet, then keepalives that same packet every 30 ticks
// (~0.5s) so the server's stale sweep (90 ticks ≈ 1.5s) never reaps the
// session — real clients keepalive. Its ship is identifiable by pid via
// snap.you: it receives only zero-flag input, so it must never leave its
// spawn spot. If the server's drive leaked another client's input onto
// it, it would drift — measurable.
//
// Verdict: PASS iff at least one ship stayed parked (the watcher's —
// inputs NOT applied to it) AND at least one ship moved (the driver's —
// inputs flow at all). A cross-owner leak fails the first half; dead
// input fails the second. Sticky `moved` catches transient drift; a
// death+respawn returns to the same spot so it can't false-fail.

import libs/udp
import wire
import clock
import std/io
import std/grid
import std/time

// Per-owner tracking, indexed by pid (owners are small ints).
std/grid:new(track, size: 16) {
    seen: 0.0[f32], x0: 0.0[f32], y0: 0.0[f32], moved: 0.0[f32]
}
std/grid:new(rep, size: 1) { snaps: 0[i32], lastn: 0[i32], still: 0[i32], driving: 0[i32], me: 0.0[f32], myparked: 0[i32] }

tor owner-idx { owner: f32 } -> i32

owner-idx -> @as(i32, @intFromFloat(owner))

tor track-ent { x: f32, y: f32, owner: f32 }

// stored reads the pre-update row: moved only counts once x0/y0 are real
// (seen already 1), else first-sight x - 0.0 would flag every ship.
track-ent = owner-idx(owner): i
    |> std/grid:stored { track[i].x0: (if (track[i].seen == 0.0) x else track[i].x0), track[i].y0: (if (track[i].seen == 0.0) y else track[i].y0), track[i].moved: (if (track[i].seen != 0.0 and @abs(x - track[i].x0) + @abs(y - track[i].y0) > 4.0) 1.0 else track[i].moved), track[i].seen: 1.0 }

tor observe { d: string }

observe = wire:snap.count(d): n
    |> wire:snap.you(d): me
    |> std/grid:stored { rep[0].snaps: rep[0].snaps + 1, rep[0].lastn: n, rep[0].me: me }
    |> for(0..@as(usize, @intCast(n)))
        ! each i |> wire:snap.ent(d, i: @as(i32, @intCast(i))): e
            |> if (e.kind == 1.0 and e.dead == 0.0)
                | then |> track-ent(e.x, e.y, e.owner)
                | else |> _

// Zero-flag input IS the keepalive: every packet runs sim:drive, which
// touches p.last. seq is the client tick — a 30-tick keepalive cadence
// reads as a 29-input gap in indrop, honest for a listen-mostly client.
// Branched send, so it lives boxed in a tor.
tor keepalive { s: *libs/udp:Socket<bound>, t: i64 }

keepalive = wire:input.encode(seq: @as(i32, @intCast(t)), left: false, right: false, thrust: false, fire: false): pkt
    |> libs/udp:send.ip(sock: s, ip: "127.0.0.1", port: 7777, data: pkt)
    | sent |> _
    | err e |> std/io:print.ln("ka err {{ e:s }}")

tor drain { s: *libs/udp:Socket<bound> }

drain = libs/udp:packets(sock: s, max: 8)
    ! packet p |> libs/udp:packet.data(p): d |> observe(d)
    | done |> _
    | err e |> std/io:print.ln("drain err {{ e:s }}")

tor report {}

report = clock:ticks(count: 16)
    ! each i |> if (track[@as(usize, @intCast(i))].seen != 0.0)
        | then |> std/grid:stored { rep[0].still: rep[0].still + @as(i32, (if (track[@as(usize, @intCast(i))].moved == 0.0) 1 else 0)), rep[0].driving: rep[0].driving + @as(i32, (if (track[@as(usize, @intCast(i))].moved != 0.0) 1 else 0)), rep[0].myparked: rep[0].myparked + @as(i32, (if (@as(f32, @floatFromInt(i)) == rep[0].me and track[@as(usize, @intCast(i))].moved == 0.0) 1 else 0)) }
        | else |> _
    | done |> _

// The join send below opens the session; keepalives in the tick loop
// hold it open for the whole ~6s observation window.
libs/udp:bind(port: 0)
| bound s |> std/io:print.ln("watcher up")
    |> wire:input.encode(seq: 0, left: false, right: false, thrust: false, fire: false): pkt
        |> libs/udp:send.ip(sock: s, ip: "127.0.0.1", port: 7777, data: pkt)
        | sent |> clock:ticks(count: 360)
            ! each t |> drain(s) |> std/time:sleep-ms(ms: 16)
                |> if (@mod(t, 30) == 0)
                    | then |> keepalive(s, t: @as(i64, @intCast(t)))
                    | else |> _
            | done |> report()
                |> std/io:print.ln("watcher: {{ rep[0].snaps:d }} snaps, pid {{ rep[0].me:d }} — {{ rep[0].myparked:d }} mine-parked, {{ rep[0].still:d }} parked, {{ rep[0].driving:d }} driving")
                |> if (rep[0].myparked >= 1 and rep[0].driving >= 1)
                    | then |> std/io:print.ln("ISOLATION: PASS")
                    | else |> std/io:print.ln("ISOLATION: FAIL — my ship moved (leak), no pid learned, or no driven ship (dead input)")
                |> libs/udp:close(sock: s)
        | err e |> std/io:print.ln("send err {{ e:s }}")
| err e |> std/io:print.ln("bind err {{ e:s }}")
