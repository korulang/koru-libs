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

## The three gaps — CAUSE CORRECTED BY MEASUREMENT, see `probes/`

⚠ **This section originally attributed the partial-update gap to per-row
handler dispatch, "known, named, compiler-side," by analogy to the ECS
benchmark's 10.4× dispatch component. That was pattern-matching, not
measurement, and the probes falsified it.** Dispatch is nearly free here. All
three gaps have ONE cause: the vehicle re-finds a row's element by scanning
the live DOM (`dom/app/main.kjs:24`, `document.querySelector("tr[data-id=…]")`)
because the component that created that element discarded the reference
(`dom/index.kz:333` mints `__root`, `:356` appends it and drops it).

Measured, not reasoned — hand-edited `output_emitted.js`, each variant
re-verified at 11/11 on the closer including keyedness:

| operation | as-shipped | retained node | bulk clear | both |
|---|---:|---:|---:|---:|
| partial update | 1.77 | **1.11** | 1.62 | 1.15 |
| replace all | 1.66 | **1.13** | 1.09 | 1.07 |
| clear 1k | 6.98 | **1.48** | 1.05 | 1.05 |
| geomean, 9 ops | 1.44 | 1.11 | 1.12 | **1.07** |

1. **clear 6.98×.** The 77.8 ms gap decomposes (medians, ms):
   vanillajs 13.0 · korubulk 13.6 · korubatch 15.6 · korumap 19.2 · shipped 90.8.

   | component | cost | share |
   |---|---:|---:|
   | scanning the page to re-find each row | **71.6** | 92% |
   | detaching 1,000 elements one at a time | 3.6 | 5% |
   | the store's own sweep + 1,000 `take`s | 2.0 | 3% |

   **The store is not the cost.** Its per-row removal machinery is 2 ms of 78.

   ⚠ `korubatch` ran in a SEPARATE session from the other variants, and its
   control says so: `03_update10th` reads 34.0 ms on a code path that variant
   does not touch, against 29.6 baseline — ~15% cross-session drift. So the
   71.6 figure is robust; the 3.6/2.0 split sits inside the noise floor and
   must not be quoted as precise.
2. **partial update 1.77×.** 100 marked rows × one page-scan each. Retention
   alone: 1.11. Per-row dispatch over all 1,000 rows accounts for roughly
   1.9 ms of 18.6 — it was never the problem.
3. **replace-all 1.66×.** Contains a full 1,000-row clear (`#run` is
   `clear() |> build(1000)`), so it inherits (1). Retention alone: 1.13.

⚠ The bulk-clear variant changes TWO things (skips the rule sweep AND writes
the DOM once), so it is a ceiling for a bulk verb, not a clean isolation.
The retained-node variant changes exactly one thing.

⚠ `04_select1k` reads 0.95 as-shipped and 1.12–1.24 across probes. That is
noise on a 4 ms operation, evidenced by a control: the bulk-clear variant does
not touch the selection path at all yet moved further than the variant that
did. It penalises every probe geomean above by a small amount.

No numbers in this file are invented; every figure is re-derivable from the
JSONs beside it, those in `probes/`, or from `cohorts.json`.

---

# The fix, measured — 2026-08-08, later the same day

The gap above was diagnosed as a forgotten reference, not a store cost. Both
halves were then built and the prediction held.

**What changed.** `std/store`'s request block now reaches the lifecycle arms,
so a row's birth and death can name its handle (`[id]h`, koru 690_250). And a
`koru/dom` component takes a `key` — the library's second non-rendered input,
exactly what `parent` already was — remembers the element it painted under it,
and `koru/dom:drop(key:)` is the inverse. The app's removal code is deleted.

**Clean three-way run**, all arms in one session so the ratios are internally
consistent (cross-session drift is real — the same untouched operation read
16.7ms in the first board and 23.2ms here; ratios travel, absolute times do
not).

| operation | hand-written | before | after | after ratio |
|---|---:|---:|---:|---:|
| 01 create 1k | 32.4 | 32.1 | 32.2 | 0.99 |
| 02 replace all | 33.4 | 53.7 | **37.3** | 1.12 |
| 03 partial update | 23.2 | 37.4 | 36.4 | 1.57 |
| 04 select row | 5.3 | 5.5 | **5.3** | 1.00 |
| 05 swap rows | 19.2 | 24.9 | **19.9** | 1.04 |
| 06 remove row | 14.8 | 15.8 | 16.1 | 1.09 |
| 07 create 10k | 300.0 | 331.9 | 344.3 | 1.15 |
| 08 append 1k | 32.8 | 34.4 | 34.9 | 1.06 |
| 09 clear 1k | 13.0 | 87.5 | **20.2** | 1.55 |

**Geomean over all nine: 1.45 → 1.16.**

**The prediction held.** The hand-edited probe that priced this fix before it
existed measured clear at 19.2ms; the real implementation measures 20.2 in the
three-way run and 19.6 on its own. Pricing before building was right about the
mechanism AND the magnitude.

Conformance re-verified at 11/11 including keyedness on the exact committed
build, before and after the dead-code cleanup.

## What is still open, in order of size

1. **Partial update, 1.57×.** Marking a row still finds its element by
   scanning the page — `domRow` is the last consumer of that search. Named in
   `dom/app/main.kjs`. The shape that retires it is re-painting a prop through
   the component that owns the markup, which needs the row's text to live in
   the store.
2. **Clear's remaining 1.55×.** This is the bulk-removal path: the probes put
   it at 1.05×. A verb is not enough — the removal hook is per-row and is
   where an app keeps its own counters, so an aggregate removal needs an
   aggregate form of that hook. `drain` is unavailable (it already means a
   row handing over an owned resource).
3. **Create 10k drifted 1.11 → 1.15**, the only number that moved the wrong
   way. Small, possibly noise, but a registry entry per row is the suspect.

## Stale walls found while measuring

`dom/tests/frontier/` pins seven compiler walls the vehicle is shaped around.
Re-run against the current compiler, most no longer fire. Two verified dead by
output, not just by compiling:

- **`char_column_js`** — a fixed-size text column lowers to JavaScript and
  prints identically on both targets. So the claim in `dom/app/main.k`'s header
  that a row's label cannot live in the store is STALE, and that claim is
  exactly what forces marking a row to be a hand-written DOM mutation.
- **`stripe_swallows_chain_tail`** — the repro now prints `tail survived`. The
  vehicle's `sweep`/`clear` tor-wrapping exists only to dodge this.

Three more (`rule_row_read_call_arg_js`, `rule_guard_cross_store_read`,
`rule_arm_if_row_read_condition`) run clean where they used to emit garbage;
their failure mode was wrong output rather than refusal, so read as fixed but
they deserve their stated expectations checked one at a time before the pins
are retired.
