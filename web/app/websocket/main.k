// Web gauntlet rung-2 claimant — websocket echo, against topcoat's `websocket`
// example (`GET /echo` -> WebSocketUpgrade -> echo text/binary frames back).
//
// The upgrade's check chain mirrors topcoat's `WebSocketUpgrade::from_request`
// (crates/topcoat-router/src/content/websocket/upgrade.rs) in order and in
// message text — Connection contains `upgrade`, then Upgrade == websocket,
// then Sec-WebSocket-Version == 13, then the key, then its validity — so the
// 400s are the reference's 400s, not approximations.
//
// Frames ride the pump seam: `! frame` -> orisha/pump:ws-frame, implemented
// here as echo. Ping/pong and close are answered at the pump itself.
//
// Build & Run:
//   koruc main.k && ./a.out
//
// Close:
//   python3 ../../closer/wire_closer.py --base 127.0.0.1:48214 --goldens ../../goldens/websocket close

import orisha
import orisha/pump
import std/fmt
import std/io

// The five upgrade checks in the extractor's order. `conn` is a token list —
// "keep-alive, Upgrade" still contains the upgrade token.
pub tor ws-check { conn: ?string, upgrade: ?string, version: ?string, key: ?string }
| ok
| bad string

proc ws-check|zig {
    const std = @import("std");
    const c = conn orelse return .{ .bad = "bad request: expected `Connection: upgrade` request header" };
    var has_upgrade = false;
    var tok = std.mem.tokenizeScalar(u8, c, ',');
    while (tok.next()) |t| {
        if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, t, " \t"), "upgrade")) {
            has_upgrade = true;
            break;
        }
    }
    if (!has_upgrade) return .{ .bad = "bad request: expected `Connection: upgrade` request header" };
    const u = upgrade orelse return .{ .bad = "bad request: expected `Upgrade: websocket` request header" };
    if (!std.ascii.eqlIgnoreCase(std.mem.trim(u8, u, " \t"), "websocket")) {
        return .{ .bad = "bad request: expected `Upgrade: websocket` request header" };
    }
    const v = version orelse return .{ .bad = "bad request: expected `Sec-WebSocket-Version: 13` request header" };
    if (!std.mem.eql(u8, std.mem.trim(u8, v, " \t"), "13")) {
        return .{ .bad = "bad request: expected `Sec-WebSocket-Version: 13` request header" };
    }
    const k = key orelse return .{ .bad = "bad request: missing `Sec-WebSocket-Key` request header" };
    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(k) catch
        return .{ .bad = "bad request: `Sec-WebSocket-Key` request header must be base64-encoded 16 bytes" };
    if (decoded_len != 16) {
        return .{ .bad = "bad request: `Sec-WebSocket-Key` request header must be base64-encoded 16 bytes" };
    }
    return .{ .ok = .{} };
}

pub tor presence { s: ?string }
| some string
| none

proc presence|zig {
    return if (s) |v| .{ .some = v } else .{ .none = .{} };
}

// Echo — the whole frame contract. `f.raw` is the reassembled payload and
// `f.opcode` decides text-vs-binary; ws-send echoes both for free.
orisha/pump:ws-frame = orisha/pump:ws-send(x: f, payload: f.raw, f.opcode)

orisha:handler = orisha:router(req)
! [GET /echo]
    |> orisha:header(req, name: "connection"): c
    |> orisha:header(req, name: "upgrade"): u
    |> orisha:header(req, name: "sec-websocket-version"): v
    |> orisha:header(req, name: "sec-websocket-key"): k
    |> ws-check(conn: c, upgrade: u, version: v, key: k)
    | bad msg -> { status: 400, body: msg, content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
    | ok |> orisha:ws-accept(req): acc
        |> presence(s: acc)
        | none -> { status: 400, body: "bad request: missing `Sec-WebSocket-Key` request header", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
        | some accept |> std/fmt:fmt.blk { connection: upgrade\r\nupgrade: websocket\r\nsec-websocket-accept: {{ accept:s }}\r\n }: extras -> { status: 101, body: "", content_type: null, extra_headers: extras }
! [*] -> { status: 404, body: "Not Found", content_type: "text/plain; charset=utf-8" }

orisha:serve(port: 48214)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln(f)
