// Web gauntlet rung-1 claimant — module-router, fully SSR'd.
//
// Six real routes, one 404, all bodies produced by `koru/dom:component`
// render tors under the native backend — no replayed capture strings.
// `Page` covers the flat routes, `SectionPage` the layout-wrapped ones.
// The nav's ` | ` separators survive verbatim: the scanner now treats an
// edge whitespace run as source formatting only when it contains a
// newline. `-&gt;` in the golden is just the escaped `>` in `src`.
//
// Build & Run:
//   koruc main.k && ./a.out
//
// Close:
//   python3 ../../closer/bytes_closer.py --base http://127.0.0.1:48201 --fixture module-router

import koru/dom
import orisha
import std/io

koru/dom:component(Page) {
    <html><head></head><body><nav><a href="/">home</a> | <a href="/about">about</a> | <a href="/docs">docs</a> | <a href="/docs/install">install</a> | <a href="/pricing">pricing</a></nav><hr><h1>{{ title:s }}</h1><p>{{ src:s }}</p></body></html>
}

koru/dom:component(SectionPage) {
    <html><head></head><body><nav><a href="/">home</a> | <a href="/about">about</a> | <a href="/docs">docs</a> | <a href="/docs/install">install</a> | <a href="/pricing">pricing</a></nav><hr><section><p>{{ layout:s }}</p><h1>{{ title:s }}</h1><p>{{ src:s }}</p></section></body></html>
}

orisha:handler = orisha:router(req)
! [GET /] |> Page-render(title: "home", src: "src/app.rs -> /"): b -> { status: 200, body: b, content_type: "text/html; charset=utf-8", extra_headers: "Vary: Accept\r\nVary: accept-encoding\r\n" }
! [GET /about] |> Page-render(title: "about", src: "src/app.rs (mod about) -> /about"): b -> { status: 200, body: b, content_type: "text/html; charset=utf-8", extra_headers: "Vary: Accept\r\nVary: accept-encoding\r\n" }
! [GET /docs] |> SectionPage-render(layout: "docs layout", title: "docs", src: "src/app/docs.rs -> /docs"): b -> { status: 200, body: b, content_type: "text/html; charset=utf-8", extra_headers: "Vary: Accept\r\nVary: accept-encoding\r\n" }
! [GET /docs/install] |> SectionPage-render(layout: "docs layout", title: "install", src: "src/app/docs/install.rs -> /docs/install"): b -> { status: 200, body: b, content_type: "text/html; charset=utf-8", extra_headers: "Vary: Accept\r\nVary: accept-encoding\r\n" }
! [GET /pricing] |> SectionPage-render(layout: "marketing group layout", title: "pricing", src: "src/app/_marketing/pricing.rs -> /pricing"): b -> { status: 200, body: b, content_type: "text/html; charset=utf-8", extra_headers: "Vary: Accept\r\nVary: accept-encoding\r\n" }
! [GET /api/health] -> { status: 200, body: "ok", content_type: "text/plain; charset=utf-8" }
! [*] -> { status: 404, body: "not found", content_type: "text/plain; charset=utf-8" }

orisha:serve(port: 48201)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln(f)
