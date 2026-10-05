// Web gauntlet rung-1 claimant — Orisha serving the topcoat golden bytes.
//
// hello-world is the first honest row AND the first SSR row: `Page` is a
// `koru/dom:component` — under the zig backend it synthesizes
// `Page-render(title, heading) -> string<std.io:allocated!>`, the native
// render artifact. The route hands that owned buffer to the Response as
// `body_allocated: true`, so pump's release-body discharges the
// `allocated!` obligation at send time. `<!DOCTYPE` is outside the markup
// dialect (the scanner refuses it), so the doctype is comptime-stringed
// into the body head.
//
// Build & Run:
//   koruc main.k && ./a.out
//
// Close:
//   python3 ../closer/bytes_closer.py --base http://127.0.0.1:48200 --fixture hello-world

import koru/dom
import orisha
import std/fmt
import std/io

koru/dom:component(Page) {
    <html><head><title>{{ title:s }}</title></head><body><h1>{{ heading:s }}</h1></body></html>
}

orisha:handler = orisha:router(req)
! [GET /] |> Page-render(title: "Hello world", heading: "Hello, World!"): html |> std/fmt:fmt.blk { <!DOCTYPE html>{{ html:s }} }: page -> { status: 200, body: page, content_type: "text/html; charset=utf-8", extra_headers: "Vary: Accept\r\nVary: accept-encoding\r\n" }
! [*] -> { status: 404, body: "Not Found", content_type: "text/plain" }

orisha:serve(port: 48200)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln(f)
