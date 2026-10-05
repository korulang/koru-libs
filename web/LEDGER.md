# WEB_GAUNTLET — exclusion ledger

One line per exclusion, with a reason. Version-controlled, in-tree, and read
before every round.

## The contract

**A contestant may PROPOSE an exclusion. It may never enact one.**

An unratified exclusion is conformance fraud with better paperwork — the
parity-run form of editing the test to match the compiler. Ratification is
Lars's, on the walk.

## Why this file exists before the first fixture

Same reason as `dom/LEDGER.md`: without it the bar is unreachable, exit-on-bar
never fires, and every round re-derives the same phantom gap. It exists from
round zero, seeded only with what the opening survey already produced —
nothing recalled, nothing invented.

**Not exclusions (recorded here so nobody proposes them):** behaviors our
model already meets by a different architecture — e.g. anything `expr!` does
in topcoat that whole-program-JS does for us. Those are conformance results
on the board, not ledger entries (WEB_GAUNTLET.md, "the bar is observable
behavior").

## Ratified

| # | excluded | reason | ratified |
|---|---|---|---|
| P3 | Extra response headers tolerated iff on the closer's ENUMERATED allowlist (`TOLERATED_EXTRAS`: `connection`, `x-powered-by`, `x-orisha`) — reported as `tolerated-extra` in detail, never counted missing | Informational/branding headers are legal HTTP; the allowlist is explicit so any *new* extra still fails loudly. Missing headers are never tolerated. | Lars's delegation, 2026-10-05 |

## Proposed — NOT in force

| # | proposed | reason | proposed by |
|---|---|---|---|
| P4 | A `*|> X : b -> {…}` router arm where `b` carries `allocated!` but is NOT returned as `body` leaks `b` silently — codegen marks `body_allocated` for returned binds (fixed 2026-10-05) but has no discharge fallback for non-inline binds dropped on the floor; auto-discharge never sees router-lowered arms | The mark half is fixed; the free half wants the checker's obligation machinery, not a codegen heuristic. Surfaced by the module-router claimant; no fixture arm exercises it today | continuation_codegen fix, 2026-10-05 |
| P1 | Byte-identical HTML excluded from the rung-1 bar; the closer asserts structural DOM equality instead | Attribute order, whitespace, and self-closing spellings differ legitimately across emitters; the observable behavior is the tree a browser builds. Same discipline as the dom closer's structural assertions. | opening brief, 2026-10-04 |
| P2 | Interop/asset examples excluded from the rung-1 fixture set: `examples/htmx`, `datastar`, `alpine-ajax`, `tailwind`, `font`, `icon`, `mail`, `ui`, `session`, `cookie` | Third-party integration guides and asset/tooling surfaces, not serving-boundary behavior. `docs/cli`, `docs/font`, `docs/icon`, `docs/mail`, `docs/ui` likewise. Rung-1 fixtures derive from `hello-world`, `module-router`, `path-query-params`, `request-response` (+`runtime` family for rung 2). | opening brief, 2026-10-04 |
| P3 | ~~Extra response headers excluded from rung-1 fails~~ → ratified in narrowed form (enumerated allowlist, see Ratified) | Surfaced by the first hello-world row (board/rung1.md). Informational/branding headers are legal HTTP. | bytes-closer first run, 2026-10-05 |
