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

## Round 9 — where the last of the gap actually was (`*-r9-*.json`)

By round 8 the app was within ~7-9% of hand-written code on most operations,
and the largest remaining absolute gap was building ten thousand rows: 348.9 ms
against the reference's 311.4. Two suspects were named and both were measured
rather than argued.

**The suspect I named was wrong.** The component looked up its container with
`document.querySelector(parent)` once per row, where the reference caches that
element once (`vanillajs Main.js:187`). `korucache` does the lookup through a
selector→element map. It is the SEVENTH candidate across three sessions to
measure zero — 344.9 against 348.9, comfortably inside a ±10 ms spread, and
slightly WORSE on the thousand-row build.

**What was actually there came from reading the control's source, not from
reasoning about ours.** The reference detaches its table body, fills it, and
puts it back (`Main.js:338-346`), so ten thousand rows enter the page as one
insertion. Ours entered as ten thousand. `korufrag` batches a task's rows into
a detached fragment and attaches once:

| operation | reference | round 8 | `korufrag` | |
|---|---|---|---|---|
| build 10,000 rows | 311.4 | 348.9 (1.120×) | 332.3 (**1.067×**) | |
| build 1,000 more | 33.2 | 36.5 (1.099×) | 34.7 (**1.045×**) | |
| build 1,000 rows | 28.6 | 30.6 (1.070×) | 30.3 (1.059×) | |

**Nearly all of it is the browser's time, not ours.** On the ten-thousand-row
build our own script time went slightly UP (37.5 → 40.5 ms) while the browser's
share fell 299.7 → 283.4 against a reference 279.0 — so batching closes 79% of
the layout gap and none of the script gap. A per-row append is not expensive to
issue; it is expensive to be on the receiving end of.

The script gap that remains has a visible candidate, unmeasured as of this
round: every row we paint carries five attributes the reference's rows do not
(`data-id` three times, `data-action` twice), because our click delegation
reads identity out of the DOM while the reference stashes it as a JavaScript
property on the element (`tr.data_id = data.id`, `Main.js:349-356`). That is
the same open question as selection-as-repaint — whether an event can carry
identity — arriving from a second direction.
