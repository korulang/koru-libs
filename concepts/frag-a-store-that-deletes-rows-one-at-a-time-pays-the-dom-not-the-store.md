---
type: belief
id: frag-a-store-that-deletes-rows-one-at-a-time-pays-the-dom-not-the-store
provenance: DOM-gauntlet timed run + four hand-edited probes, dom/board/timings-2026-08-08 — clear 6.98x, of which 92% is the vehicle re-finding elements by scanning
ts: 2026-08-08
---

# A component that forgets the element it created makes every later write a search (belief)

The first attended timing run of the DOM gauntlet showed the compiled store at
hand-written parity on six of nine operations — including the two where runtime
state libraries bleed (select 0.95×, swap 1.02×, against 1.9–7.5× for the React
family) — with one outlier: clearing a thousand rows at 6.98×.

The obvious reading was that mass removal is the wrong unit of work for a
per-row observer protocol, and that the store needs a bulk form. **Four
hand-edited probes falsified that reading.** Of the 77.8 ms gap, **71.6 ms is
the vehicle re-finding each row's element by scanning the live DOM.** The
store's own sweep and thousand `take`s cost about 2 ms. The per-row protocol
was never the problem; a prediction that retention alone would only reach
2–2.7× was recorded before the data and came in at 1.48×.

The cause is structural and sits one layer up from the store. `koru/dom`'s
component clones a template, fills it, appends it, and lets the reference go
out of scope (`dom/index.kz:333` creates `__root`, `:356` appends it). The
store has stable identity for the row that caused it — a handle carrying slot
and generation — and the two are never associated. So the app must re-derive,
by searching the page, a correspondence the compiler held at creation time and
discarded. That search is free once (removing one row is 1.04×) and quadratic
a thousand times.

The same cause explains the other two gaps: partial update (1.77× → 1.11× with
retention) is 100 searches, and replace-all (1.66× → 1.13×) contains a full
clear.

**Two things follow.** First, the fix is library-side and needs no new
spelling: `koru/dom` already emits module-scope host state — that is how the
row templates get there (`dom/index.kz:475`) — so it can emit a registry the
same way. Second, **the registry must key on the row's handle, not its
position**: removal compacts by moving the last row into the freed slot
(`__koru_hslot_row` is rewritten), so an index-keyed registry would silently
point at the wrong element after the first removal, and every conformance
check would still pass because the *set* of rows stays correct.

A bulk-removal verb is still worth roughly 6 ms on clear (1.48× → 1.05×), so
it is real but secondary, and it costs more than a verb: the lifecycle
interceptor is per-row and is where the app maintains its own counters
(`store.kz:3102` builds the inserted payload from named columns while
`__koru_new_row` sits unused in scope; `store.kz:4663` fires removal
interceptors before the swap-remove, so a dying row is still addressable).
An aggregate removal needs an aggregate form of that hook, or the bookkeeping
stops happening silently. `drain` cannot be the word — in the store it already
means handing over a row's owned resource when that row dies.

Open, and Lars's: what identifies the row a component painted. Threading the
row's identity into the lifecycle interceptor is additive — all 12 tests using
`! inserted` / `! removed` bind columns or nothing, none binds a row — but
whether an interceptor's payload gains identity is surface, not plumbing.

Relates to [[frag-a-cost-the-optimizer-deletes-was-never-there]]: both are
cases where the expensive thing was invisible until a second host ran it.

---

## Round 9: the searching is gone, and what is left did not survive measurement

Retention landed and the gaps closed roughly as the probes predicted. What
remained was building rows — ten thousand at 1.12× and a thousand more at 1.10×
— with no page search anywhere in the path, and two candidates were put to it.

**Both measured nothing on the big one, and the second one fooled me first.**
Caching the container element the component looks up per row was the seventh
candidate in three sessions to measure zero. Batching a task's rows into a
detached fragment — the trick the reference uses by hand, detaching its table
body to fill it (`vanillajs Main.js:338-346`) — *appeared* to take the
ten-thousand-row build from 348.9 ms to 332.3 and was written up as closing 79%
of the layout gap. **A 25-iteration run refutes that.** Under load the
distribution goes cleanly bimodal — a fast cluster near 340 ms and a contended
one near 800 — and the median is then decided by how many fast samples a
framework happened to catch, not by its code. In the fast cluster the batched
and unbatched builds sit at ~343 and ~344 ms. There is no difference.

What survives is smaller and was reproduced in two independent windows, by the
hand-edited probe and the real library build agreeing to 0.1 ms: on the
*thousand-rows-after-a-thousand* build, batching is worth about 1.5 ms
(36.5/35.1 → 34.7/34.5). Real, modest, and nothing like the headline it was
first written up as.

**The methodological lesson is the durable part, and it is about the
instrument, not the DOM.** A single fifteen-iteration median is not evidence on
a loaded machine, and it fails in the most flattering possible way: it does not
look noisy, it looks like a clean 5% win. The tell was available and unread —
the *control* in the same window had drifted 2.4× from its own known value.
**A timing window is only worth reading if the control lands where the control
is known to land**, and that check costs nothing next to the hour of write-up
it would have saved.

The remaining gap is therefore still unexplained, and one named candidate is
unmeasured: every row we paint carries five attributes the reference's rows do
not (`data-id` three times, `data-action` twice), because our click delegation
reads a row's identity out of the DOM while the reference stashes it as a
JavaScript property on the element (`tr.data_id = data.id`). That is the open
question at the bottom of this file — what identifies the row a component
painted — arriving from a second direction.
