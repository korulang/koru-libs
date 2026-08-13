# korulang-org

How the live korulang.org is hosted through `koru/vercel`: a hybrid reactor.
The fully-prerendered static site (`~/src/korulang_org/build`) is embedded into
an Orisha wasm module, and the genuinely live paths are reverse-proxied to the
korulang-org backend.

This is exactly what `~/src/korulang_org/scripts/publish-orisha.sh` runs on every
publish — the build/stage/deploy machinery lives in `koru/vercel`; the script is
only the site's thin config (bake → hybrid flags → link the live project).

```bash
koru-vercel build . \
  --root /Users/larsde/src/korulang_org/build \
  --fallback 200.html \
  --name site \
  --backend https://korulang-org.vercel.app \
  --dynamic /api/,/blog/drafts,/learn,/admin,/feedback,/present,/ratings,/studio,/worldmodel,/share,/hyperframe-demo \
  --link /Users/larsde/src/orisha/examples/korulang-site-wasm-vercel

koru-vercel dev   .      # local proof through the real adapter
koru-vercel deploy .     # vercel deploy --prod (aliased to korulang.org)
```

Static paths answer from the wasm reactor (real page, correct status/gzip/ETag);
unknown static paths fall back to `200.html`; the listed dynamic prefixes proxy
to the backend so nothing live goes dark.
