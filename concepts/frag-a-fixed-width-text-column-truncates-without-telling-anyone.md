---
type: belief
id: frag-a-fixed-width-text-column-truncates-without-telling-anyone
provenance: DOM gauntlet, 2026-08-08 — a char[40] label silently dropped the last mark from ~1.2% of rows on every run; found by the reference harness, not by anything of ours
ts: 2026-08-08
---

# A fixed-width text column truncates without telling anyone (belief)

A store column declared `char[N]` is a fixed-width text cell, and a write longer
than `N` is cut to fit. Not refused, not reported, not logged — cut, and the
program continues with a value it was never asked to store.

The benchmark app carried `label: char[40]`. The reference's word lists top out
at 27 characters, and the partial-update operation appends `" !!!"` four times
for 16 more, so the real maximum is 43. Every label of 25 characters or more
therefore lost its last mark, on every run, on roughly twelve rows in a
thousand. The page rendered text nobody wrote.

**Nothing in our stack noticed for four sessions.** Not the store, which did the
cutting. Not the emitter. Not the app's own conformance gate, which read 11/11
on the exact build the reference aborted on (see
[[frag-a-gate-cheaper-than-the-benchmark-it-mirrors-is-green-by-construction]]).
The thing that found it was a harness written by someone outside this project,
asserting a specific string rather than a shape.

**The belief is about the shape of the failure, not the width.** Widening the
column fixes this program. What does not change is that the next author sizing a
text column is making an arithmetic prediction about their own data — longest
input, plus every suffix any code path may append, across the whole life of a
row — and a wrong prediction is paid in silent wrong output rather than in a
refusal. That is exactly the failure class this language is built to convert
into a compile error, and here it is, in the standard library, converting the
other way.

**Why it is not simply a bug to fix in the store.** The cheap page-allocated
text form is a fixed-width cell on purpose: it is what makes a column
allocation-free and a sweep cache-friendly, and the DOM work depends on that.
The question is not whether to have fixed-width cells; it is what a write that
does not fit should DO. A refusal at the write site would be loud and correct
and would also make every write a branch. A compile-time bound — the column's
width against the maximum length any writer can produce — would be free at
runtime and is the shape this language usually reaches for, but nothing today
tracks the length of a built string.

**Open, and it is a language question rather than a store bug:** should a write
that does not fit a `char[N]` be a refusal, a branch, or a compile-time
obligation on the writer? Recording the question here rather than answering it —
the arithmetic now sits beside the declaration in `dom/app/main.k` so the next
person sizing one does not guess, which is a workaround and reads like one.

Relates to [[frag-a-numeric-guarantee-does-not-port-between-hosts]]: both are
cases where a bound that a human has to predict correctly is enforced by
truncation or wraparound instead of by refusal, and both were found only because
something outside the system disagreed with the result.
