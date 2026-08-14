# korulang-org

How the live korulang.org is hosted through `koru/vercel`: an Orisha reactor.
The fully-prerendered static site (`~/src/korulang_org/build`) is embedded into
an Orisha wasm module and serves **every page** on Orisha; the data on the
client-rendered pages comes from Convex directly in the browser. Only the
genuinely server-side pieces are reverse-proxied to the korulang-org backend.

The publish path is `~/src/korulang_org/scripts/publish-orisha.mjs`: it bakes the
site, runs the deploy command, and verifies the live artifact. The hosting
surface is declared in the site's own `site.k` — importing `koru/vercel` floats
`build`/`dev`/`deploy` onto the compiler, so there is no sidecar CLI:

```koru
import vercel

vercel:site {
    name: "site",
    root: "build",                      // baked static site (STATIC_BUILD=1 build:local)
    fallback: "200.html",               // shell, served ONLY for the declared routes
    routes: ["/playground", "/learn"],  // browser-only paths that hydrate from the shell
    backend: "https://korulang-org.vercel.app",
    dynamic: ["/api/", "/blog/drafts"], // only true server pieces stay proxied
    link: "/Users/larsde/src/orisha/examples/korulang-site-wasm-vercel",
}
```

```bash
koruc site.k build      # embed build/ → wasm reactor → stage deploy/
koruc site.k dev        # serve the staged deployment locally through the real adapter
koruc site.k deploy     # build + vercel deploy --prod (project linkage carried from `link`)
```

The `link` field carries the existing Vercel project linkage (`.vercel/project.json`)
into the staged deploy dir, so `deploy` pushes to the live project instead of
minting a new one.

The surface, in order: baked static pages answer from the reactor (real page,
correct status/gzip/ETag); declared client routes (`/learn`, `/playground`) get
the shell to hydrate from; `/api/**` and `/blog/drafts` proxy to the backend; and
any path the site does not have is a real **404** — no SPA-shell sweep.

`/admin`, `/feedback`, `/ratings`, `/studio`, `/worldmodel`, `/share`,
`/hyperframe-demo`, `/present` were all reverse-proxied until the bake grew to
include them. They now serve as real prerendered files from Orisha; the stale
proxy entries were removed. The only remaining backend surface is the voice
endpoint (`/api/pixie-voice`) and the gated drafts review — both genuine server
logic, both next to port into Koru handlers.