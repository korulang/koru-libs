# Rung-1 board — served-bytes conformance vs topcoat v0.10.0

Closer: `web/closer/bytes_closer.py`. Claimant: `web/app/main.k` (Orisha,
`date-header` worktree). Self-certification vs reference: 29/29 pass.

| fixture/case | verdict | detail |
|---|---|---|
| hello-world | **pass** | status+body byte-exact (102B), rendered — `Page-render` (koru/dom native SSR, `58cb9f1`) composes through `fmt.blk` for the doctype; `allocated!` on the render return auto-sets `body_allocated`, pump frees via `release-body`; `vary` ×2 via `Response.extra_headers`; tolerated-extra `connection`, `x-orisha`, `x-powered-by` per LEDGER P3 |
| path-query-params (6) | **pass** | 6/6 byte-exact on the sibling's `http-surface` stack — `:post_id` param + in-arm `parse-int` union (400 on bad), `orisha:query-param` ×2, `*`-wildcard match reading tail off `req.path`, 307 `Location: ?` via `extra_headers`; required one orisha fix (`content_type: null` now omits the header — was an unspellable hard default) |
| module-router (7) | **pass** | 7/7 byte-exact — all bodies rendered by `Page-render`/`SectionPage-render` (koru/dom native SSR) at request time; `body_allocated` auto-marked on the `allocated!` render return after the `continuation_codegen` obligation fix; 404 arm + `/api/health` literal bodies conform |
| request-response (15) | **pass** | 15/15 byte-exact on `http-surface` — JSON via `koru/yyjson` chains (parse→root→object.get→as.string→close, obligation discharged in-arm), `orisha:form`/`query-param`/`header` + `req.body`, multipart byte-sum walking the request's own boundary, authored 405+`Allow` arm (topcoat derives it; the router has no method-negation), serde-shaped error text emulated for covered classes (column off yyjson's failure offset) |

First green row landed 2026-10-05: `extra_headers` on `Response` (orisha
`date-header` @ `81c6236`) spells the missing `vary` lines verbatim.
Second green same day: module-router claimant (`web/app/module-router`),
which surfaced a real compiler gap — `body_allocated` keyed on inline-bodied
producers only, so a `*|> X-render : b -> { body: b }` arm silently leaked
the render buffer per request; fixed in koru `continuation_codegen` by
keying the mark on the invoked tor's `allocated!` return phantom.

Third green: path-query-params (`web/app/path-query-params`) — the first
claimant on the sibling's `http-surface` request surface rather than
`date-header`. Fourth: request-response (`web/app/request-response`) —
yyjson obligation chains in router arms, multipart boundary walk,
serde-shaped error emulation. Two http-surface gaps the claimants forced:
`content_type: null` omits the header (was a hard `text/plain` default) and
`405` joins the reason table (was "Unknown") — committed `4836e22`.

Rung-1 is fully green: 29/29 cases conform across all four fixtures —
re-verified against merged orisha `main` (date-header + http-surface
landed as `cafeb18`/`7b25eba`); all claimants now point at the merged
library, not the worktrees.
