# The opponent set — cohorts for the DOM gauntlet

This is the opponent table for `DOM_GAUNTLET.md`: the reference benchmark's 181
keyed implementations reduced to a defensible set we compare against. **We never
run anyone else's code — every number below is read from the project's own
published results.** Classification was done by reading each implementation's
source and dependency manifest in the reference repo, not by recognising names;
every entry carries its evidence.

## Where these numbers come from

- Reference: **krausest/js-framework-benchmark**, keyed division, commit `247fafa22c1f`
  ("incremental run", 2026-07-28). Checked 2026-08-07 against GitHub: that commit
  is still the newest one touching the published results file, so this is the
  current dataset, not a stale one.
- Data file: `webdriver-ts/results.json` — raw sample arrays for 248 frameworks
  x 15 benchmarks. The numbers below are **medians of those samples**, computed
  at pull time (2026-08-07). Nothing was re-run, estimated, or interpolated.
- Browser: Chrome 150.0.7871.47 (stated by the project's result viewer,
  `webdriver-ts-results/src/App.tsx:28`). Because the dataset is built up
  incrementally, individual rows may have been measured under adjacent Chrome
  versions — that is the reference project's own practice, recorded here so a
  future round knows what it is comparing against.
- Units: operation timings in **ms** (some operations run under deliberate CPU
  throttling — that is part of the benchmark's spec). Memory in **MB**. Sizes in
  **KB**, where "compressed" means **brotli** over all implementation files
  excluding css (`benchmarksSize.ts:20-24`). First paint in **ms**.
- Machine-readable version of everything on this page: `cohorts.json` next to
  this file.

An implementation can appear in more than one cohort; overlaps are stated
rather than forced into one box.

---

## Cohort A — the store cohort (the direct opponents)

These are the implementations whose defining feature is an **external
state-management layer** bolted onto a rendering framework. This gauntlet's
thesis is that a compiled store beats a runtime one — these are the entries that
ship the runtime one.

### The headline sub-table: same renderer, different store

Fourteen entries pair the **same React renderer** with a different state layer.
That is a controlled experiment someone else already ran for us: the renderer is
held constant, so the differences below are the **cost of the store itself**.
Sorted by the partial-update operation (update every 10th row of 1,000 — the
operation a store exists to make cheap):


| implementation | store | create 1k | replace 1k | partial update | select row | swap rows | remove row | create 10k | append 1k | clear 1k |
|---|---|---|---|---|---|---|---|---|---|---|
| react-hooks | (none — plain React baseline) | 23.6 | 29.1 | 13.6 | 4.8 | 84.9 | 10.9 | 424.3 | 28.1 | 16.3 |
| react-mlyn | mlyn subscribable state | 26.4 | 30.6 | 13.4 | 5.2 | 87 | 10.8 | 415.9 | 31.5 | 10.7 |
| react-tagged-state | react-tagged-state signals | 23.9 | 29.4 | 13.8 | 4.6 | 84.8 | 10.4 | 419.3 | 29.2 | 16.5 |
| react-rxjs | RxJS streams as state | 25.6 | 29.2 | 14.2 | 5.1 | 84.8 | 10.4 | 361.4 | 29.6 | 17.7 |
| react-supergrain | Supergrain store | 25.8 | 32 | 14.4 | 5.8 | 12.6 | 12.1 | 422.2 | 31.4 | 18 |
| react-zustand | Zustand | 24.8 | 30.5 | 14.6 | 4.8 | 85 | 11 | 439.3 | 29.4 | 19.7 |
| react-mobX | MobX observables | 26.8 | 32.9 | 14.8 | 5.5 | 87.9 | 10.9 | 453.9 | 31.6 | 17.1 |
| react-kr-observable | kr-observable observables | 26 | 30.3 | 14.8 | 4.7 | 85.2 | 10.9 | 469.4 | 30.6 | 17 |
| legend-state | Legend-State observables | 29.3 | 33.9 | 15.7 | 4.9 | 87.7 | 12 | 447.3 | 32.2 | 13.1 |
| react-redux-hooks | Redux, hooks API | 26.8 | 30.3 | 16.8 | 6.2 | 86.8 | 11.4 | 436.6 | 31.4 | 19.1 |
| react-redux | Redux, connect() API | 28.9 | 34.4 | 16.9 | 9.1 | 87.7 | 22.8 | 416.6 | 33.7 | 21 |
| react-redux-rematch | Redux via the Rematch framework | 28.7 | 34.8 | 17.6 | 8.9 | 87.6 | 22.9 | 418.8 | 33.7 | 20.8 |
| react-tracked | react-tracked proxy-based tracking | 25 | 31.6 | 19.4 | 9.5 | 88.4 | 12.4 | 444.1 | 31.5 | 17.4 |
| react-redux-hooks-immutable | Redux + Immutable.js state | 26.9 | 31.7 | 20.8 | 6.7 | 92.6 | 13.2 | 450.3 | 32.1 | 18.1 |
| valtio | Valtio proxy store | 28.8 | 32.7 | 22.6 | 9 | 91.7 | 15.6 | 496.2 | 35.6 | 14.2 |

Read it plainly: plain React does the partial update in
**13.6 ms**. Every store pairing pays on top of
that, from roughly nothing (react-mlyn 13.4 ms,
react-tagged-state 13.8 ms) through
the Redux family (16.8–20.8 ms)
to Valtio at 22.6 ms — **1.7x
the plain-React cost, before the renderer has done anything different.** That
spread, on identical rendering machinery, is the runtime price of a store. The
gauntlet's claim is that a compiled store makes that price ~zero; this sub-table
is the yardstick the claim will be measured against.

For scale: the hand-written floor (`vanillajs`) does the same operation in
**9.6 ms**, and the fine-grained exemplar
(`solid`) in 10.2 ms.

### The rest of cohort A — stores over other renderers


| implementation | store / renderer | create 1k | replace 1k | partial update | select row | swap rows | remove row | create 10k | append 1k | clear 1k |
|---|---|---|---|---|---|---|---|---|---|---|
| preact-kr-observable | kr-observable observables over Preact | 31.6 | 34 | 14.2 | 3.7 | 13.6 | 10.4 | 327.1 | 35.5 | 14.4 |
| vue-pinia | Pinia over Vue | 24.4 | 28.3 | 14.2 | 5.3 | 14.1 | 13.9 | 269.7 | 28.8 | 12.8 |
| san-store | san-store flux store over San | 32.4 | 30.7 | 24.9 | 9.4 | 24.6 | 12 | 254.1 | 33.3 | 15.2 |
| mobx-jsx | MobX driving a Solid-style fine-grained renderer | 23.9 | 26.4 | 10.6 | 3 | 12.7 | 9.7 | 248.8 | 26.6 | 9.2 |
| reatom-jsx | Reatom atoms with Reatom's renderer | 29.8 | 35.3 | 10.7 | 2.8 | 12.1 | 9.4 | 311.3 | 33.4 | 15.9 |
| re-frame | re-frame event/subscription store over Reagent (ClojureScript) | 50.8 | 58.2 | 36.9 | 17.2 | 105.6 | 24.3 | 490.3 | 55.9 | 49.9 |
| preact-signals | borderline store entry over Preact | 30.4 | 32 | 10.3 | 3.9 | 14.3 | 10.9 | 305.6 | 31.7 | 13 |
| solid-store | borderline store entry over Solid | 21.9 | 25.2 | 10.2 | 3.4 | 13.4 | 10.6 | 237.2 | 26 | 10.2 |

The same controlled experiment exists piecewise outside React — each store row
next to its plain-renderer baseline, partial update and create-1k:

| store row | partial upd | create 1k | its plain baseline | partial upd | create 1k |
|---|---|---|---|---|---|
| vue-pinia | 14.2 | 24.4 | vue | 12.4 | 24.5 |
| preact-kr-observable | 14.2 | 31.6 | preact-hooks | 20 | 25.9 |
| preact-signals | 10.3 | 30.4 | preact-hooks | 20 | 25.9 |
| san-store | 24.9 | 32.4 | san-composition | 12.7 | 25.4 |
| solid-store | 10.2 | 21.9 | solid | 10.2 | 20.8 |
| re-frame | 36.9 | 50.8 | reagent | 21.4 | 37.6 |

Two rows are **borderline members, included with their asterisks stated**:
`preact-signals` (the signals package is external but ships from the Preact team
itself) and `solid-store` (the store ships *inside* the solid-js package, so it
is not an external layer at all — it is here because Solid-vs-solid-store is the
same renderer/store split the React rows give us).
`re-frame` sits in both cohort A and cohort B: it is a real external store
(events + subscriptions) and it is authored in ClojureScript.

### Cohort A footprint


| implementation | size unc. KB | size br. KB | ready mem MB | run mem MB | run+clear MB | first paint ms |
|---|---|---|---|---|---|---|
| react-hooks | 190.3 | 51.4 | 1.2 | 4.36 | 1.91 | 222.6 |
| react-mlyn | 213.1 | 49.2 | 1.4 | 7.13 | 2.83 | 222 |
| react-tagged-state | 181.6 | 49.5 | 1.18 | 4.99 | 1.92 | 210.6 |
| react-rxjs | 196.8 | 53.3 | 1.25 | 4.3 | 1.98 | 231.3 |
| react-supergrain | 202 | 54.9 | 1.23 | 5.84 | 2.62 | 250.6 |
| react-zustand | 182.9 | 49.8 | 1.2 | 6.07 | 1.99 | 212.6 |
| react-mobX | 242.8 | 64 | 1.56 | 6.17 | 2.37 | 273.6 |
| react-kr-observable | 190.1 | 51.8 | 1.2 | 5.6 | 1.93 | 223.3 |
| legend-state | 157.1 | 45.2 | 1.14 | 5.66 | 4.74 | 188.6 |
| react-redux-hooks | 185.9 | 50.6 | 1.19 | 5.92 | 1.98 | 210.9 |
| react-redux | 193.9 | 52.9 | 1.29 | 8.61 | 2.16 | 225.7 |
| react-redux-rematch | 200.2 | 54.7 | 1.31 | 8.6 | 2.15 | 233.4 |
| react-tracked | 185.7 | 50.8 | 1.25 | 4.86 | 2.51 | 216.4 |
| react-redux-hooks-immutable | 246.1 | 64.7 | 1.37 | 6.38 | 2.44 | 290.4 |
| valtio | 145.2 | 41.3 | 1.14 | 5.97 | 2.83 | 168 |
| preact-kr-observable | 32 | 10.8 | 0.76 | 5.68 | 1.05 | 54.6 |
| vue-pinia | 69.6 | 25.3 | 0.85 | 4.26 | 1.37 | 118.5 |
| san-store | 92.5 | 23 | 1.03 | 3.55 | 1.25 | 102 |
| mobx-jsx | 56.4 | 15.6 | 0.91 | 3.89 | 1.21 | 70.4 |
| reatom-jsx | 29.6 | 10.4 | 0.72 | 5.94 | 1.08 | 91.3 |
| re-frame | 351.1 | 80.8 | 1.92 | 7.61 | 3.3 | 381.8 |
| preact-signals | 23.1 | 8.2 | 0.7 | 5.05 | 2.0 | 58.5 |
| solid-store | 14.7 | 5.5 | 0.53 | 2.91 | 0.86 | 38.6 |


---

## Cohort B — the compiled-language cohort (Koru's peer group)

Implementations authored in a language that is **not JavaScript or TypeScript**,
compiled to run in a browser. Everyone here pays a compiler and ships a runtime,
which is exactly Koru's deal — this is the like-for-like group. 23
entries: Rust x14, C# x2, ClojureScript x3, plus Elm, Scala, Swift, and Imba.

Two of them the repo's own metadata mislabels as JavaScript — `anansi` (the app
is Rust: `js-framework-comps/src/app.rs`) and `helix` (ClojureScript:
`shadow-cljs.edn`, `src/demo/main.cljs`). We classified by source, so they are
here. One borderline call: `imba` is its own language compiling to JS, but it is
JS-adjacent — included, flagged. `marko` was considered and **not** included
(HTML-template DSL over JS; recorded, not forced).

### The download-size picture — the axis where this cohort splits

Sorted by compressed (brotli) transfer size. "ships" is what the entry actually
sends to the browser, verified by the artifacts in each entry's dist directory:


| implementation | ships | size unc. KB | size br. KB | ready mem MB | run mem MB | run+clear MB | first paint ms |
|---|---|---|---|---|---|---|---|
| elm | js | 31.7 | 10.4 | 0.69 | 3.63 | 0.97 | 59.9 |
| wasm-bindgen | wasm | 47 | 14.5 | 1.73 | 2.87 | 1.81 | 70.7 |
| imba | js | 64.1 | 15.1 | 0.88 | 3.59 | 1.1 | 79.4 |
| spair-qr | wasm | 90.7 | 27.8 | 1.76 | 4.47 | 3.1 | 117.6 |
| spair | wasm | 101.4 | 31.8 | 1.77 | 4.95 | 3.61 | 137 |
| stdweb | wasm | 130.8 | 34.2 | 1.75 | 3.17 | 2.36 | 52.7 |
| dominator | wasm | 135.4 | 40.1 | 1.76 | 3.85 | 2.66 | 171.5 |
| silkenweb | wasm | 173.9 | 44.3 | 1.76 | 3.72 | 2.63 | 212.7 |
| sycamore | wasm | 157.5 | 47.2 | 1.78 | 2.08 | 3.56 | 208.5 |
| leptos | wasm | 189.6 | 48.8 | 1.77 | 5.37 | 4.51 | 230.4 |
| yew | wasm | 202.3 | 56.8 | 1.83 | 5.83 | 4.61 | 255.3 |
| yew-hooks | wasm | 206.4 | 57.9 | 1.77 | 2.18 | 4.7 | 263 |
| helix | js | 257.9 | 58.9 | 1.35 | 4.69 | 2.19 | 269.4 |
| reagent | js | 274.8 | 64.4 | 1.51 | 6.24 | 2.97 | 299.9 |
| mogwai | wasm | 232.2 | 66.3 | 2.86 | 9.62 | 10.24 | 294.2 |
| anansi | wasm | 257.1 | 73.5 | 0.57 | 6.31 | 4.8 | 36.4 |
| laminar | js | 720.4 | 80.1 | 3.38 | 15.09 | 4.12 | 665.8 |
| re-frame | js | 351.1 | 80.8 | 1.92 | 7.61 | 3.3 | 381.8 |
| sauron | wasm | 277.6 | 81 | 1.8 | 8.42 | 22.85 | 402.8 |
| dioxus | wasm | 419.6 | 114.9 | 1.91 | 6.12 | 6.74 | 528.7 |
| elementaryui | wasm | 610.7 | 172.3 | 1.04 | 4.93 | 3.35 | 809.6 |
| blazor-wasm | wasm | 4208.3 | 1377 | 41.14 | 52.65 | 49.47 | 64.5 |
| blazor-wasm-aot | wasm | 12639 | 2951.8 | 51.78 | 64.67 | 61.43 | 71.5 |

The shape: this cohort spans **three orders of magnitude**, and what dominates
is not the language but **what the toolchain makes you ship**. Elm compiles to a
small JavaScript runtime (10.4 KB compressed — the
smallest compiled-language entry on the board). The lean Rust/wasm entries start
at 14.5 KB (`wasm-bindgen`) and typical Rust
frameworks land in the 40–80 KB range. Swift ships
172.3 KB. Blazor ships a .NET runtime:
**1377 KB**, and its AOT variant
**2951.8 KB — about
284x
Elm** for the same three buttons and a table. First-paint tracks the same split
(Elm 59.9 ms; wasm frameworks mostly
117.6–809.6 ms —
with one caveat: Blazor reports an early first paint at
~64.5 ms despite its megabytes — first paint
measures when something first renders, not when the payload has arrived or the
app is usable).

**Where Koru sits in that shape — stated honestly.** As of round 2 the
gauntlet's app passes **11 of 11 operations under our closer** (a structural
DOM-assertion harness calibrated against `vanillajs-keyed` at 0% cant-tell —
`dom/board/latest.md`), and the emitted JS compresses to **4.8 KB gzip /
4.1 KB brotli** (measured locally 2026-08-07 on `dom/app/output_emitted.js`,
25.4 KB uncompressed). Koru ships **no framework runtime** — the JS backend
emits the program and nothing else. That puts it in the hand-written
neighborhood: above the `vanillajs` floor (2.5
KB brotli published), at `solid`'s size (4.5 KB),
under `mikado` (4.9 KB), a third of `svelte`
(12.2 KB) — and **2.5x smaller than Elm**
(10.4 KB), this cohort's previous small-end anchor.
Three caveats keep this honest: our conformance is certified by our own closer,
not the reference's webdriver harness; our size is a local brotli of the
emitted files, not the reference's size benchmark run over its own server
(`benchmarksSize.ts:20-24`); and koru has **no published operation timings** —
Phase 2 has not opened, so koru takes no row in any timing table on this page.
The second headline number rides along: **46.2% of the app's lines are host-JS
escapes** (60/130) — the gauntlet's real deliverable is driving that down, not
the size.

### Cohort B operation timings

Same order as above:


| implementation | language | create 1k | replace 1k | partial update | select row | swap rows | remove row | create 10k | append 1k | clear 1k |
|---|---|---|---|---|---|---|---|---|---|---|
| elm | Elm | 29 | 30.3 | 12.6 | 4.7 | 13.8 | 11.1 | 264.2 | 30.9 | 10.6 |
| wasm-bindgen | Rust | 22 | 23.6 | 10.1 | 2.5 | 10.9 | 9.2 | 230.7 | 24.7 | 8.9 |
| imba | Imba | 27.5 | 32.1 | 10.4 | 3.4 | 13 | 9.8 | 255.1 | 55.3 | 10.3 |
| spair-qr | Rust | 24.5 | 27 | 10.4 | 2.4 | 11 | 9.2 | 257.6 | 27.6 | 9.7 |
| spair | Rust | 24.4 | 27.9 | 11.3 | 3.4 | 12 | 9.8 | 257.9 | 28.4 | 9.2 |
| stdweb | Rust | 26.3 | 28.8 | 10.2 | 2.7 | 11.3 | 9.6 | 256.2 | 27.3 | 11.4 |
| dominator | Rust | 25.5 | 28.9 | 11.2 | 3 | 11.3 | 9.4 | 275.2 | 29.3 | 12.1 |
| silkenweb | Rust | 22.5 | 24.9 | 10.3 | 2.8 | 11.4 | 9.4 | 243.1 | 26.9 | 9.8 |
| sycamore | Rust | 24.3 | 28.9 | 11.6 | 5.3 | 12 | 9.7 | 259.4 | 28.4 | 10.7 |
| leptos | Rust | 24.2 | 28.3 | 10.7 | 3.1 | 11.6 | 9.7 | 259.4 | 28.2 | 14.3 |
| yew | Rust | 30.8 | 34.9 | 13.3 | 4.3 | 13.5 | 10.2 | 314 | 35 | 15.5 |
| yew-hooks | Rust | 31.1 | 35.2 | 18.9 | 11.9 | 20 | 13 | 319.4 | 36.3 | 16.5 |
| helix | ClojureScript | 26.5 | 29.3 | 16.7 | 6.7 | 87.6 | 11.2 | 375.3 | 30.4 | 11.3 |
| reagent | ClojureScript | 37.6 | 43.5 | 21.4 | 8.1 | 100.2 | 20.9 | 497.8 | 39.2 | 24.4 |
| mogwai | Rust | 23.4 | 26.1 | 10.6 | 3.1 | 12.3 | 9.9 | 346.6 | 36.8 | 12.5 |
| anansi | Rust | 29.8 | 35.3 | 16.9 | 8.5 | 16.3 | 59.2 | 317.4 | 33.8 | 11.2 |
| laminar | Scala | 51.9 | 63 | 14.8 | 9.3 | 85.1 | 11.6 | 421.5 | 52.6 | 33.4 |
| re-frame | ClojureScript | 50.8 | 58.2 | 36.9 | 17.2 | 105.6 | 24.3 | 490.3 | 55.9 | 49.9 |
| sauron | Rust | 42.9 | 56.8 | 32.5 | 23.5 | 58.9 | 19.8 | 458.5 | 54.8 | 15.8 |
| dioxus | Rust | 23.8 | 27.1 | 11.6 | 2.7 | 14.3 | 10.4 | 252 | 27.6 | 15.7 |
| elementaryui | Swift | 30.8 | 36.5 | 17.9 | 8.7 | 17.7 | 12.2 | 334 | 35.7 | 15.2 |
| blazor-wasm | C# | 67.7 | 78.5 | 94.9 | 83.3 | 90.6 | 33 | 679.2 | 104.8 | 30.2 |
| blazor-wasm-aot | C# | 58.5 | 64.2 | 95.1 | 83.9 | 95 | 91.7 | 627.1 | 98.1 | 19.5 |

For scale, `vanillajs` (hand-written JS): create 1k 20.2, replace 1k 21.9, partial update 9.6, select row 2.5, swap rows 11.3, remove row 9.5, create 10k 212.1, append 1k 22.9, clear 1k 8.4.
The best compiled entries (`wasm-bindgen`, `silkenweb`, `leptos`, `sycamore`,
`stdweb`) sit within ~10–30% of it on most operations — compiled-to-wasm is not
intrinsically slow at this task; the costs concentrate in download size and
first paint.

---

## Cohort C — architecture exemplars, one per update strategy

One representative per distinct way of getting a data change onto the screen.
(React is the mandated virtual-DOM representative.)

| exemplar | strategy | why this one |
|---|---|---|
| vanillajs | THE FLOOR | the floor and this gauntlet's control — a hand-built `<tr>` template cloned per row (`src/Main.js:7-8,349`), zero dependencies; every framework's overhead is measured as distance from this |
| react-hooks | VIRTUAL-DOM DIFF | the canonical virtual-DOM implementation: re-render then diff, `memo` bailouts (`src/main.jsx:74,95`); mandated as the entry every reader knows |
| svelte | COMPILER-FIRST | the compiler-first family: components are compiled ahead of time; Svelte 5 runes (`src/Main.svelte:3-4`) emit fine-grained updates from compiled output — nearest published relative of Koru's compile-the-reactivity thesis |
| solid | FINE-GRAINED RUNTIME SIGNALS | fine-grained runtime signals, the family's origin and its most optimized member (`createSignal`/`createSelector`, `src/main.jsx:1`); no vdom, per-node subscriptions |
| lit | TAGGED-TEMPLATE CACHING | tagged-template caching: html`` templates parsed once, only dynamic holes re-evaluated, keyed `repeat()` (`src/main.ts:17,50`) — a distinct strategy that is neither vdom nor signals |
| blockdom | BLOCK-VDOM | block-granular vdom: diffs cloned template blocks, not individual vnodes (`app.js:77,136,167`) — the middle point between vdom and templates, base of Odoo's Owl |
| mikado | DOM NODE RECYCLING | DOM node recycling/pooling over precompiled templates (`src/main.js:1,9`) — a fourth distinct strategy, and among the fastest non-hand-written entries on the board |

### Cohort C numbers


| implementation | create 1k | replace 1k | partial update | select row | swap rows | remove row | create 10k | append 1k | clear 1k |
|---|---|---|---|---|---|---|---|---|---|
| vanillajs | 20.2 | 21.9 | 9.6 | 2.5 | 11.3 | 9.5 | 212.1 | 22.9 | 8.4 |
| mikado | 20.2 | 22.1 | 9.6 | 2.4 | 11.9 | 9.2 | 218.6 | 22.8 | 8.4 |
| blockdom | 20.5 | 22.9 | 10.1 | 3.1 | 11.6 | 9.4 | 227.8 | 23.1 | 8.2 |
| solid | 20.8 | 23.2 | 10.2 | 3.1 | 12.6 | 9.7 | 225.5 | 23.4 | 10.7 |
| svelte | 21 | 24.1 | 10.3 | 4.7 | 12.5 | 9.8 | 229.8 | 23.7 | 9.8 |
| lit | 23.1 | 25.6 | 11.6 | 5 | 16.3 | 10.7 | 244 | 27.3 | 11.7 |
| react-hooks | 23.6 | 29.1 | 13.6 | 4.8 | 84.9 | 10.9 | 424.3 | 28.1 | 16.3 |

| implementation | size unc. KB | size br. KB | ready mem MB | run mem MB | run+clear MB | first paint ms |
|---|---|---|---|---|---|---|
| vanillajs | 11.3 | 2.5 | 0.56 | 1.86 | 0.63 | 68.9 |
| mikado | 12.3 | 4.9 | 0.61 | 1.94 | 0.75 | 42.3 |
| blockdom | 17 | 5.3 | 0.66 | 2.41 | 0.78 | 53.2 |
| solid | 11.5 | 4.5 | 0.51 | 2.65 | 0.75 | 38.4 |
| svelte | 34.3 | 12.2 | 0.6 | 2.82 | 0.94 | 60.3 |
| lit | 22.1 | 7.3 | 0.69 | 2.73 | 0.85 | 58.2 |
| react-hooks | 190.3 | 51.4 | 1.2 | 4.36 | 1.91 | 222.6 |


---

## The React family — complete, as mandated

Every React variant the reference ships, enumerated from the repo — none pruned.
19 entries: 5 without a store (plain hooks, classes, the React-compiler
build, useTransition, and React-inside-Astro) plus the 14 store pairings from
cohort A. Three more entries render through React under another language's
surface and are filed in cohort B: `reagent`, `re-frame`, `helix`
(ClojureScript). Two React store pairings exist in the repo but are quarantined
under `broken-frameworks/` with no published numbers: `react-jotai`,
`react-native-onyx` — recorded as absent, not estimated.

Sorted by partial update:


| implementation | variant | create 1k | replace 1k | partial update | select row | swap rows | remove row | create 10k | append 1k | clear 1k |
|---|---|---|---|---|---|---|---|---|---|---|
| react-classes | React, class components, no store | 24.5 | 29.7 | 12.8 | 5.8 | 84.5 | 10.7 | 427.5 | 29.3 | 16.1 |
| react-mlyn | React + mlyn subscribable state | 26.4 | 30.6 | 13.4 | 5.2 | 87 | 10.8 | 415.9 | 31.5 | 10.7 |
| react-hooks | React, hooks, no store (baseline) | 23.6 | 29.1 | 13.6 | 4.8 | 84.9 | 10.9 | 424.3 | 28.1 | 16.3 |
| astro-react | React island inside Astro | 23.9 | 29.7 | 13.8 | 5.4 | 85.8 | 11 | 427.8 | 28.7 | 17.1 |
| react-tagged-state | React + react-tagged-state signals | 23.9 | 29.4 | 13.8 | 4.6 | 84.8 | 10.4 | 419.3 | 29.2 | 16.5 |
| react-compiler-hooks | React with the React Compiler's automatic memoization | 23.9 | 29.6 | 13.9 | 7.2 | 85.7 | 11.4 | 432 | 28.4 | 16.5 |
| react-rxjs | React + RxJS streams as state | 25.6 | 29.2 | 14.2 | 5.1 | 84.8 | 10.4 | 361.4 | 29.6 | 17.7 |
| react-supergrain | React + Supergrain store | 25.8 | 32 | 14.4 | 5.8 | 12.6 | 12.1 | 422.2 | 31.4 | 18 |
| react-zustand | React + Zustand | 24.8 | 30.5 | 14.6 | 4.8 | 85 | 11 | 439.3 | 29.4 | 19.7 |
| react-mobX | React + MobX observables | 26.8 | 32.9 | 14.8 | 5.5 | 87.9 | 10.9 | 453.9 | 31.6 | 17.1 |
| react-kr-observable | React + kr-observable observables | 26 | 30.3 | 14.8 | 4.7 | 85.2 | 10.9 | 469.4 | 30.6 | 17 |
| legend-state | React + Legend-State observables | 29.3 | 33.9 | 15.7 | 4.9 | 87.7 | 12 | 447.3 | 32.2 | 13.1 |
| react-redux-hooks | React + Redux, hooks API | 26.8 | 30.3 | 16.8 | 6.2 | 86.8 | 11.4 | 436.6 | 31.4 | 19.1 |
| react-hooks-use-transition | React hooks wrapping updates in useTransition | 28.9 | 30.7 | 16.9 | 9.1 | 87.1 | 13.1 | 439.2 | 32.8 | 14.7 |
| react-redux | React + Redux, connect() API | 28.9 | 34.4 | 16.9 | 9.1 | 87.7 | 22.8 | 416.6 | 33.7 | 21 |
| react-redux-rematch | React + Redux via the Rematch framework | 28.7 | 34.8 | 17.6 | 8.9 | 87.6 | 22.9 | 418.8 | 33.7 | 20.8 |
| react-tracked | React + react-tracked proxy-based tracking | 25 | 31.6 | 19.4 | 9.5 | 88.4 | 12.4 | 444.1 | 31.5 | 17.4 |
| react-redux-hooks-immutable | React + Redux + Immutable.js state | 26.9 | 31.7 | 20.8 | 6.7 | 92.6 | 13.2 | 450.3 | 32.1 | 18.1 |
| valtio | React + Valtio proxy store | 28.8 | 32.7 | 22.6 | 9 | 91.7 | 15.6 | 496.2 | 35.6 | 14.2 |


---

## Does anybody publish build time? No.

We intend to publish Koru's compile time, on the argument that a compiler
claiming to pay at compile time should show the bill. So we checked whether the
reference measures build time at all:

- **The harness has no build-time benchmark.** The complete benchmark list is
  the enum at `webdriver-ts/src/benchmarksCommon.ts:72-90`: nine CPU
  operations, memory, startup, and sizes. Nothing times a build.
- **The build tooling doesn't time builds either.** `cli/rebuild-build-single.js`
  and `cli/rebuild-all-frameworks.js` run each framework's production build with
  no timing around it.
- **No entry self-reports one.** A repo-wide search for build/compile-time
  reporting finds only vendored bundler comments inside shipped artifacts.

So: **nobody in a 181-implementation benchmark publishes what their compiler
costs.** If Koru publishes its compile time next to its runtime numbers, that
column is one nobody else has.

---

## What is absent, and what was left out — stated, not smoothed


- Haskell: miso exists in the repo only under broken-frameworks/keyed/ (miso-ghc-js, miso-ghc-wasm) — no rows in the current dataset.
- ReScript: rescript-react is under broken-frameworks/keyed/ — no rows in the current dataset.
- PureScript: no keyed entry exists at this commit at all.
- Store pairings with no current numbers: react-jotai and react-native-onyx are under broken-frameworks/keyed/ — no rows in the current dataset.
- san (plain, template API) is under broken-frameworks/keyed/ — san-composition is the nearest live baseline for san-store.
- The non-keyed division (67 implementations) is out of scope for this gauntlet (the reference control is vanillajs-keyed) and was not classified.
- marko / marko-classes were considered for cohort B and not included: .marko is an HTML-template DSL over JS and the repo classifies both as JavaScript — borderline, recorded rather than forced.
- magnet, alien-signals, vanillajs-signals, wcstack-signals(-tsx) use signal libraries as their internal reactivity engine, not as an app-level store over a separate renderer — considered for cohort A and not included.
- Build time: no entry publishes one and the harness does not measure one (see the build-time section).

Within the pulled dataset there were **no gaps to record**: all 58
selected entries have published samples for all 15 benchmarks at this commit.
Every timing cell in this page is a median of the reference's published sample
array; no cell is estimated, and an entry with no published number would be
marked absent rather than filled.
