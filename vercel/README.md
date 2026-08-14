# koru/vercel

Host a Koru/Orisha site on Vercel, turnkey — and Koru-owned. The release verbs
float onto the **compiler** from `import koru/vercel`, so a site's build/dev/deploy
are `koruc` commands, not a sidecar CLI:

```koru
// site.k — the whole site, pure Koru
import vercel

vercel:site {
    name: "site",
    root: "public",
    fallback: null,   // shell file, served ONLY for the declared routes
    routes: [],       // browser-only paths that hydrate from the shell
    backend: null,    // a live backend to reverse-proxy `dynamic` to
    dynamic: [],      // genuinely server-side path prefixes
    link: null,       // a dir with .vercel/project.json, so deploy hits an existing project
}
```

```bash
koruc site.k build      # embed ./public → wasm reactor → stage deploy/
koruc site.k dev        # serve the staged deployment locally
koruc site.k deploy     # vercel deploy --prod
```

A completely static site needs **no Koru beyond that one file**. `build` reads the
`vercel:site` declaration from the AST, generates the reactor from the committed
template, compiles it, and stages the Vercel deployable.

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
  index.k            # the pure-Koru contract + the site config tor
  index.kz           # the build/dev/deploy command implementations
  reactor/main.kz    # the committed wasm-reactor entry the build command emits
  scaffold/          # the Vercel adapter + config + local harness
  examples/hello-static/
```

## `.k`, front and center

`index.k` is pure Koru — no Zig, no socket, no `~`. The Zig half of this library
(the wasm reactor host seam: the exported request/response windows and `handle`)
is **generated** into your build directory by the `build` command. It is the
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
that cannot be baked (browser-only, `prerender = false`) declares them in
`routes`, and the adapter serves the shell for exactly those paths:

```koru
vercel:site {
    name: "site",
    root: "build",
    routes: ["/playground"],
    fallback: "200.html",
    backend: null,
    dynamic: [],
    link: null,
}
```

`/playground` then hydrates from the shell; `/nope` still 404s. This is the
house rule (no fallbacks — a degraded path becomes the default): the shell is a
declared real route, never a sweep for "anything not found".

## Hybrid: static reactor plus a live backend

A site with a genuinely dynamic surface (forms, admin, auth) declares the
backend and the `dynamic` prefixes it proxies:

```koru
vercel:site {
    name: "site",
    root: "build",
    routes: [],
    backend: "https://my-backend.example.com",
    dynamic: ["/api/", "/admin"],
    link: null,
}
```

The wasm reactor answers every baked static path (or a real 404); the listed
dynamic prefixes reverse-proxy to the backend.

## Status

- **`koruc build`/`dev`/`deploy` float under `import koru/vercel`** — verified on
  `examples/hello-static/`: `build` stages the deploy dir, `dev` serves it
  locally through the real adapter (missing paths → real 404).
- **Hybrid (static reactor + dynamic reverse-proxy) + project linkage** — the
  full surface (`routes`, `fallback`, `backend`, `dynamic`, `link`) is parsed from
  the `vercel:site` declaration and served. korulang.org publishes through this
  path: `examples/korulang-org` documents the config, and
  `korulang_org/scripts/publish-orisha.mjs` is `koruc site.k deploy` after baking
  the static site.
- Custom Koru handlers and owning the dynamic surface itself (Convex, serverless
  app logic) are the next increments, not yet wired by the builder.
