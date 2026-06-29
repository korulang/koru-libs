# Phase 3 — Arbitrate, then commission

You and the human have walked back from the scouts with a fistful of findings.
This is the phase where the two of you stand still on the path, read what came
back together, and only then send one minion off to build. It is the narrowest
gate in the whole method, and the easiest to narrate past — so this file slows
it down and names every place the slide happens.

The shape of the phase is two beats, in this order, never collapsed:

1. **Arbitrate** — present the findings and *stop*. The two arbiters read them
   together, on the walk, and land a shared decision about what to build.
2. **Commission** — distill that decision into one lossy charge and hand it down
   the wall to a contestant.

The work below is mostly about protecting the boundary between those two beats,
because the cost of collapsing them lands on the product, not on you.

## The HARD STOP — this is a two-arbiter checkpoint, not a formality

**NON-NEGOTIABLE.** Scouting produces findings; the *arbitration of those
findings is a conversation between both arbiters — you AND the human — and it
must happen before a single contestant is commissioned.** Present the scout
findings, then **stop and wait for the human's read.** Do NOT present-and-commission
in the same turn. Do NOT treat an earlier "I trust your instinct / run it" as
authorization to skip this: pre-authorization for *initiative* is not permission
to delete the human's seat at the arbitration. Firing contestants off the back of
your own synthesis alone is the cardinal on-ramp-to-contest drift — it spends a
fleet probing whatever *you* concluded, with the one person who can catch a
wrong-target commission left out of the loop.

The slide to watch for in yourself: you finish presenting the findings, the
synthesis feels clean, the next move feels obvious, and your hand reaches for
the contestant prompt in the same breath. That breath is the violation. The stop
is not a beat of politeness — it is the structural place where the human's
altitude enters the loop. Present, then go quiet. Let the read come back.

## Why the seat is load-bearing — and why no subagent can fill it

The human is not in the loop here for ceremony. The seat catches two whole
classes of failure that are **structurally invisible from inside the sprint** —
invisible to you mid-synthesis, and invisible by construction to any subagent
(a sealed shell has no altitude to see them; see the sealing section below).

- **Wrong-target / known-hole probing.** A commission can be perfectly
  well-grounded — real `file:line` evidence, a real seam — and still aim the
  fleet at something *already known*. "Find the holes in a layer we already
  mapped as full of holes" re-confirms the known instead of surfacing the
  unknown. Only the human, holding the north star and the history of where
  you've already been, reliably spots "we already know this — point them at the
  unknown instead." From inside the sprint a known hole and a fresh one look
  identical; both have good evidence. The difference lives in memory the
  subagent was never handed and you, mid-synthesis, are not holding.

- **Obsolescence + north star** — the two filters the human owns:
  - *Is this already done, or superseded by a pivot?* A scout grounds in the
    repo as it *is*, and the repo's center of gravity is whatever was built
    last. It will surface plausible seams that pull straight toward the
    most-recently-built thing. Only the human knows what's been *pivoted away
    from* — a seam can be immaculately evidenced and still point at a direction
    the project abandoned two sessions ago.
  - *Does this serve the north star, or is it just momentum?* The same gravity
    that surfaces obsolete seams surfaces on-target-looking ones that quietly
    serve the proxy, not the scene. Aiming the slope at the scene rather than
    the pass-count (tenet 6) is a judgment that lives with the walkers.

A top-ranked finding that fails either filter does **not** get commissioned, no
matter how well-evidenced it is. The evidence answers "is this real?"; it cannot
answer "is this what we should build?" — that second question is the whole
reason the seat exists.

Only after the conversation has *landed a shared decision* do you distill the
commission.

## The commission — one lossy charge

Now compress. The decision the two of you just reached, plus everything the
scouts surfaced to support it, gets distilled into **one self-contained charge**.

It carries exactly these, and nothing else:

- **Target** *(grounded)* — the specific thing to build, with the `file:line`
  evidence that anchors it.
- **Value** — why this slice is worth a contestant's run.
- **Non-negotiables** — the invariants the slice must hold (see the sealed shell
  below — the asymmetric truth hierarchy is baked in here, not appended later).
- **Forcing-function framing** — the shape of the work, framed so the contestant
  is pushed toward the real thing rather than a vacuous green.
- **Orientation pointer** — where to read the standards and ground itself; a
  pointer is enough, not the contents. **On any governed target — and always on
  a world-model commission — this pointer names the `wm` readers so the
  contestant first *sees what already exists*: `wm tree <path>` for the
  per-instrument landscape (green / red / **dark** = authored-but-never-run),
  `wm top` for the one-line repo state, `wm help` for the manual. That glance is
  how it avoids re-floating a concept already shipped and aims at the residue
  instead — the same move a synth contestant makes by listing prior submissions
  before building. Pure readers: no run, no lock, safe inside a sealed shell.**

**Lossy on purpose.** The charge does NOT carry the deliberation, the rejected
findings, the other scouts' reports, or anything about *how* you and the human
arrived here. A contestant blind to all that brings fresh judgment instead of
inheriting your biases — which is exactly what keeps variance alive across the
fleet. The lossiness is the feature, not a shortcut.

## The sealed shell — the commission *is* the sealing

This is the same act named from both ends. Distilling the lossy charge and
sealing the subagent's shell are not two steps — **the lossiness IS the
sealing.** When you strip the deliberation out of the brief, you are not just
keeping the contestant fresh; you are drawing the wall that keeps the
methodology with the walkers.

Operationally, here is what crosses the wall and what does not:

- **Crosses:** the bounded task + the scene-substance it judges against + the
  non-negotiables. The contestant gets the *content* — the substance of the bed
  it builds in.
- **Does NOT cross:** the wander, the roles, the promotion lifecycle, the
  gardener stance, the right to make a methodology-level call. The contestant
  gets the content, never the **process**. Withholding the methodology is what
  makes ADD **non-recursive by construction** — the garden stays with the
  walkers; a sealed shell cannot spawn its own walk.

- **The ideal user is how taste crosses the wall.** You do not hand a contestant
  `SCENE.md`. You hand it *"build this to satisfy THIS person."* The ideal user
  is the protocol that carries the feeling of the scene across a boundary the
  scene itself is not allowed to cross. That is how a sealed shell builds
  something that fits the garden without ever being shown the garden.

- **Bake the asymmetric truth hierarchy into the brief — as a non-negotiable,
  not a footnote.** The single most important thing the commission carries past
  the wall is *what the contestant must NOT decide on its own*. Concretely:
  **"a failing test is a design question — return it to me, do not resolve it
  yourself."** A contestant briefed without this will, by default, conform a red
  test to the compiler and call it done — because editing a test to match the
  compiler breaks no rule it can see. The brief is the only place this constraint
  can be installed; install it. (A *passing* test is strong evidence a shape is
  intended-legal — fair to lean on; a *failing* one indicts neither side and
  comes home unbuilt.)

## A sealed shell cannot catch a bad commission

This is the load-bearing consequence, and it is why the hard stop above is not
optional. If the brief is wrong, the contestant executes it **faithfully** — it
has no altitude to notice "this fights the scene," because you deliberately
withheld the altitude. A misframed task does not bounce back with a warning; it
comes back built, green, and pointed at the wrong thing.

So the check on a bad commission is **never the subagent — it is the two
arbiters, back on the walk, judging what came back.** Do not brief a contestant
expecting it to push back on a wrong target; that pushback lives with the
walkers by design. The seal that keeps it fresh is the same seal that blinds it
to your mistake. Which means the only place a bad commission can be caught is the
place you just stood — the arbitration. Skip the stop, and there is no second net.

When the charge is distilled and the wall is drawn, hand it to a contestant and
move to **Contest** (§4).
