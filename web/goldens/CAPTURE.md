# Calibration capture — topcoat golden fixtures

Captured 2026-10-05 (UTC) from upstream examples, for conformance-gauntlet
calibration. Two fixtures only; this documents what one capture costs.

## Pinned reference

- Repo: https://github.com/tokio-rs/topcoat
- Tag: `v0.10.0`
- `git rev-parse HEAD` after checkout: `3e7bb43948a61dadcdba5a79d99c0f3a75de1abc` — VERIFIED, matches pin.
- Scratch checkout: `/tmp/web-gauntlet/topcoat` (not committed anywhere).
- Checkout disk size: 839 MB total (820 MB `target/` after the two example
  builds, 9.0 MB `.git`, ~10 MB source). Source-only clone would be ~19 MB.

## Toolchain

- cargo 1.96.0-nightly (90ed291a5 2026-03-05)
- rustc 1.96.0-nightly (b41f22de2 2026-03-08)
- Note: repo's `rust-toolchain.toml` pins `channel = "stable"`; the ambient
  nightly on PATH was used and built everything with zero warnings/errors.

## Serving model (applies to all examples)

`topcoat::start(router)` binds `HOST`:`PORT` from env vars
(`crates/topcoat/src/serve.rs:114-115`), defaulting to `127.0.0.1:3000`.
No source edits needed — set `PORT`/`HOST` in the environment. Port 3000 was
occupied by two unrelated `a.out` listeners (SO_REUSEPORT), so high ports
were used and verified free via `lsof -iTCP:<port> -sTCP:LISTEN` before and after.

README suggests `cargo topcoat dev -p <name>` (dev server w/ live reload);
plain `cargo build -p <name>` + running `./target/debug/<name>` directly is
simpler and sufficient — the `topcoat::dev::script()` hook emits nothing when
no dev listener is configured, so bodies are identical either way.

## Fixture 1: `examples/hello-world` → `goldens/hello-world/`

- Package name: `hello-world`; run: `PORT=48111 HOST=127.0.0.1 ./target/debug/hello-world`
- Build: `cargo build -p hello-world`, cold cache
  - cargo-reported: 35.28s; wall-clock (full `time` around cargo incl. dep
    graph + fetch): 2m23s. The cargo number undercounts — trust wall time.
- Routes: `GET /` only.
- Capture:
  `curl -sS -D head.txt -o body.html http://127.0.0.1:48111/`
- Files: `hello-world/head.txt`, `hello-world/body.html` (200, 102-byte HTML).
- Nondeterminism audit (4 requests total, bodies + headers diffed):
  - Body: byte-identical every run. No CSRF, cookies, session IDs, timestamps.
  - Headers: only `date:` varies. `content-length: 102` stable.
  - Fields a conformance closer must normalize: **`date` response header only.**

**`date` note (landed 2026-10-05, orisha branch `date-header` @ 7109e90):**
Orisha's baked static responses were the only path without `Date` — the
dynamic head-builder already had it via a per-second threadlocal cache.
Landed as a send-time splice: `answer` marks the post-status-line offset
(`date_hole`), the pump inserts a whole `Date: …\r\n` line as a middle
writev iovec — same single syscall, no bake change, rodata untouched.
Measured cost: +41ns/writev worst case on a socketpair microbench.
Covers 200/304/HEAD/gzip/404 — verified on static-server. Note for the
bench lane: httparena's hand-baked `pipeline_response` now also gains
Date (+37B wire). The closer should still normalize `date` — values
always vary — but no Orisha response omits it anymore.

## Fixture 2: `examples/path-query-params` → `goldens/path-query-params/`

- Package name: `path-query-params`; run: `PORT=48112 HOST=127.0.0.1 ./target/debug/path-query-params`
- Build: `cargo build -p path-query-params`, warm cache: 3.2s wall.
- Routes + captures (one dir per route):
  - `GET /` → `root/` (200)
  - `GET /posts?page=2&q=rust` → `posts/` (200, reflects query params)
  - `GET /posts/42` → `posts-42/` (200, u32 path param)
  - `GET /docs/guides/getting-started` → `docs-guides-getting-started/` (200, catch-all)
  - `GET /posts/abc` → `posts-bad-id/` (400 `Bad Request`, plain-text body
    `bad request: Post ID must be a number!`)
  - `GET /posts?page=notanumber` → `posts-bad-query/` (307 `Temporary Redirect`,
    `location: ?`, empty body — the `query_params(error = redirect("?"))` path)
- Capture pattern: `curl -sS -D <dir>/head.txt -o <dir>/body.html <url>`
- Nondeterminism audit (3 extra requests per route × 4 routes, diffed):
  - Bodies: byte-identical every run.
  - Headers: only `date:` varies on every route.
  - Fields to normalize: **`date` response header only.**
- Quirk (not nondeterminism): `posts-42` body contains the literal text
  `parsed from the {post_id} path segment` — the `view!` macro doesn't
  interpolate `{ident}` in string literals. Expected upstream output; do not
  "fix" golden.

## Fixture 3: `examples/module-router` → `goldens/module-router/` (2026-10-05)

- Build: `cargo build -p module-router`, warm cache: ~6s (with fixture 4).
- Routes derived from the module tree — file/module names map to segments,
  `_marketing` is skipped in the URL (`_marketing/pricing.rs` → `/pricing`),
  and a 404 golden (`not-found/`) captured for the negative path.
- 7 cases: `GET /` `GET /about` `GET /docs` `GET /docs/install` `GET /pricing`
  `GET /api/health` `GET /nonexistent` — all 200 except the 404.

## Fixture 4: `examples/request-response` → `goldens/request-response/`

- 15 cases, GET and POST. **Module filenames snake_case → URL segments
  hyphenated**: `maybe_user.rs` → `/api/maybe-user` (confirmed: POST to
  `/api/maybe_user` 404s). Captured bodies include real behaviors: JSON echo,
  query→form parse with defaults, `Option<Json>` present/absent/malformed
  (200/200/400), raw form bytes, octet-stream, streaming upload, method
  mismatch (405), missing-signature rejection (400, `x-signature` header).
- `post-files`: multipart spec carried by `multipart-field:` in case.txt +
  `test.txt` payload sibling; the closer re-encodes with a fixed boundary.
  First capture was malformed (0 bytes received); golden re-captured against
  the canonical spec — spec is source of truth, not first capture.

## Closer (rung 1): `web/closer/bytes_closer.py`

- Stdlib-only replay closer: `case.txt` (request line + headers +
  `multipart-field:` marker) + optional `req-body.bin` → replay → diff vs
  `head.txt` + `body.*`. Normalizes `date` only. Verdicts pass/fail/cant-tell
  with cant-tell fraction in the summary.
- **Self-certified against the reference on 2026-10-05: 29/29 pass, 0 fail,
  0 cant-tell** — replaying each golden against its own origin server.

## Cost summary (the calibration answer)

- Clone + pin verify: ~60s
- First fixture end-to-end (cold build + run + capture + audit): ~3.5 min,
  dominated by the 143s cold build of the topcoat dep graph.
- Each additional example sharing the dep graph: ~15–30s total (3s incremental
  build, launch, curls, audit diffs).
- Fixture cost ≈ **one cold build (~2.4 min) once, then ~30s per example.**
- Whole pull, clone→servers-killed: ~6 min wall.
- Golden artifacts: 52 KB total, all deterministic modulo `date:` header.

## Cleanup

Both example servers killed; `lsof` confirms :48111 and :48112 free; no
processes left running. Scratch checkout left in `/tmp/web-gauntlet/topcoat`
(839 MB) — safe to `rm -rf` when calibration is done.
