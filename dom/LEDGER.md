# DOM_GAUNTLET — exclusion ledger

One line per exclusion, with a reason. Version-controlled, in-tree, and read
before every round.

## The contract

**A contestant may PROPOSE an exclusion. It may never enact one.**

An unratified exclusion is conformance fraud with better paperwork — the
parity-run form of editing the test to match the compiler. Ratification is
Lars's, on the walk.

Without a ledger the bar is unreachable, exit-on-bar never fires, a finished run
reads as a failing one, and every round re-derives the same phantom gap and
spends a contestant on it. So it exists from round zero, even empty.

## Why this file is empty

**Deliberately.** The operation set is derived from the reference by the closer,
not recalled from memory by whoever opened the gauntlet. Seeding this file with
exclusions written from a recollection of js-framework-benchmark would be
inventing the spec and then excusing ourselves from parts of it — in that order.

First proposals arrive with the calibration board.

## Ratified

*(none yet)*

| # | excluded | reason | ratified |
|---|---|---|---|

## Proposed — NOT in force

| # | proposed | reason | proposed by |
|---|---|---|---|
| P1 | Memory benchmarks `21_ready-memory`, `22_run-memory`, `25_run-clear-memory` excluded from the Phase-1 conformance bar | Not structural DOM assertions — they read Chrome memory metrics (`benchmarksCommon.ts:219-256`). The calibration closer derived an 11-op bar (9 CPU ops + html structure + keyedness) that leaves these out; that omission is itself an exclusion and needs ratifying. They are Phase-2 material if anything. | calibration pull, 2026-08-07 |
| P2 | Startup (`30_startup`) and size (`40_sizes`) benchmarks excluded from the Phase-1 conformance bar | Lighthouse startup timing and bundle-size measurements (`benchmarksCommon.ts:258-274`) — mechanical but not DOM-structural, and size in particular has no comparable meaning for a compiled-Koru bundle until one exists. Phase 2 at the earliest. | calibration pull, 2026-08-07 |
| P3 | Visual rendering out of closer scope: bootstrap CSS styling and the `preloadicon` span | The reference mandates the shared bootstrap CSS (`README.md:547`, `index.html:6`) and the glyph preload (`README.md:571`), but both are presentational/perf concerns, not DOM structure. The closer asserts classes and attributes, never pixels. The vehicle should still ship the link + span verbatim — cheap and required for any Phase-2 run — so this excludes only *closer verification* of rendering, not the markup itself. | calibration pull, 2026-08-07 |
| P4 | Reference-repo integration machinery: `js-framework-benchmark` package.json metadata, `dev`/`build-prod` npm scripts, CSP-compliance check (`webdriver-ts/src/isCSPCompliant.ts`) | This is the machinery for submitting an implementation into their repo and table. The gauntlet runs whole-app comparisons locally and reads their published column; koru/dom is not (yet) a PR against krausest. No Koru analogue needed for the bar. | calibration pull, 2026-08-07 |
