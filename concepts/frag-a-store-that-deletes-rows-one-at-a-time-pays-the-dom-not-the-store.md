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

## Round 9: once the searching stopped, the remaining cost had moved to the other side

Retention landed and the gaps closed roughly as the probes predicted. What was
left was building rows: ten thousand of them at 1.12× and a thousand more at
1.10×, with no search anywhere in the path. The natural continuation of the
belief above is that some other per-row thing *we* do is expensive, and the
named suspect fit that shape perfectly — the component looked its container up
with `document.querySelector` once per row where the reference caches it once.

**It measured zero.** Seventh candidate across three sessions to do that, and
the first to be wrong in an instructive direction rather than merely dead.

The answer was in the control's own source, five lines with no comment on them:
the reference detaches its table body, fills it, and puts it back
(`vanillajs Main.js:338-346`). Ten thousand rows enter its page as one
insertion. They entered ours as ten thousand.

Batching a task's rows into a detached fragment took the ten-thousand-row build
from 1.120× to 1.067×. **And our own script time went UP while doing it** —
37.5 to 40.5 ms — while the browser's share fell 299.7 to 283.4 against a
reference 279.0. Batching closes 79% of the layout gap and none of the script
gap.

So the belief above is right about its case and too narrow as a rule. A per-row
DOM write has two prices and they are paid by different parties: *issuing* it,
which is our program's time and was the whole story while we were searching the
page, and *receiving* it, which is the browser's and becomes the whole story
once the searching stops. A markup surface is the only layer that knows a run
of rows is in flight, so it is the only layer that can pay the second price
down — the app cannot, and the store should not have to know it is talking to a
page.

The script gap that remains has a visible candidate, unmeasured: every row we
paint carries five attributes the reference's rows do not, because our click
delegation reads a row's identity out of the DOM while the reference stashes it
as a JavaScript property on the element (`tr.data_id = data.id`). That is the
open question at the bottom of this file — what identifies the row a component
painted — arriving from a second direction, and it is now the last named thing
between us and the reference.
