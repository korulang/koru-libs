# DOM gauntlet — first timed run, 2026-08-08

The rung-2 measurement the gauntlet deliberately did not take unattended:
CPU timings under the reference's own driver, run while Lars was present.

## Method

- Driver: the reference's `webdriver-ts` at HEAD `247fafa22c1f2caeb4cad179aa64cf444398cbc7`
  — the same clone the closer certified against. Default puppeteer runner,
  4× CPU throttling (the reference's own setting), 15 iterations per
  operation, drop-slowest 0, median reported.
- Browser: Chrome 151.0.7922.76, `--headless=new`, Apple Silicon (Darwin 25.5.0).
- App: `frameworks/keyed/koru/` = `dom/app/index.html` + `output_emitted.js`
  verbatim, plus the shared `/css/currentStyle.css` link the app's own header
  says to restore for a real run. Metadata `package.json`/`package-lock.json`
  only — no build step, the emitted file IS the implementation.
- Control: the reference's own `frameworks/keyed/vanillajs`, same run, same flags.
- The driver's plausibility check passed for both arms.

## Results (medians of 15, ms)

| operation | koru | vanillajs | ratio |
|---|---:|---:|---:|
| 01 create 1k rows | 30.2 | 27.9 | 1.08 |
| 02 replace all 1k | 51.3 | 30.9 | **1.66** |
| 03 partial update (every 10th) | 29.6 | 16.7 | **1.77** |
| 04 select row | 4.0 | 4.2 | **0.95** |
| 05 swap rows | 20.8 | 20.3 | 1.02 |
| 06 remove row | 16.9 | 16.2 | 1.04 |
| 07 create 10k rows | 349.6 | 312.9 | 1.12 |
| 08 append 1k to 1k | 36.0 | 33.9 | 1.06 |
| 09 clear 1k | 90.8 | 13.0 | **6.98** |

Geomean slowdown vs vanillajs: **1.44**. Excluding `09_clear1k`: **~1.18**.

Smoketest also measured transfer size: **4,573 bytes compressed** (gzip; the
4.1 KB figure elsewhere on this board is brotli — different codec, both real).

## Placement — ratios only, never absolute cross-machine numbers

Opponents' ratios computed from `dom/opponents/cohorts.json` (their published
Chrome-150 medians ÷ their published vanillajs medians). Koru's ratio is
local÷local from this run. Comparing ratio-to-vanilla across machines is the
fairest available normalization, not a perfect one — different hardware,
Chrome 150 vs 151, headed vs headless.

Geomean slowdown vs vanillajs: Solid 1.10 · Svelte 1.15 · Vue 1.26 · Elm 1.35
· **koru 1.44** · react-hooks 1.77 · react-zustand 1.86 · react-redux 2.32.

The two operations where runtime state libraries pay their price tag are
exactly where the compiled store is at hand-written parity: select-row
(koru 0.95 vs React-family 1.92–3.64) and swap-rows (koru 1.02 vs
React-family ~7.5).

## The three gaps, each with a located cause (read from `output_emitted.js`)

1. **clear 6.98×, the whole outlier.** `clear_event` empties the store through
   the sweep: per-row `take` with swap-last compaction, and every removal calls
   `remove_row_event` → `domRow(id)` = `document.querySelector` per row →
   an O(n²) DOM scan plus 1,000 individual `removeChild` calls. The control
   drops the tbody wholesale. A "store emptied" bulk path (or emitting
   tbody-clear when every row dies in one sweep) closes most of 7×.
2. **partial update 1.77×.** The sweep visits all 1,000 rows through per-row
   handler dispatch (`__store_qrow` → `__store_qbody` → `mark_event`), four
   object literals per row — the same per-row dispatch cost the ECS benchmark
   isolated as its 10.4× component. Known, named, compiler-side.
3. **replace-all 1.66×.** Rebuild inherits per-insert dispatch (insert →
   inserted-watch → label → row append), partially the same cost as (2).

No numbers in this file are invented; every figure is re-derivable from the
JSONs beside it or from `cohorts.json`.
