# Rung-1 board — served-bytes conformance vs topcoat v0.10.0

Closer: `web/closer/bytes_closer.py`. Claimant: `web/app/main.k` (Orisha,
`date-header` worktree). Self-certification vs reference: 29/29 pass.

| fixture/case | verdict | detail |
|---|---|---|
| hello-world | **pass** | status+body byte-exact (102B), rendered — `Page-render` (koru/dom native SSR, `58cb9f1`) composes through `fmt.blk` for the doctype; `allocated!` on the render return auto-sets `body_allocated`, pump frees via `release-body`; `vary` ×2 via `Response.extra_headers`; tolerated-extra `connection`, `x-orisha`, `x-powered-by` per LEDGER P3 |
| path-query-params (6) | unmeasured | needs `:param`/`?query` surface (G3/G4) before any row can run |
| module-router (7) | **pass** | 7/7 byte-exact — all bodies rendered by `Page-render`/`SectionPage-render` (koru/dom native SSR) at request time; `body_allocated` auto-marked on the `allocated!` render return after the `continuation_codegen` obligation fix; 404 arm + `/api/health` literal bodies conform |
| request-response (15) | unmeasured | needs request body/JSON/form surface (G3) |

First green row landed 2026-10-05: `extra_headers` on `Response` (orisha
`date-header` @ `81c6236`) spells the missing `vary` lines verbatim.
Second green same day: module-router claimant (`web/app/module-router`),
which surfaced a real compiler gap — `body_allocated` keyed on inline-bodied
producers only, so a `*|> X-render : b -> { body: b }` arm silently leaked
the render buffer per request; fixed in koru `continuation_codegen` by
keying the mark on the invoked tor's `allocated!` return phantom.
Remaining fixtures wait on the request-side surface (G3/G4).
