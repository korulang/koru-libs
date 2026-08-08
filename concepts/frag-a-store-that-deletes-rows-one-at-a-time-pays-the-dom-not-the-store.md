---
type: belief
id: frag-a-store-that-deletes-rows-one-at-a-time-pays-the-dom-not-the-store
provenance: first timed DOM-gauntlet run, dom/board/timings-2026-08-08 — clear1k at 6.98x of vanillajs while six of nine operations sit at 0.95–1.12x
ts: 2026-08-08
---

# A store that deletes rows one at a time pays in the DOM, not in the store (belief)

The first attended timing run of the DOM gauntlet split cleanly: the compiled
store is at hand-written parity on every operation that touches few rows or
appends (select 0.95×, swap 1.02×, remove-one 1.04×, create-10k 1.12×), and it
is at parity precisely where runtime state libraries pay their price (the React
family runs select at 1.9–3.6× and swap at ~7.5×). The one outlier is mass
removal: clear-1k at 6.98×.

The cost is not the store's compaction — swap-with-last over flat columns is
cheap. It is that emptying the store is expressed as per-row `take`, and each
removal fires the removed-watch, whose body is `remove_row_event` →
`domRow(id)` → `document.querySelector` over the live table, then one
`removeChild`. A thousand-row clear is a thousand shrinking DOM scans plus a
thousand individual detachments; the hand-written control drops the tbody in
one assignment.

So the belief: **when every row dies in one sweep, the per-row watch protocol
is the wrong unit of work — the observer needs a bulk form.** This is the same
shape as the announce finding ([[frag-a-cost-the-optimizer-deletes-was-never-there]]):
the per-row protocol was designed for the general case, and the aggregate case
(everything at once) is a compile-time-visible pattern the emitter could lower
differently. The partial-update gap (1.77×) is the milder sibling — per-row
handler dispatch over 1,000 rows where only 100 match — already isolated by the
ECS benchmark as the dispatch component.

Open: whether the bulk form is a store-level "emptied" event the markup
surface can implement as a tbody clear, or an emitter observation that a
sweep's take-all is total. The first is a language-surface question and is
Lars's.
