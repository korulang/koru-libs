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

## Round 9: the searching is gone, and nothing we could name replaced it

Retention landed and the gaps closed roughly as the probes predicted. What
remained was building rows — ten thousand at ~1.10× and a thousand more at
~1.06× — with no page search anywhere in the path. Two candidates were put to
it and **both failed**, one of them three times over before it stayed dead.

Caching the container element the component looks up per row was the seventh
candidate in three sessions to measure zero. Batching a task's rows into a
detached fragment — the trick the reference uses by hand, detaching its table
body to fill it (`vanillajs Main.js:338-346`) — is the eighth, and the first to
come in *worse*: 1.112× against 1.101× on the big build, 1.090× against 1.061×
on the small one. It has been reverted.

**The durable belief from this round is about the instrument, not the DOM, and
it cost three wrong write-ups to arrive at.** The first said batching won 5%.
The retraction of that said it won ~1.5 ms on one operation. Both were the same
error at different magnitudes, and the error is this: *on a machine that is not
quiet, a timing sample is not a noisy measurement of one value — it is a clean
measurement of one of two values.* Runs fall into a fast cluster and a contended
one with nothing in between, because a run either holds a fast core for its
whole duration or it does not. A median over such a set reports how many fast
samples a framework caught, and it does not look noisy when it does so. It looks
like a result.

Three things follow, all mechanical, all now built:

- **The control gates the window.** The reference is the one program guaranteed
  not to have changed between runs. In the window that produced the 5% claim it
  had drifted 2.4× from its own known value, in the same file, unread.
  `dom/board/read-timings.mjs` refuses to rank a window whose control has moved.
- **Read the fast cluster, never the median.** Interference only ever adds time.
- **Quiet the machine with the supervisor's own switch.** The heavy services
  here are launchd agents declared `KeepAlive true`; killing them by pid is
  answered in milliseconds. `dom/board/quiet-machine.sh` boots them out
  reversibly. With them down the bimodality vanishes completely — 25 of 25
  samples in one cluster for every framework — which is what made the verdict
  legible at last.

A quiet machine is also simply faster (the reference moved 311.4 → 290.5 ms), so
a baseline is a property of the machine's state and not of the reference. Any
number carried across sessions has to say which state it was taken in.

The remaining gap is therefore still unexplained, and one named candidate is
unmeasured: every row we paint carries five attributes the reference's rows do
not (`data-id` three times, `data-action` twice), because our click delegation
reads a row's identity out of the DOM while the reference stashes it as a
JavaScript property on the element (`tr.data_id = data.id`). That is the open
question at the bottom of this file — what identifies the row a component
painted — arriving from a second direction.
