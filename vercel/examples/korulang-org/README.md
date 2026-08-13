# korulang-org

How the live korulang.org is hosted through `koru/vercel`: an Orisha reactor.
The fully-prerendered static site (`~/src/korulang_org/build`) is embedded into
an Orisha wasm module and serves **every page** on Orisha; the data on the
client-rendered pages comes from Convex directly in the browser. Only the
genuinely server-side pieces are reverse-proxied to the korulang-org backend.

This is exactly what `~/src/korulang_org/scripts/publish-orisha.mjs` runs on every
publish — the build/stage/deploy machinery lives in `koru/vercel`; the script is
only the site's thin config (bake → surface flags → link the live project).

```bash
koru-vercel build . \
  --root /Users/larsde/src/korulang_org/build \
  --name site \
  --routes /playground,/learn \      # browser-only routes hydrate from the shell
  --fallback 200.html \
  --backend https://korulang-org.vercel.app \
  --dynamic /api/,/blog/drafts \     # only true server pieces stay proxied
  --link /Users/larsde/src/orisha/examples/korulang-site-wasm-vercel

koru-vercel dev   .      # local proof through the real adapter
koru-vercel deploy .     # vercel deploy --prod (aliased to korulang.org)
```

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