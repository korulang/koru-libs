// podnet render — the watching client. Dials :28800, keeps every racer's
// last pos broadcast in a grid row (cn = slot), and redraws an ASCII field
// on every 2nd pos packet (~10-20 fps). One posix.write per frame: cursor-
// home + fully-overwritten cells, so no clear flicker. It also sends a
// gentle input (thrust 4, turn -1) so its own pod orbits too — this client
// is a participant, not a pure spectator.
//
// Units: wire pos is milli (x,y milli-units drifting ±100ish, a milli-rad,
// v milli-speed). RANGE is the field half-extent in those units; racers
// outside it clamp to the border. Racers draw as their cn digit (the wire
// has no welcome packet — a client cannot learn its own slot), '+' marks
// the origin.
//
// Build: koruc render.k && mv a.out render.bin

import libs/enet
import std/io
import std/grid
import wire

const {
    MAXP: 8
    RANGE: 160
    COLS: 78
    ROWS: 24
}

// Racer state — last broadcast per slot.
std/grid:new(pods, size: 8) {
    used: 0[i32], x: 0[i32], y: 0[i32], a: 0[i32], v: 0[i32]
}

// View counters. NOTE: the wire protocol has no welcome packet, so a
// client cannot learn its own slot — racers are drawn as their cn digit,
// never a "me" glyph (peer.pid is the LOCAL peer index, always 0 here).
std/grid:new(view, size: 1) {
    packets: 0[i32], frames: 0[i32]
}

// Alt-screen-free setup: clear once, hide the cursor.
tor enter {}

proc enter|zig {
    const std = @import("std");
    _ = std.posix.write(1, "\x1b[2J\x1b[H\x1b[?25l") catch 0;
}

tor leave {}

proc leave|zig {
    const std = @import("std");
    _ = std.posix.write(1, "\x1b[?25h\x1b[0m\n") catch 0;
}

// One frame, one write. Reads $mod.__koru_grid_pods — the grid emit — so
// the flow side stays pure Koru and the drawing stays one Zig body.
tor draw { packets: i32 }

proc draw|zig {
    const std = @import("std");
    const FC = $mod.COLS;
    const FR = $mod.ROWS;
    const EXT = $mod.RANGE;

    var field: [FR][FC]u8 = undefined;
    for (&field) |*row| @memset(row, ' ');

    // Origin marker.
    field[FR / 2][FC / 2] = '+';

    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();

    for (0..8) |i| {
        if ($mod.__koru_grid_pods.used[i] == 0) continue;
        const x = $mod.__koru_grid_pods.x[i];
        const y = $mod.__koru_grid_pods.y[i];
        var c = @divTrunc((x + EXT) * (FC - 1), 2 * EXT);
        var r = @divTrunc((EXT - y) * (FR - 1), 2 * EXT);
        c = @max(0, @min(FC - 1, c));
        r = @max(0, @min(FR - 1, r));
        const ci: usize = @intCast(c);
        const ri: usize = @intCast(r);
        field[ri][ci] = @as(u8, '0') + @as(u8, @intCast(i));
    }

    w.writeAll("\x1b[H+") catch {};
    w.writeBytesNTimes("-", FC) catch {};
    w.writeAll("+\n") catch {};
    for (field) |row| {
        w.writeAll("|") catch {};
        w.writeAll(&row) catch {};
        w.writeAll("|\n") catch {};
    }
    w.writeAll("+") catch {};
    w.writeBytesNTimes("-", FC) catch {};
    w.writeAll("+\n") catch {};

    w.print(" pkts {d} range ±{d}", .{ packets, EXT }) catch {};
    for (0..8) |i| {
        if ($mod.__koru_grid_pods.used[i] == 0) continue;
        w.print("  {d}:({d},{d})v{d}", .{
            i,
            $mod.__koru_grid_pods.x[i],
            $mod.__koru_grid_pods.y[i],
            $mod.__koru_grid_pods.v[i],
        }) catch {};
    }
    w.writeAll("\n") catch {};

    const b = fbs.getWritten();
    var off: usize = 0;
    while (off < b.len) {
        off += std.posix.write(1, b[off..]) catch break;
    }
}

libs/enet:client(channels: 3)
| up cli |> libs/enet:dial(host: cli, ip: "127.0.0.1", port: 28800, channels: 3)
    | dialing ck |> for(0..3600)
        ! each _ |> libs/enet:service(host: cli, timeout_ms: 10)
            ! connect _ |> enter()
                |> std/io:eprint.ln("connected")
            ! packet pk |> libs/enet:packet.data(p: pk): d
                |> wire:nmc(d): code
                |> if (code == 2)
                    | then |> wire:pos.decode(d)
                        | pos p |> if (p.cn >= 0 and p.cn < 8)
                            | then |> std/grid:stored {
                                    pods[p.cn].used: 1, pods[p.cn].x: p.x, pods[p.cn].y: p.y,
                                    pods[p.cn].a: p.a, pods[p.cn].v: p.v,
                                    view[0].packets: view[0].packets + 1 }
                                |> if (@mod(view[0].packets, 2) == 0)
                                    | then |> std/grid:stored { view[0].frames: view[0].frames + 1 }
                                        |> draw(packets: view[0].packets)
                        | bad |> _
            ! disconnect dp |> std/io:eprint.ln("disconnected")
            | idle |> wire:input(thrust: 4, turn: -1): m
                |> libs/enet:send.key(host: cli, key: ck, channel: 0, data: m, reliable: false)
                    | sent |> libs/enet:flush(host: cli)
                    | err _ |> _
            | err _ |> _
        | done |> leave()
            |> std/io:eprint.ln("render done: {{ view[0].packets:d }} pkts, {{ view[0].frames:d }} frames")
            |> libs/enet:close(host: cli)
    | err e |> std/io:print.ln("dial err {{ e:s }}")
| err e |> std/io:print.ln("client err {{ e:s }}")
