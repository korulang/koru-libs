# korulang-org

How the live korulang.org is hosted through `koru/vercel`: an Orisha reactor.
The fully-prerendered static site (`~/src/korulang_org/build`) is embedded into
an Orisha wasm module and serves **every page** on Orisha; the data on the
client-rendered pages comes from Convex directly in the browser. Only the
genuinely server-side pieces are reverse-proxied to the korulang-org backend
(or run in the reactor — pixie-voice).

Publishing is one command — `koruc site.k deploy` — and the whole surface is
declared in the site's own `site.k`: importing `koru/vercel` floats
`build`/`dev`/`verify`/`deploy` onto the compiler, so there is no sidecar CLI
and no publish script in the repo. `deploy` runs the declared bake, embeds the
result, pushes (carrying the project linkage), and verifies the live site before
reporting success.

```koru
import vercel

vercel:site {
    name: "site",
    root: "build",                      // baked static site (STATIC_BUILD=1 build:local)
    fallback: "200.html",               // shell, served ONLY for the declared routes
    routes: ["/playground", "/learn"],  // browser-only paths that hydrate from the shell
    backend: "https://korulang-org.vercel.app",
    dynamic: ["/blog/drafts"],          // /api/ is gone: pixie-voice runs in the reactor
    link: "/Users/larsde/src/orisha/examples/korulang-site-wasm-vercel",
    bake: ["bun", "run", "build:local"], // the site's own generator, run before the embed
    verify: ["/", "/docs", "/admin"],    // must answer 200 with a REAL page after deploy
    pixie: true,
}
```

```bash
koruc site.k build                              # bake + embed build/ → stage deploy/
koruc site.k dev                                # serve the staged deployment locally
koruc site.k deploy                             # bake + build + push + verify the live site
koruc site.k deploy /blog/<new-post>            # … plus prove the new post is a real page
koruc site.k verify                             # re-check the live site any time
```

- `bake`/`bake_env` — the site's generator, run before the embed (`STATIC_BUILD=1`
  `bun run build:local` here, producing the `build/` the reactor embeds).
- `link` — carries the existing Vercel project linkage (`.vercel/project.json`)
  into the staged deploy dir, so `deploy` pushes to the live project instead of
  minting a new one.
- `verify` — paths that must answer HTTP 200 with a REAL page after deploy. A
  response equal to the shell body is a failed publish, not a success; extra
  paths ride argv (the per-publish freshness check).

The surface, in order: baked static pages answer from the reactor (real page,
correct status/gzip/ETag); declared client routes (`/learn`, `/playground`) get
the shell to hydrate from; `/blog/drafts` proxies to the backend; and
any path the site does not have is a real **404** — no SPA-shell sweep.

`/admin`, `/feedback`, `/ratings`, `/studio`, `/worldmodel`, `/share`,
`/hyperframe-demo`, `/present` were all reverse-proxied until the bake grew to
include them. They now serve as real prerendered files from Orisha; the stale
proxy entries were removed. The only remaining backend surface is the gated
drafts review — genuine server logic, next to port into Koru handlers.