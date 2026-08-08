# Probes — pricing the fix before writing any of it

The method that paid five times on the JS-perf night: hand-edit
`output_emitted.js` and time it BEFORE writing compiler code. It is not a mock
— it IS the emitter's output minus the thing under test, so the context a mock
cannot reproduce is there by construction.

`mkprobes.mjs` and `mkprobe2.mjs` build the variants from the shipped
`output_emitted.js`. **Every replacement asserts its hit count** — a silently
missed edit would measure the baseline and report it as a win.

| variant | what it changes | isolates |
|---|---|---|
| `korumap` | the app retains the element it just created instead of re-finding it by scanning the DOM | the page-search cost |
| `korubatch` | keeps the sweep-driven clear, but the removal observer batches its DOM write | the per-element detach cost |
| `korubulk` | the store empties in one step and writes the DOM once | ceiling of a bulk verb (changes TWO things — also skips the sweep) |
| `koruboth` | `korumap` + `korubulk` | do they compose |

**All variants were re-verified at 11/11 on `dom/closer` — including the
keyedness check — before being timed.** A faster variant that quietly stopped
being keyed would be measuring a different program.

## What they showed

The three gaps in the shipped app have one cause, and it is not the compiler's
per-row protocol: the vehicle re-finds a row's element by scanning the live
DOM, because the component that created that element discarded the reference.
Retaining it closes 71.6 ms of clear's 77.8 ms gap and takes partial update
from 1.77 to 1.11. Per-row dispatch over 1,000 rows costs ~1.9 ms of 18.6.

A prediction was recorded before the data and **falsified**: retention alone
was expected to land clear at 2–2.7×; it landed at 1.48×.

## Round 9 — two candidates, and a lesson about the instrument (`*-r9-*.json`)

By round 8 the app was within ~7-9% of hand-written code on most operations and
the largest remaining absolute gap was building ten thousand rows: 348.9 ms
against the reference's 311.4.

**`korucache`** caches the container element the component otherwise looks up
once per row (the reference caches it once, `vanillajs Main.js:187`). Zero —
344.9 against 348.9, and slightly worse on the thousand-row build. Seventh
candidate across three sessions to measure nothing.

**`korufrag`** batches a task's rows into a detached fragment and attaches once,
which is what the reference does by hand when it detaches its table body to fill
it (`Main.js:338-346`). At n=15 it measured 332.3 — a clean-looking 5% — and
that number was wrong.

### What refuted it, and what a quiet machine finally said

At n=25 under load the create-10k distribution is **bimodal**: a fast cluster
near 340 ms and a contended one near 800, with nothing in between. The median is
then set by how many fast samples a framework happens to catch — 1 for the
reference, 4 for round 8, 9 for the batched build in the same run. Ranking those
medians ranks scheduling luck.

**The tell was in the same file and went unread.** The reference — the control,
the one program guaranteed not to have changed — measured 756.8 ms in a window
where it is known to measure 311.4. `dom/board/read-timings.mjs` now refuses to
rank a window whose control has drifted, and reads the fast cluster rather than
the median.

Then the machine was actually quieted. The heavy background services here are
launchd agents declared `KeepAlive true`, so killing them by pid is answered in
milliseconds by a new process — an hour of "I killed the noisy things and load
is unchanged" is the supervisor working, not a mystery.
`dom/board/quiet-machine.sh` boots them out and puts back exactly what it took.

**With them down the split disappears entirely — 25/25 samples in one cluster,
every framework — and the verdict reverses:**

| operation | reference | round 8 | batched | |
|---|---|---|---|---|
| build 10,000 rows | 290.5 | 319.7 (1.101×) | 323.0 (1.112×) | batching is WORSE |
| build 1,000 more | 31.2 | 33.1 (1.061×) | 34.0 (1.090×) | batching is WORSE |

So batching is not a win, and not a wash — it is a small **regression**, on both
operations, and the "~1.5 ms on the smaller build" that was salvaged from the
first retraction was contamination too. It has been reverted from `koru/dom`;
the emitted output is byte-identical to the build that measured 1.101×.

**Eighth candidate to measure nothing, and the first to measure worse.** Note
also that a quiet machine is simply faster: the reference moved 311.4 → 290.5,
so a baseline is a property of the machine's state, not of the reference.

The gap remains unexplained, with one named unmeasured candidate: every row we
paint carries five attributes the reference's rows do not (`data-id` ×3,
`data-action` ×2), because our click delegation reads identity out of the DOM
while the reference stashes it as a JavaScript property on the element
(`tr.data_id = data.id`, `Main.js:349-356`). That is the same open question as
selection-as-repaint — whether an event can carry identity — arriving from a
second direction.

## Round 10 — the first candidate that actually won (`*-r10-quiet-*.json`, `mkprop.mjs`)

Nine candidates across four sessions had now measured nothing or worse. The
tenth is the one, and it came from the same place round 9's real finding did:
reading what the hand-written reference does instead of reasoning about our own
code.

Every row we painted carried five attributes the reference's rows do not —
`data-id` three times, written per row, and `data-action` twice, cloned in from
the template. They existed for one reason: the click delegation recovered a
row's identity by parsing it back out of the page. The reference never puts it
there. It stashes identity as a plain JavaScript property on the element
(`tr.data_id = data.id`, `Main.js:352`) and decides the action from WHICH CELL
was hit (`Main.js:168-185`).

`koruprop` does the same: no attributes on a painted row, identity as a
property, delegation by cell position, and an id→element map for the two host
escapes that still look a row up. Every replacement asserts its hit count, and
the probe refuses to write itself if a single `setAttribute("data-id"` survives
— a half-applied edit would measure the baseline and report it as a win.

Timed on a **quieted machine** (`dom/board/quiet-machine.sh`), all three
frameworks in one window, read through `dom/board/read-timings.mjs`:

| operation | reference | round 9 | without attributes | |
|---|---|---|---|---|
| 01 build 1,000 rows | 26.9 | 1.074 | **1.045** | better |
| 02 replace all | 30.0 | 1.093 | **1.043** | better |
| 03 update every 10th | 15.2 | 1.118 | 1.112 | ~same |
| 04 select a row | 4.4 | 0.773 | **0.727** | better |
| 05 swap two rows | 18.2 | 1.016 | 1.049 | WORSE |
| 06 remove one row | 14.6 | 1.021 | **0.973** | better |
| 07 build 10,000 rows | 293.7 | 1.107 | **1.078** | better |
| 08 build 1,000 more | 32.2 | 1.068 | **1.040** | better |
| 09 clear 1,000 rows | 12.0 | 1.283 | **1.200** | better |
| **geomean** | | **1.053** | **1.021** | |

Better on eight of nine. It moves coherently rather than in one place, which is
what a real change looks like and what none of the nine dead candidates did:
fewer attributes is less work when a row is born AND a smaller DOM for every
operation that touches it afterwards. Only swap regressed, and swap is the one
operation whose host escape still walks the page.

**This is a probe, not a shipped change.** The `data-id` attributes are the
APP's markup, and the identity channel that would replace them is the library's
— which makes the shippable version a change to what a click carries. That is a
spelling question and it is Lars's.

## Round 11 — the identity channel, shipped (`*-r11-shipped-*.json`)

Round 10's probe is now the library's behaviour. `koru/dom` records both
directions of the pairing it always had in hand — the map from key to element,
and the key on the element — and a click walks up to the nearest keyed ancestor
and carries that key in its payload. The app's markup carries no identity at
all; `data-id` is gone from every row.

Measured in one window against the previous build, quiet machine, read through
`read-timings.mjs`:

| operation | reference | before | shipped | |
|---|---|---|---|---|
| 01 build 1,000 rows | 27.2 | 1.074 | **1.044** | better |
| 02 replace all | 30.4 | 1.079 | **1.049** | better |
| 03 update every 10th | 14.5 | 1.055 | 1.083 | worse |
| 04 select a row | 3.3 | 0.939 | 0.970 | worse |
| 05 swap two rows | 17.3 | 1.035 | **1.023** | better |
| 06 remove one row | 14.0 | 1.050 | **1.007** | better |
| 07 build 10,000 rows | 290.3 | 1.097 | **1.077** | better |
| 08 build 1,000 more | 32.0 | 1.056 | **1.012** | better |
| 09 clear 1,000 rows | 12.1 | 1.223 | **1.182** | better |
| **geomean** | | **1.065** | **1.048** | |

**The structural win is bigger than the number.** Removing a row used to stage
the clicked id and sweep every row in the store comparing ids — an O(n) scan to
find the row the user had just pointed at — then sweep again to close the
position gap. The click carries the handle now, so the removal addresses the
row directly and the first pass is deleted outright: the op sweep went from
three cases to two, and remove went 1.050 to 1.007.

**Honest about the gap to the probe.** Round 10's hand-edit measured 1.021; the
shipped form lands at 1.048, and the baseline itself read 1.053 there against
1.065 here — so roughly a third of the apparent difference is window-to-window
drift of the *same* build, and the rest is that the probe also stripped the two
`data-action` attributes and decided the action from cell position. That was
right for pricing and wrong to ship: which action an element performs is the
app's declaration, and cell position is a fact about this one table, not
something a markup library can assume.

Two operations regressed slightly. Selection now resolves through the library's
registry rather than a page query and is a shade slower at 0.970 (still ahead
of hand-written); partial update at 1.083 does not touch the click path at all
and is inside this benchmark's run-to-run spread.
