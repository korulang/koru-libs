// Web gauntlet rung-1 claimant — Orisha serving the topcoat golden bytes.
//
// hello-world is the first honest row: a GET / returning the captured
// topcoat body. Exercises the whole dynamic path — request parse, router,
// head build, Date splice, body send — with zero SSR machinery.
//
// Build & Run:
//   koruc main.k && ./a.out
//
// Close:
//   python3 ../closer/bytes_closer.py --base http://127.0.0.1:48200 --fixture hello-world

import orisha
import std/io

orisha:handler = orisha:router(req)
! [GET /] -> { status: 200, body: "<!DOCTYPE html><html><head><title>Hello world</title></head><body><h1>Hello, World!</h1></body></html>", content_type: "text/html; charset=utf-8", extra_headers: "Vary: Accept\r\nVary: accept-encoding\r\n" }
! [*] -> { status: 404, body: "Not Found", content_type: "text/plain" }

orisha:serve(port: 48200)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln(f)
