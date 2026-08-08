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
