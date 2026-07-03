# openssl — the definitive Koru OpenSSL client-TLS edition

**One-line pitch**: verified-by-default client TLS where skipping certificate
checks, leaking the free-chain, or writing after shutdown are all compile errors.

**Entry type**: new lift

**Author**: Claude Opus 4.8 (lift-challenge contestant, session 2026-07-03)

## What the C library does, and what we lift

[OpenSSL](https://www.openssl.org/) (libssl + libcrypto) is the C library that
terminates most of the world's TLS. Its raw API is also the most footgun-famous
in existence: a connection with `SSL_VERIFY_NONE` or a forgotten
`SSL_set1_host` looks identical to a secure one and has produced decades of
CVEs; the `SSL_free` / `SSL_CTX_free` / socket free-chain leaks if you forget a
link; `ERR_get_error()` errors sit silently in a thread-local queue; and
reading before the handshake or writing after shutdown are undefined behaviour,
not diagnostics.

This scope-v0 edition lifts **client-side connect / read / write / clean
shutdown** and compiles those four footguns away:

1. **Verified by default, uncompilable otherwise.** `connect` *always* verifies
   the peer certificate (`SSL_VERIFY_PEER` + the system CA store) **and** the
   hostname (`SSL_set1_host`). There is no parameter to weaken it. The only way
   to obtain an unverified channel is to type a different, loudly-named event —
   `connect.insecure`. Skipped verification cannot happen by omission.
2. **Handshake / shutdown are phantom states.** `connect` completes the full
   handshake before returning an `<open>` connection, so "read before
   handshake" is unrepresentable. `shutdown` moves the connection to `<closing>`
   and `read`/`write` require `<open>`, so "write after shutdown" does not
   compile.
3. **The free-chain is one phantom obligation.** `SSL`, `SSL_CTX`, and the
   socket are owned by a single handle carrying an `open!` obligation discharged
   only by `close`. Forget it and the build fails (`KORU030`).
4. **The error queue is lifted.** Every fallible event drains OpenSSL's error
   queue and surfaces the first diagnostic in an honest `| err` branch — never
   silent, never left to poison the next call.

The C library does all the real cryptographic work; we call `SSL_connect`,
`SSL_read`, `SSL_write`, `SSL_shutdown` and friends directly. Delete OpenSSL and
this package is an empty shell.

## Quick start

```koru
~import koru/openssl
~import std/io

var buf: [8192]u8 = undefined;

~koru/openssl:connect(host: "example.com", port: 443)
| ok conn |> koru/openssl:write(conn, data: "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n")
    | ok w |> koru/openssl:read(w.conn, buf: buf[0..])
        | data d |> std/io:print.ln("{{ d.bytes:s }}") |> koru/openssl:shutdown(d.conn)
            | ok s |> koru/openssl:close(s)
            | err e |> koru/openssl:close(e.conn)
        | eof ec |> koru/openssl:close(ec)
        | err re |> koru/openssl:close(re.conn)
    | err we |> koru/openssl:close(we.conn)
| err e |> std/io:print.ln("connect failed: {{ e.msg:s }}")
```

## API reference (v0)

| Event | Consumes → Produces | Purpose |
|---|---|---|
| `connect(host, port, allocator?)` | → `ok *Tls<open!>` \| `err Error` | Verified handshake. Only safe constructor. |
| `connect.insecure(host, port, allocator?)` | → `ok *Tls<open!>` \| `err Error` | **UNSAFE** escape hatch — skips all verification. |
| `write(conn: *Tls<!open>, data)` | → `ok {conn: *Tls<open!>, n}` \| `err {...}` | Send bytes. Requires `<open>`. |
| `read(conn: *Tls<!open>, buf)` | → `data {conn: *Tls<open!>, bytes}` \| `eof *Tls<open!>` \| `err {...}` | Fill a caller-owned buffer (zero-copy). Requires `<open>`. |
| `shutdown(conn: *Tls<!open>)` | → `ok *Tls<closing!>` \| `err {conn: *Tls<closing!>, ...}` | Send close_notify. `<open>` → `<closing>`. |
| `close(conn: *Tls<!open\|closing>)` | (void) | Free SSL + SSL_CTX + socket. Discharges the obligation. |

## The quadrifecta self-audit

- **DX**: the happy path is one `connect` and a chain of branches; the newcomer
  never types `SSL_CTX_new`, never chooses a method object, never sets a verify
  mode, never calls three different free functions, and never checks
  `SSL_get_error` by hand. The right thing (a fully verified connection) is the
  *only* unmarked thing. The one concept they must learn is the phantom chain
  `open → closing → discharged`, and the compiler teaches it by rejecting
  mistakes with named diagnostics.
- **Performance**: all lifting is compile-time — the phantom states and
  obligations are erased before codegen and cost nothing at runtime. The
  wrappers are thin: `read`/`write` are a single `SSL_read`/`SSL_write` into a
  **caller-owned buffer** (zero allocation, zero copy on the hot path). The only
  per-call allocations are the one-time `host` dup in `connect` and the error
  string on the error path. This is at parity with hand-written OpenSSL client
  code; *unmeasured* against a formal benchmark (no drag-race harness exists for
  TLS yet — stated honestly).
- **Correctness**: wrong usage is a build error. `tests/negative/write_after_shutdown.kz`
  is rejected with `KORU030: Phantom state mismatch: expected 'koru.openssl:open'
  but got 'koru.openssl:closing!'` (SHOWN below). Verification is enforced at
  runtime too: `tests/verify.kz` connects to `expired.badssl.com` and lands in
  `err` with `certificate has expired` — the verified `connect` can never return
  a usable handle for a bad cert.
- **Resource safety**: the `open!` obligation on every connection must be
  discharged by `close` (or by `shutdown` then `close`). `tests/negative/forgotten_close.kz`
  proves it: bind the connection to `_`, and the build fails with
  `KORU030: Resource '_' <open!> was not discharged` (SHOWN below). One `close`
  frees the entire chain — `index.kz:328` (`SSL_free`), `index.kz:331`
  (`SSL_CTX_free`), `index.kz:334` (socket close) — so a partial free is
  impossible.

## What it explicitly doesn't do (yet)

Scope was cut brutally to go narrow and deep. Honestly named edges:

- **Client only.** No server side (`SSL_accept`, no server certs/keys).
- **No renegotiation, no session resumption/tickets, no ALPN, no 0-RTT.**
- **One `SSL_read` per `read`.** `read` returns whatever a single OpenSSL read
  yields; looping until a full message / content-length is the caller's job (the
  examples read one chunk). No buffered "read all" or streaming helper yet.
- **Blocking sockets only.** No non-blocking / `WANT_READ`/`WANT_WRITE` retry
  loop, no timeouts, no poll integration.
- **No BIO chains.** I/O uses `SSL_set_fd` over a `std.net` socket rather than
  `BIO_new_ssl_connect`, so the "BIO ownership" footgun is sidestepped rather
  than lifted; the lifted free-chain covers SSL + SSL_CTX + socket. A BIO-based
  variant is future work.
- **No client certificates / mTLS.**
- **Homebrew/macOS include+lib paths are hardcoded** in `~std/build:requires`
  (`/opt/homebrew/opt/openssl@3`). A pkg-config-driven path is future work; see
  Toolchain findings.

## Toolchain findings

**1. Transient `findSubflowImpl` compile error from the koru repo's uncommitted
WIP (observed, not stably reproducible).** On the *first, cold* build of the
full-lifecycle flow (`connect → write → read → shutdown → close`), backend
compilation (Stage B) failed with, verbatim:

```
/Users/larsde/src/koru/src/comptime_eval.zig:428:13: error: use of undeclared identifier 'findSubflowImpl'
        if (findSubflowImpl(items, path)) |sub| {
            ^~~~~~~~~~~~~~~
```

`src/comptime_eval.zig` in the compiler repo is currently **uncommitted-modified
(+248 lines)** — a mid-flight refactor adding a comptime `invokePath` walker.
`findSubflowImpl` *is* defined (file scope, line 605); Zig analyses `invokePath`
lazily, so only programs that instantiate that path see it. After clearing the
local build cache the error did **not** recur across repeated cold runs, and the
file was unchanged between failure and success — so this reads as a race against
an actively-edited WIP file / a stale global-cache object, **not** a stable
defect in released compiler behaviour. Recorded here rather than fixed:
per the challenge rules I don't touch the compiler, and per house rules I don't
modify another session's uncommitted work. **Reading**: the *toolchain* is in a
transiently-broken WIP state; my koru is clean (it compiles and runs reliably
once the cache is warm). If it were a stable defect it would be a first-class
blocker; as observed it is a flake worth surfacing.

**2. `koruc --check` does not catch phantom *state* mismatches (only obligation
discharge is checked later).** `koruc --check tests/negative/write_after_shutdown.kz`
prints `✓ Shape checking passed`; the write-after-shutdown mismatch is only
caught by the phantom semantic checker during `koruc run` (Stage C). This is not
wrong — `--check` is documented as shape checking — but it means Gate-3 misuse
detection for *state* walls needs `koruc run`, not `--check`. Possibly worth a
note in the gate wording, or lifting the state check into `--check`.

**3. `~std/build:requires` has no portable way to express keg-only include/lib
paths.** I had to hardcode `/opt/homebrew/opt/openssl@3/{include,lib}`. A
`pkg-config`-backed helper (the `~std/deps:requires.system` block already knows
the `check` command) would let the build resolve these without a machine-specific
literal. Not a bug — a missing convenience.

Aside from #1, no defect was hit: clean, test-grounded koru compiled and ran.

## Proof of life

Linked against Homebrew `openssl@3` **3.6.2** (`/opt/homebrew/opt/openssl@3`),
verified via `pkg-config --modversion openssl` → `3.6.2`. All commands run from
the repo root with `koruc = /Users/larsde/src/koru/zig-out/bin/koruc`.

**Gate 1 — `koruc --check openssl/index.kz`:**
```
✓ Shape checking passed
```

**Gate 2 — full lifecycle, `koruc run openssl/tests/basic.kz`:**
```
TLS OK — read 864 bytes
Closed cleanly!
```

**Verification is enforced — `koruc run openssl/tests/verify.kz`** (connects to
`expired.badssl.com`):
```
Verified connect correctly REJECTED: certificate has expired
```

**Escape hatch — `koruc run openssl/tests/insecure.kz`:**
```
insecure connect accepted expired cert (as designed)
```

**Example — `koruc run openssl/examples/01_https_get.kz`:**
```
--- 864 bytes of TLS-protected response ---
HTTP/1.1 200 OK
...
```

**Gate 3a — negative test (state wall), `koruc run openssl/tests/negative/write_after_shutdown.kz`:**
```
error[KORU030]: Phantom state mismatch: expected 'koru.openssl:open' but got 'koru.openssl:closing!' for argument 's'
```

**Gate 3b — negative test (leak wall), `koruc run openssl/tests/negative/forgotten_close.kz --auto-discharge=disable`:**
```
error[KORU030]: Resource '_' <open!> was not discharged. Call one of: koru.openssl:close, koru.openssl:read, koru.openssl:shutdown, koru.openssl:write
```

## License

MIT (same as Koru). OpenSSL is under the Apache License 2.0.
