# hello-static

The smallest thing `koru/vercel` hosts: a directory of static files, served
through Orisha as a wasm reactor on Vercel. No Koru of your own is required.

```bash
# 1. build — embed ./public into a wasm reactor, stage the deploy dir
koru-vercel build .          # from this directory

# 2. prove it locally through the real adapter
koru-vercel dev .            # then: curl localhost:3200/

# 3. ship
koru-vercel deploy .
```

What lands in `deploy/`:

- `wasm/handler.wasm` — the compiled Orisha reactor (a few KB, embeds `public/`)
- `api/serve.mjs` — the Vercel adapter (the only platform code)
- `vercel.json` — route every path to the adapter
- `test-adapter.mjs` — the local harness `koru-vercel dev` runs

The reactor serves pre-rendered HTTP: correct status/headers per file. A path
the site does not have is a **real 404** — no SPA shell sweep. (A site with
genuine client-only routes declares them with `--routes`; see the package
README. korulang.org does this for `/playground`.)
