---
type: belief
id: frag-a-gate-cheaper-than-the-benchmark-it-mirrors-is-green-by-construction
provenance: DOM gauntlet, 2026-08-08 — the official harness aborted both Koru columns on an assertion the in-tree closer had passed 11/11 minutes earlier
ts: 2026-08-08
---

# A conformance gate cheaper than the benchmark it mirrors is green by construction (belief)

The DOM gauntlet's closer exists to answer "would the reference accept this
app" without paying for a benchmark run. It read **11/11 pass, 0 fail,
0 cant-tell** on the exact build that, forty minutes later, the reference's own
driver refused to score at all.

The whole difference is a repetition count. The closer's partial-update
operation clicks `#update` **once** and asserts a row's label *contains*
`" !!!"`. The reference clicks it **four times cumulatively** — three warmup
clicks, each asserted, then the timed one — and asserts all four marks are
there. Koru's row label lives in a fixed-width store column, `label: char[40]`.
The reference's word lists top out at a 27-character label. One mark is +4
characters and fits with room to spare; four marks are +16, and 27 + 16 = 43.
The app truncates, silently, and the closer is structurally incapable of
noticing because it never gets near the boundary.

**The gate was not wrong. It was weaker than the thing it stood in for, and a
weaker gate does not report that it is weak — it reports PASS.** That is the
generalisation worth keeping: whenever a cheap check mirrors an expensive one,
the cheap one's parameters are a claim about the expensive one's parameters,
and nobody writes that claim down. Iterations, repetitions, input sizes,
string lengths, warmup counts — every one of those is a place where "mirrors
the reference" quietly means "mirrors the reference at a setting where our
implementation happens to hold".

The tell is specific and worth recognising: a defect that is **probabilistic in
the real harness and impossible in the gate**. Here the truncation hits about
1.2% of marked rows on every single run, but the reference asserts on one
particular row, so it fails roughly one run in four — which for four sessions
looked like a green gate and a lucky benchmark, and was actually a blind gate
and an honest benchmark. A failure whose rate depends on iteration count is
almost always a gate-coverage failure rather than a flake, because a real flake
does not care how many times you ask.

The response is not "add this case to the closer" — that is a resolution, and
it fixes one operation. The mechanism is to make every place the closer chose a
number *say which number the reference uses*, so a divergence is visible at the
point where it is introduced rather than at the point where it costs a
measurement window.

Relates to [[frag-absence-and-emptiness-are-different-and-the-instrument-cannot-tell]]
— both are the instrument being unable to distinguish two states, but that one
is about a reading the instrument cannot resolve, and this one is about a
reading it never takes.
