# koru/vercel

Host a Koru/Orisha site on Vercel, turnkey. A completely static site needs **zero
Koru of your own**: `koru-vercel build` embeds your static directory into an
Orisha WebAssembly reactor, compiles it, and stages a Vercel deployable. Then
`koru-vercel deploy` ships it.

```bash
koru-vercel build .     # embed ./public → wasm reactor → stage deploy/
koru-vercel dev  .      # prove it locally through the real adapter
koru-vercel deploy .    # vercel deploy --prod
```

## Why it feels like magic

Vercel gives a deployment no socket. It accepts the connection, parses HTTP, and
calls your function once with a request. Orisha already split its server the same
way (`orisha:answer` turns request bytes into response bytes and never names a
file descriptor; the pump owns the loop). So the wasm build keeps the *answer*
half — a **reactor** a host instantiates once and calls — and drops the pump
entirely. That is the whole trick, and it is why the module is a few KB and
imports almost nothing.

For a static site, your files are compiled *into* the module and served as
pre-rendered HTTP (correct status/headers per file; a missing path is a real
404, no per-request parsing, no libc).

## The layout

```
vercel/
  index.k            # the pure-Koru contract (the user-facing surface)
  bin/koru-vercel    # the turnkey builder (build/dev/deploy)
  scaffold/          # the Vercel adapter + config + local harness
  examples/hello-static/
```

## `.k`, front and center

`index.k` is pure Koru — no Zig, no socket, no `~`. The Zig half of this library
(the wasm reactor host seam: the exported request/response windows and `handle`)
is **generated** into your build directory by `koru-vercel build`. It is the
plumbing — fine as `.kz` — and you never write it. The convention matches Orisha's
own: the contract is `.k`, the Zig implementation is the companion `.kz`.

If you want Koru in the loop, author a `main.k` beside your static root (pure
Koru) and deploy that instead:

```koru
~import orisha
~orisha:static(name: "site", root: "public", fallback: "200.html")
~orisha:handler = orisha:static-router(name: "site")
```

## Discovery

The build needs the Koru compiler, the standard library, and Orisha. Override
with env vars if they aren't at the default locations:

| var | default |
|---|---|
| `KORU_REPO` | `~/src/koru` |
| `KORUC` | `$KORU_REPO/zig-out/bin/koruc` |
| `KORU_STDLIB` | `$KORU_REPO/koru_std` |
| `ORISHA_PATH` | `~/src/orisha/lib` |

## Real surface, fail loud — the shell is not a fallback

A path the site does not have is a **real 404**, always. The reactor never takes
a catch-all fallback: it answers baked files and 404s everything else.

The one exception is a **designed state**: a site with genuine client-only routes
that cannot be baked (browser-only, `prerender = false`) declares them, and the
adapter serves the shell for exactly those paths:

```bash
koru-vercel build . \
  --root ./build --name site \
  --routes /playground \
  --fallback 200.html
```

`/playground` then hydrates from the shell; `/nope` still 404s. This is the
house rule (no fallbacks — a degraded path becomes the default): the shell is a
declared real route, never a sweep for "anything not found".

## Hybrid: static reactor plus a live backend

A site with a genuinely dynamic surface (forms, admin, auth) is hosted with
`--backend` + `--dynamic`:

```bash
koru-vercel build . \
  --root ./build --name site \
  --backend https://my-backend.example.com \
  --dynamic /api/,/admin,/feedback \
  --link /path/to/a-linked-vercel-dir
```

The wasm reactor answers every baked static path (or a real 404); the listed
dynamic prefixes reverse-proxy to the backend. `--link` carries an existing
Vercel project linkage so `koru-vercel deploy` pushes to the same project rather
than creating a new one.

**korulang.org runs this way** — see `examples/korulang-org/` and the site's
`scripts/publish-orisha.mjs` (a source script, no shell), which is now only thin
site config around `koru-vercel build` + `koru-vercel deploy`.

## Status

- **Completely static sites** — verified (see `examples/hello-static/`).
- **Hybrid (static reactor + dynamic reverse-proxy)** — verified and live: it is
  how korulang.org is served today (`examples/korulang-org/`).
- Custom Koru handlers (`main.k`, pure `.k`) and owning the dynamic surface
  itself (Convex, serverless app logic) are the next increments, not yet wired by
  the builder.
