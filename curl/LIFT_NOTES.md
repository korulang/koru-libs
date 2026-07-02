# curl — quality pass: migrate to the current language

**One-line pitch**: bring the flagship libcurl wrapper back from
"dead on arrival" to compiling, running, and network-tested against the
current Koru compiler.

**Entry type**: quality pass on `curl` (existing package)

**Author**: Claude Sonnet 5, contestant session 2026-07-02

## What the C library does, and what we lift

libcurl is the industry-standard HTTP client — the same engine behind the
`curl` CLI, wget, git, and most HTTP client libraries across ecosystems. This
package wraps `curl_easy_*` and lifts connection cleanup into Koru's phantom
obligation system: every `Response` carries an `open!` obligation that must
be discharged via `close`, and forgetting it is either auto-fixed by the
compiler (auto-discharge) or a compile error (with auto-discharge off).

## What was actually broken, and what changed

Every quickstart example failed to compile. Two independent breakages, both
inside `curl/`:

1. **Stale `~proc` syntax (the commissioned bug).** `curl/index.kz` declared
   its four procs bare (`~proc get { ... }`, `~proc post { ... }`,
   `~proc post.with-headers { ... }`, `~proc close { ... }`) — the pre-KORU110
   form. Since the variant-mandatory rule landed, a bare proc is parseable but
   unresolvable at any call site (`error[KORU110]`). Fixed by tagging all four
   with `|zig`, matching the house style already established in
   `vaxis/index.kz`.
2. **A stale absolute path in `curl/koru.json` (found during verification,
   not commissioned).** `curl/koru.json` aliased `"koru"` to the literal
   string `/Users/larsde/src/koru-libs` — the *original* repo checkout, not
   wherever this package happens to live. Every other package resolves its
   `koru` alias with a *relative* path (`pq/examples/koru.json`:
   `"koru": "../.."`; `sqlite3/tests/koru.json`: `"libs": "../.."`); `curl`
   was the only package with an absolute one, and it silently pointed
   `~import koru/curl` at whatever `index.kz` happened to sit at that fixed
   path — invisible to normal editing, only surfaced by actually running the
   examples through the compiler. Fixed by making it relative (`".."`), same
   convention as the rest of the catalog.

Both were necessary — fixing only #1 does nothing observable if #2 keeps
resolving `koru/curl` to a different `index.kz` than the one on disk.

A third bug surfaced only once real network compilation ran the full
pipeline (`koruc run`, not just `--check`): `post.with-headers` called
`std.fmt.allocPrintZ`, a Zig std API removed in the Zig toolchain this
compiler now targets (0.15.2). Fixed by switching to
`std.fmt.allocPrintSentinel(alloc, fmt, args, 0)`, the current replacement —
found by reading `/opt/homebrew/Cellar/zig/0.15.2_1/lib/zig/std/fmt.zig`
directly rather than guessing a rename.

The three examples (`examples/01_simple_get.kz`, `02_post_json.kz`,
`03_error_handling.kz`) were also written against syntax generations old:
`=>` branch construction instead of `|>` chaining, `response`/`error` branch
names that don't match the event's real `ok`/`err` branches, `Header{ .key,
.val }` field names that don't match the real `Header{ name, value }`
struct, positional `std.fmt`-style `print.ln(..., args: [...])` instead of
the current `{{ expr:fmt }}` interpolation, and a required (non-optional)
`allocator` parameter that doesn't match the real `?std.mem.Allocator`
signature. All three were rewritten against the real, current `index.kz`
signatures and re-verified end-to-end.

## The quadrifecta self-audit

- **DX**: the happy path is `~koru/curl:get(url: "...") | ok r |>
  <use r.status, r.body> | err e |> <handle e.msg>` — one call, two branches,
  no manual cleanup required in the common case (auto-discharge inserts
  `close` for you; see `examples/01_simple_get.kz`, which never calls `close`
  and still runs clean). A newcomer never has to know libcurl's handle
  lifecycle, `curl_slist` header list management, or CURLcode error mapping —
  all of that is behind the `Response`/`Error` types.
- **Performance**: unmeasured beyond "it runs a real network round-trip and
  parses a real response" (SHOWN: `examples/01_simple_get.kz` against
  `https://httpbin.org/get` returns `Status: 200`, body length 222, on this
  run). The wrapper adds no extra copies beyond libcurl's own write callback
  buffering into a Zig `ArrayListUnmanaged(u8)` — same allocation shape a
  hand-written libcurl C client would use. No comptime-lifted DSL work was
  added or touched in this pass (that's `sqlite3`'s `~query` territory); this
  pass is a syntax migration plus two toolchain-visibility bugs, not a new
  optimization.
- **Correctness**: wrong usage — discarding a `Response` obligation with no
  reachable disposer — is a build error. Cite: `tests/negative/forgotten_close.kz`,
  which fails to compile under `--auto-discharge=disable` with
  `error[KORU030]: Resource '_' <open!> was not discharged. Call: koru.curl:close`.
- **Resource safety**: the `open!` obligation on `*Response` (declared at
  `curl/index.kz:73` — `~pub event get { ... } | ok *Response<open!>`) is
  discharged only by `close`, which consumes `*Response<!open>`
  (`curl/index.kz:276`). The compiler enforces this either explicitly (the
  caller writes `close`) or via auto-discharge (the compiler inserts it when
  it can trace a single legal disposer) — never silently.

## What it explicitly doesn't do (yet)

- No PUT/DELETE/PATCH — only GET, POST, and POST-with-headers exist. Out of
  scope for a quality pass; would be a separate slice (or arguably the
  intended v1 scope this v0 never finished, per `ECOSYSTEM.md`'s own
  "Implementation tasks" list).
- No streaming response body — the whole body is buffered into memory via
  the write callback, matching what `curl/index.kz` already did before this
  pass. Not touched.
- HTTP status codes (4xx/5xx) are not treated as errors — only
  transport-level failures (DNS, TLS, connection refused) produce `| err`.
  This is standard libcurl/HTTP-client behavior, not a gap, but it surprises
  newcomers coming from higher-level clients that auto-raise on 4xx/5xx —
  documented explicitly in `examples/03_error_handling.kz`.
- `tests/negative/forgotten_close.kz` only demonstrates the
  `--auto-discharge=disable` path. It does not (yet) pin a case that fails
  under *default* settings — auto-discharge in curl's case is genuinely
  robust enough that a plain "forgot to close" mistake gets silently and
  correctly fixed by the compiler by default. That's a DX win worth stating
  plainly, not a gap to route around.

## Toolchain findings

Two real findings, both inside curl's own files (not the compiler):

1. `curl/koru.json` had a hardcoded absolute path that made `~import
   koru/curl` from `curl/examples/*.kz` resolve against a *different*
   checkout of this repo than the one being edited — invisible via
   `--check` on `index.kz` alone (which passed), only surfaced by
   `--check`ing a file that actually imports the package through that
   `koru.json`. Fixed (see above). Worth flagging as a general lesson: a
   package-level `koru.json` with an absolute path is a landmine for anyone
   working in a worktree, fork, or CI checkout at a different path.
2. `std.fmt.allocPrintZ` doesn't exist in Zig 0.15.2 (this compiler's target
   Zig version) — real Zig-std staleness in the wrapped library code, not a
   Koru compiler defect. Fixed with `allocPrintSentinel`.

No Koru compiler defects hit in this pass — `koruc --check` and `koruc run`
behaved consistently and predictably throughout, including the auto-discharge
mechanics, which worked exactly as documented (`koruc --help`'s
`--auto-discharge=disable` description) once grounded against the koru
compiler's own regression tests (`330_025_auto_discharge_disabled`,
`330_043_auto_discharge_none`,
`2104_01_unused_connection`/`2104_21_open_tx_forgot_close` in
`/Users/larsde/src/koru/tests/regression/`).

## Proof of life

```
$ /Users/larsde/src/koru/zig-out/bin/koruc --check curl/index.kz
✓ Shape checking passed

$ /Users/larsde/src/koru/zig-out/bin/koruc --check curl/examples/01_simple_get.kz
✓ Shape checking passed
$ /Users/larsde/src/koru/zig-out/bin/koruc --check curl/examples/02_post_json.kz
✓ Shape checking passed
$ /Users/larsde/src/koru/zig-out/bin/koruc --check curl/examples/03_error_handling.kz
✓ Shape checking passed

$ /Users/larsde/src/koru/zig-out/bin/koruc run curl/examples/01_simple_get.kz
...
Running a.out...

=== HTTP Response ===
Status: 200
Body length: 222

$ /Users/larsde/src/koru/zig-out/bin/koruc run curl/examples/02_post_json.kz
...
Running a.out...

=== POST Response ===
Status: 200
Body length: 429

$ /Users/larsde/src/koru/zig-out/bin/koruc run curl/examples/03_error_handling.kz
...
Running a.out...

Got a response (transport succeeded)
Status: 404

$ /Users/larsde/src/koru/zig-out/bin/koruc run curl/tests/negative/forgotten_close.kz --auto-discharge=disable
...
Building executable...
error[KORU030]: Resource '_' <open!> was not discharged. Call: koru.curl:close

❌ Compiler coordination error: Phantom semantic validation failed
✗ Backend execution failed
```

All output above is real, from this session, on this repo state.
