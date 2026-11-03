// Web gauntlet probe — mixed-router, for the static-route fastpath.
//
// Thirteen routes mixing the two dispatch classes the router transform now
// splits at compile time: arms that never name `req` anywhere in their
// chain go to handler-lite (pre-Request dispatch), arms that consume any
// req field keep the full Request path. The gate is a two-build A/B —
// ORISHA_NO_LITE=1 builds the all-full-path reference — plus authored
// goldens under web/goldens/mixed-router.
//
// Build & Run:
//   koruc main.k && ./a.out                    (lite build)
//   ORISHA_NO_LITE=1 koruc main.k && ./a.out   (reference build)
//
// Close:
//   python3 ../../closer/bytes_closer.py --base http://127.0.0.1:48206 --fixture mixed-router
//   ./probe.sh                                 (A/B byte-diff, both builds)

import koru/dom
import orisha
import std/io

pub tor or-def { s: ?string, d: string } -> string
or-def -> s orelse d

pub tor version-string {} -> string
version-string -> "mixed-router/1.0"

koru/dom:component(Page) {
    <html><head></head><body><h1>{{ title:s }}</h1><p>{{ src:s }}</p></body></html>
}

orisha:handler = orisha:router(req)
! [GET /] |> Page-render(title: "home", src: "lite:handler-call"): b -> { status: 200, body: b, content_type: "text/html; charset=utf-8" }
! [GET /health] -> { status: 200, body: "ok", content_type: "text/plain; charset=utf-8" }
! [GET /version] |> version-string(): v -> { status: 200, body: v, content_type: "text/plain; charset=utf-8" }
! [GET /chain] |> or-def(s: null, d: "chain-answer"): v -> { status: 200, body: v, content_type: "text/plain; charset=utf-8" }
! [GET /search] |> orisha:query-param(req, name: "q"): q |> or-def(s: q, d: "(none)"): v -> { status: 200, body: v, content_type: "text/plain; charset=utf-8" }
! [GET /ua] |> orisha:header(req, name: "user-agent"): ua |> or-def(s: ua, d: "(none)"): v -> { status: 200, body: v, content_type: "text/plain; charset=utf-8" }
! [POST /echo] |> or-def(s: req.body, d: "(empty)"): b -> { status: 200, body: b, content_type: "text/plain; charset=utf-8" }
! [GET /item/:id] p |> or-def(s: p.id, d: "(none)"): v -> { status: 200, body: v, content_type: "text/plain; charset=utf-8" }
! [GET /shadow/*] |> Page-render(title: "wild", src: "shadow-wildcard"): b -> { status: 200, body: b, content_type: "text/html; charset=utf-8" }
! [GET /shadow/exact] -> { status: 200, body: "shadow-exact", content_type: "text/plain; charset=utf-8" }
! [GET /free/exact] -> { status: 200, body: "free-exact", content_type: "text/plain; charset=utf-8" }
! [GET /free/*] -> { status: 200, body: "free-wild", content_type: "text/plain; charset=utf-8" }
! [*] -> { status: 404, body: "not found", content_type: "text/plain; charset=utf-8" }

orisha:serve(port: 48206)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln(f)
