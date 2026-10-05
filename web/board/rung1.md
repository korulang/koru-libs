# Rung-1 board — served-bytes conformance vs topcoat v0.10.0

Closer: `web/closer/bytes_closer.py`. Claimant: `web/app/main.k` (Orisha,
`date-header` worktree). Self-certification vs reference: 29/29 pass.

| fixture/case | verdict | detail |
|---|---|---|
| hello-world | **pass** | status+body byte-exact (102B); `vary` ×2 spelled via new `Response.extra_headers` (orisha `date-header` branch); tolerated-extra `connection`, `x-orisha`, `x-powered-by` per LEDGER P3 |
| path-query-params (6) | unmeasured | needs `:param`/`?query` surface (G3/G4) before any row can run |
| module-router (7) | unmeasured | body needs SSR (G10) or embedded static equivalence |
| request-response (15) | unmeasured | needs request body/JSON/form surface (G3) |

First green row landed 2026-10-05: `extra_headers` on `Response` (orisha
`date-header` @ `81c6236`) spells the missing `vary` lines verbatim.
Remaining fixtures wait on the request-side surface (G3/G4) and SSR (G10).
