# hello-static

The smallest thing `koru/vercel` hosts: a directory of static files, served
through Orisha as a wasm reactor on Vercel. The whole site is a pure-Koru file —
`site.k` — and the release verbs float onto the compiler from `import koru/vercel`.

```koru
// site.k — the whole site
import vercel

vercel:site {
    name: "site",
    root: "public",
    fallback: null,
    routes: [],
    backend: null,
    dynamic: [],
    link: null,          // a path with .vercel/project.json, to hit an existing project
    bake: [],            // no generator step — the site is already baked
    bake_env: [],
    alias: null,         // no verify — nothing deploys against a live alias here
    verify: [],
}
```

```bash
koruc site.k build      # embed ./public → wasm reactor → stage deploy/
koruc site.k dev        # serve the staged deployment locally (localhost:3200)
koruc site.k deploy     # vercel deploy --prod
```

`build` reads the `vercel:site` declaration from the AST, generates the reactor
from the committed template, compiles it, and stages `deploy/` (wasm + the Vercel
adapter + `vercel.json` + the local harness). `dev` serves that staged deployment
through the real adapter; a path the site does not have is a **real 404** — no
SPA-shell sweep. A site with genuine client-only routes declares them with
`routes` (see the package README).
