// Web gauntlet rung-1 claimant — request-response, against the sibling's
// http-surface stack (header / form / query-param tors + req.body).
//
// Fifteen cases. JSON bodies ride koru/yyjson: parse -> root ->
// object.get("name") -> as.string -> close, with the doc obligation
// discharged in-arm. Serde-shaped error text is authored emulation for the
// covered classes: "expected ident" for a non-JSON leading token (column
// derived from yyjson's failure offset), "invalid form value" for a missing
// required field. The 405 on GET /api/users is an authored arm — topcoat
// derives it from the method set; the router has no method-negation.
// Multipart field bytes are summed by walking --boundary delimiters off the
// request's own content-type (boundary-insensitive, per the closer spec).
//
// Build & Run:
//   koruc main.k && ./a.out
//
// Close:
//   python3 ../../closer/bytes_closer.py --base http://127.0.0.1:48203 --fixture request-response

import orisha
import koru/yyjson
import std/fmt
import std/io

pub tor or-empty { s: ?string } -> string
or-empty -> s orelse "(missing)"

pub tor or-def { s: ?string, d: string } -> string
or-def -> s orelse d

pub tor presence { s: ?string }
| some string
| none

proc presence|zig {
    return if (s) |v| .{ .some = v } else .{ .none = .{} };
}

pub tor streq { a: string, b: string }
| eq
| ne

proc streq|zig {
    const std = @import("std");
    return if (std.mem.eql(u8, a, b)) .{ .eq = .{} } else .{ .ne = .{} };
}

pub tor body-len { s: ?string } -> i64

proc body-len|zig {
    return if (s) |v| @intCast(v.len) else 0;
}

pub tor parse-int { s: string }
| ok i64
| bad string

proc parse-int|zig {
    const std = @import("std");
    const n = std.fmt.parseInt(i64, s, 10) catch return .{ .bad = "not a number" };
    return .{ .ok = n };
}

// JSON object writers — serde's emit is field order + minimal escaping; the
// escaper covers quote, backslash, and control bytes so string fields
// round-trip honestly rather than interpolate raw.
pub tor json-escape { s: string } -> string<std/io:allocated!>

proc json-escape|zig {
    const std = @import("std");
    const a = koru_allocator();
    var out = std.ArrayList(u8){};
    for (s) |c| {
        switch (c) {
            '"' => out.appendSlice(a, "\\\"") catch unreachable,
            '\\' => out.appendSlice(a, "\\\\") catch unreachable,
            '\n' => out.appendSlice(a, "\\n") catch unreachable,
            '\r' => out.appendSlice(a, "\\r") catch unreachable,
            '\t' => out.appendSlice(a, "\\t") catch unreachable,
            else => {
                if (c < 0x20) {
                    var buf: [8]u8 = undefined;
                    const esc = std.fmt.bufPrint(&buf, "\\u{x:0>4}", .{c}) catch unreachable;
                    out.appendSlice(a, esc) catch unreachable;
                } else {
                    out.append(a, c) catch unreachable;
                }
            },
        }
    }
    return out.items;
}

pub tor search-json { q: string, limit: i64 } -> string<std/io:allocated!>

proc search-json|zig {
    const std = @import("std");
    const a = koru_allocator();
    return std.fmt.allocPrint(a, "{{\"query\":\"{s}\",\"limit\":{d}}}", .{ q, limit }) catch unreachable;
}

pub tor user-json { name: string } -> string<std/io:allocated!>

proc user-json|zig {
    const std = @import("std");
    const a = koru_allocator();
    return std.fmt.allocPrint(a, "{{\"name\":\"{s}\"}}", .{name}) catch unreachable;
}

// serde_json's phrasing for a leading non-JSON token. yyjson reports the
// token's start offset; serde reports the byte where the literal diverged —
// for the covered class (leading bare ident) that is one byte later, so the
// 1-based column is offset + 2.
pub tor bad-json-body { pos: usize } -> string<std/io:allocated!>

proc bad-json-body|zig {
    const std = @import("std");
    const a = koru_allocator();
    return std.fmt.allocPrint(a, "bad request: invalid JSON syntax: expected ident at line 1 column {d} (at `.`)", .{pos + 2}) catch unreachable;
}

// Sum of all part payloads in a multipart body. Boundary is read off the
// request's content-type, so the count is insensitive to the closer's
// encoding choice.
pub tor multipart-total { body: ?string, ct: ?string } -> i64

proc multipart-total|zig {
    const std = @import("std");
    const b = body orelse return 0;
    const c = ct orelse return 0;
    const bi = std.mem.indexOf(u8, c, "boundary=") orelse return 0;
    const boundary = c[bi + "boundary=".len ..];
    var total: i64 = 0;
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, b, pos, "--")) |dash| {
        const after = dash + 2;
        if (after + boundary.len > b.len) break;
        if (!std.mem.eql(u8, b[after .. after + boundary.len], boundary)) {
            pos = dash + 1;
            continue;
        }
        var p = after + boundary.len;
        if (p + 2 <= b.len and std.mem.eql(u8, b[p .. p + 2], "--")) break;
        if (p + 2 <= b.len and std.mem.eql(u8, b[p .. p + 2], "\r\n")) {
            p += 2;
        } else {
            pos = dash + 1;
            continue;
        }
        const he = std.mem.indexOfPos(u8, b, p, "\r\n\r\n") orelse break;
        const payload_start = he + 4;
        var e = b.len;
        if (std.mem.indexOfPos(u8, b, payload_start, "\r\n--")) |idx| e = idx;
        total += @intCast(e - payload_start);
        pos = e + 2;
    }
    return total;
}

orisha:handler = orisha:router(req)
! [GET /api/search]
    |> orisha:query-param(req, name: "q"): q
    |> presence(s: q)
    | none -> { status: 400, body: "bad request: invalid form value: missing field `q` (at `.`)", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
    | some qs
        |> orisha:query-param(req, name: "limit"): lim
        |> or-def(s: lim, d: "10"): lim_s
        |> parse-int(s: lim_s)
        | ok n |> json-escape(s: qs): qe |> search-json(q: qe, limit: n): j |> std/io:free(content: qe) -> { status: 200, body: j, content_type: "application/json" }
        | bad _ -> { status: 400, body: "bad request: invalid form value: invalid digit (at `limit`)", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
! [GET /api/report.csv] -> { status: 200, body: "name,total\nAda,42\nGrace,64\n", content_type: "text/csv; charset=utf-8" }
! [POST /api/bytes]
    |> body-len(s: req.body): n
    |> std/fmt:fmt.blk { received {{ n:d }} bytes }: b -> { status: 200, body: b, content_type: "text/plain; charset=utf-8" }
! [POST /api/upload]
    |> body-len(s: req.body): n
    |> std/fmt:fmt.blk { received {{ n:d }} bytes }: b -> { status: 200, body: b, content_type: "text/plain; charset=utf-8" }
! [POST /api/raw-form]
    |> body-len(s: req.body): n
    |> std/fmt:fmt.blk { received {{ n:d }} bytes of form data }: b -> { status: 200, body: b, content_type: "text/plain; charset=utf-8" }
! [POST /api/form-echo]
    |> or-empty(s: req.body): b -> { status: 200, body: b, content_type: "application/x-www-form-urlencoded" }
! [POST /api/files]
    |> orisha:header(req, name: "content-type"): ct
    |> multipart-total(req.body, ct): n
    |> std/fmt:fmt.blk { received {{ n:d }} bytes across all fields }: b -> { status: 200, body: b, content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
! [POST /api/maybe-user]
    |> presence(s: req.body)
    | none -> { status: 200, body: "no user provided", content_type: "text/plain; charset=utf-8" }
    | some text
        |> koru/yyjson:parse(text)
        | ok doc
            |> koru/yyjson:root(doc): v
            |> koru/yyjson:object.get(doc, v, key: "name")
            | found fv |> koru/yyjson:as.string(doc, v: fv)
                | ok name |> std/fmt:fmt.blk { got user {{ name:s }} }: out
                    |> koru/yyjson:close(doc) |> std/io:free(content: name) -> { status: 200, body: out, content_type: "text/plain; charset=utf-8" }
                | wrong-type |> koru/yyjson:close(doc) -> { status: 400, body: "bad request: invalid type: expected a string (at `.name`)", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
            | not-found |> koru/yyjson:close(doc) -> { status: 400, body: "bad request: invalid JSON syntax: missing field `name` (at `.`)", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
        | err e |> bad-json-body(e.pos): m -> { status: 400, body: m, content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
! [POST /api/users]
    |> presence(s: req.body)
    | none -> { status: 400, body: "bad request: missing request body", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
    | some text
        |> koru/yyjson:parse(text)
        | ok doc
            |> koru/yyjson:root(doc): v
            |> koru/yyjson:object.get(doc, v, key: "name")
            | found fv |> koru/yyjson:as.string(doc, v: fv)
                | ok name |> json-escape(s: name): ne |> user-json(name: ne): j
                    |> koru/yyjson:close(doc) |> std/io:free(content: name) |> std/io:free(content: ne) -> { status: 200, body: j, content_type: "application/json" }
                | wrong-type |> koru/yyjson:close(doc) -> { status: 400, body: "bad request: invalid type: expected a string (at `.name`)", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
            | not-found |> koru/yyjson:close(doc) -> { status: 400, body: "bad request: invalid JSON syntax: missing field `name` (at `.`)", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
        | err e |> bad-json-body(e.pos): m -> { status: 400, body: m, content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
! [GET /api/users] -> { status: 405, body: "", content_type: null, extra_headers: "Allow: POST\r\n" }
! [POST /api/signed]
    |> orisha:header(req, name: "x-signature"): sig
    |> presence(s: sig)
    | none -> { status: 400, body: "bad request: missing x-signature header", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
    | some sv |> streq(a: sv, b: "topcoat-demo")
        | ne -> { status: 400, body: "bad request: invalid x-signature header", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
        | eq |> presence(s: req.body)
            | none -> { status: 400, body: "bad request: missing request body", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
            | some text
                |> koru/yyjson:parse(text)
                | ok doc
                    |> koru/yyjson:root(doc): v
                    |> koru/yyjson:object.get(doc, v, key: "name")
                    | found fv |> koru/yyjson:as.string(doc, v: fv)
                        | ok name |> json-escape(s: name): ne |> user-json(name: ne): j
                            |> koru/yyjson:close(doc) |> std/io:free(content: name) |> std/io:free(content: ne) -> { status: 200, body: j, content_type: "application/json" }
                        | wrong-type |> koru/yyjson:close(doc) -> { status: 400, body: "bad request: invalid type: expected a string (at `.name`)", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
                    | not-found |> koru/yyjson:close(doc) -> { status: 400, body: "bad request: invalid JSON syntax: missing field `name` (at `.`)", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
                | err e |> bad-json-body(e.pos): m -> { status: 400, body: m, content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
! [*] -> { status: 404, body: "Not Found", content_type: "text/plain; charset=utf-8" }

orisha:serve(port: 48203)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln(f)
