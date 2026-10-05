// Web gauntlet rung-1 claimant — path-query-params, against the sibling's
// http-surface request stack (query-param / form / wildcard segments).
//
// Six cases: SSR'd component pages for /, /posts/:id, /posts?page&q; the
// docs wildcard renders its segment list via fmt.blk (a dynamic-length
// list is not expressible in fixed component markup — the sibling router
// MATCHES `*` but binds nothing, so the arm reads the tail off req.path).
// The golden's two coercions are authored behavior: a non-numeric :post_id
// is a 400 text/plain, a bad ?page= is topcoat's 307 to bare `?`.
//
// Build & Run:
//   koruc main.k && ./a.out
//
// Close:
//   python3 ../../closer/bytes_closer.py --base http://127.0.0.1:48202 --fixture path-query-params

import koru/dom
import orisha
import std/fmt
import std/io

koru/dom:component(RootPage) {
    <html><head></head><body><h1>Path and query params</h1><ul><li><a href="/posts?page=2&amp;q=rust">query params: /posts?page=2&amp;q=rust</a></li><li><a href="/posts/42">path param: /posts/42</a></li><li><a href="/docs/guides/getting-started">catch-all param: /docs/guides/getting-started</a></li></ul></body></html>
}

koru/dom:component(PostPage) {
    <html><head></head><body><h1>Post {{ id:d }}</h1><p>parsed from the {post_id} path segment</p><p><a href="/posts?page=1">all posts</a></p></body></html>
}

koru/dom:component(PostsPage) {
    <html><head></head><body><h1>Posts</h1><p>page: {{ page:d }}</p><p>search: {{ q:s }}</p><p><a href="/">back home</a></p></body></html>
}

pub tor or-empty { s: ?string } -> string
or-empty -> s orelse "(missing)"

pub tor parse-int { s: string }
| ok i64
| bad string

proc parse-int|zig {
    const std = @import("std");
    const n = std.fmt.parseInt(i64, s, 10) catch return .{ .bad = "not a number" };
    return .{ .ok = n };
}

// The wildcard route binds nothing — `/docs/*` only matches. The arm hands
// req.path's tail here; each segment becomes one escaped <li> so a
// doc-tree path renders its parts verbatim (`docs/a/b` -> li a, li b).
pub tor doc-items { path: string } -> string<std/io:allocated!>

proc doc-items|zig {
    const std = @import("std");
    const __a = koru_allocator();
    var out = std.ArrayList(u8){};
    const sub = if (std.mem.startsWith(u8, path, "/docs/")) path["/docs/".len..] else path;
    var it = std.mem.splitScalar(u8, sub, '/');
    while (it.next()) |seg| {
        if (seg.len == 0) continue;
        out.appendSlice(__a, "<li>") catch unreachable;
        for (seg) |c| {
            switch (c) {
                '&' => out.appendSlice(__a, "&amp;") catch unreachable,
                '<' => out.appendSlice(__a, "&lt;") catch unreachable,
                '>' => out.appendSlice(__a, "&gt;") catch unreachable,
                else => out.append(__a, c) catch unreachable,
            }
        }
        out.appendSlice(__a, "</li>") catch unreachable;
    }
    return out.items;
}

orisha:handler = orisha:router(req)
! [GET /] |> RootPage-render(): r |> std/fmt:fmt.blk { <!DOCTYPE html>{{ r:s }} }: f -> { status: 200, body: f, content_type: "text/html; charset=utf-8", extra_headers: "Vary: Accept\r\nVary: accept-encoding\r\n" }
! [GET /posts/:post_id] p
    |> parse-int(s: p.post_id)
    | ok n |> PostPage-render(id: n): r |> std/fmt:fmt.blk { <!DOCTYPE html>{{ r:s }} }: f -> { status: 200, body: f, content_type: "text/html; charset=utf-8", extra_headers: "Vary: Accept\r\nVary: accept-encoding\r\n" }
    | bad _ -> { status: 400, body: "bad request: Post ID must be a number!", content_type: "text/plain; charset=utf-8", extra_headers: "Vary: accept-encoding\r\n" }
! [GET /posts]
    |> orisha:query-param(req, name: "page"): page
    |> or-empty(s: page): page_s
    |> parse-int(s: page_s)
    | ok n
        |> orisha:query-param(req, name: "q"): q
        |> or-empty(s: q): q_s
        |> PostsPage-render(page: n, q: q_s): r |> std/fmt:fmt.blk { <!DOCTYPE html>{{ r:s }} }: f -> { status: 200, body: f, content_type: "text/html; charset=utf-8", extra_headers: "Vary: Accept\r\nVary: accept-encoding\r\n" }
    | bad _ -> { status: 307, body: "", content_type: null, extra_headers: "Location: ?\r\n" }
! [GET /docs/*] |> doc-items(req.path): items
    |> std/fmt:fmt.blk { <!DOCTYPE html><html><head></head><body><h1>Documentation path</h1><ul>{{ items:s }}</ul><p><a href="/">back home</a></p></body></html> }: f -> { status: 200, body: f, content_type: "text/html; charset=utf-8", extra_headers: "Vary: Accept\r\nVary: accept-encoding\r\n" }
! [*] -> { status: 404, body: "Not Found", content_type: "text/plain; charset=utf-8" }

orisha:serve(port: 48202)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln(f)
