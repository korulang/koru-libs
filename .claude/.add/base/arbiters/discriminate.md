# Discriminate — does the finding's premise survive the standard?

This is **phase 2.5** of the walk: the gate between a Scout coming back with a
finding and the Arbiter handing that finding to a Contestant to build. It is the
one place in the loop where you stop and ask, before any code is written, a
question the rest of the machine cannot ask for you — *is the thing we're about
to commission even allowed?*

It earns the half-number because it isn't a phase you march to so much as a
judgment that has to land *somewhere* between Scout and commission. On the walk,
2.5 is just the name for where it lands. Scale it to the stakes: a glance for an
obviously-legal move, a real and adversarial look when a finding wants to make a
new syntactic shape *work*.

## Why this gate exists at all

The sealed shell makes Contestants powerful and blind in the same stroke: hand a
Contestant a tight commission and it will earnestly, faithfully build exactly
that — including building something the language forbids, if that's what the
commission asked for. **A sealed shell cannot catch a bad commission.** It has no
altitude to notice "this fights the scene" or "this premise is illegal"; it was
sealed precisely so it wouldn't. So the check on a bad commission is never the
subagent. It is the two arbiters, back on the walk, judging the premise *before*
it goes out. That judgment is this gate.

Scout findings are **hypothesis** — and the most dangerous hypothesis is a seam
whose *premise* is illegal, because the whole machine downstream will earnestly
make it true. The absence of this check is what once let `~decide = ~if(...)` — a
`~` inside a flow, forbidden by the handbook's first rule — get ranked,
commissioned, built, merged, and published, with a compiler taught to accept
illegal code along the way. No link in that chain was holding the rulebook. 2.5
is the link.

## The asymmetric Truth Hierarchy — the spine of this gate

Everything below rests on one asymmetry. Get the asymmetry right or you trade one
failure for its mirror image.

- **A passing test is strong evidence a shape is intended-legal.** Use it to
  block *fabrication*. Any move that makes a new syntactic shape compile must be
  verified against a passing example of the same shape. **If no passing example
  exists, that is a red flag, not a green field** — it says "pin or repro," never
  "invent the syntax and make it work." The burden of proof sits on *legality*,
  not on the doubt.

- **A failing test tells you nothing about *which side* is wrong.** This is the
  mirror trap, and it is just as dangerous. In a greenfield repo there is **no
  source of truth by design** — tests and the compiler co-evolve, and *either*
  can be the thing that's wrong. A test that newly fails after a compiler change
  may mean the test is stale, **or** that the compiler change (a tightening, a
  new rejection) overreached. You CANNOT settle it by noting the compiler commit
  is newer, that the test no longer passes, or that "the compiler is what runs."
  Conforming a failing test to the compiler's latest behavior is the **same class
  of error** as inventing syntax: forcing reality to fit an unratified premise.
  **"Which side moves?" is a *design question*** — it belongs to the human (the
  language designer), never to whichever artifact is newer. A subagent's job is
  to surface the question with evidence for both readings, **not to pick a side.**

The two tales that paid for these rules — the `~if` fabrication and the `for`-loop
conformance cluster — live in full in `ARBITER_DRIVEN_DEVELOPMENT.md`. Read them
there; they are the receipts for everything on this page.

## The two questions, and their opposite mandates

A finding arrives at the gate carrying one of two questions. They look adjacent.
Their correct handling is *opposite*, and confusing them is how the gate fails.

### Fabrication question — the seam wants to make a forbidden shape compile

The sharp question, for any move that wants to make a shape compile: **is that
shape actually legal?** Ground the answer — cite the governing rule (a
`CLAUDE.md` / `AGENTS.md`-style invariant) and a **passing test of the same
shape**. No passing example of the shape is a red flag, not a green field.

When a move would legitimize forbidden syntax, it does **not** get commissioned as
written. It gets re-cast as a *negative* test that pins the rejection. "Make the
compiler accept X" is never the commission when X is forbidden; **"make the
compiler reject X clearly" is.** That recast is the whole fix — the seam still
produces useful work, but the work now hardens the rule instead of dissolving it.

If you spawn a discriminator for this question, its job is **"find the rule this
move would break."** A verdict is the point. You hand a skeptic the finding you
are most excited about and ask it to kill the premise; the moves that survive
proceed.

### Conformance question — the seam wants to "fix" a red cluster by editing tests

The opposite of "make the compiler accept forbidden X" is "make the failing test
conform to the compiler," and it is **just as dangerous**. When a finding reads
"this cluster of tests fails since commit Y, fix the tests," do NOT commission the
test edit on that basis. First answer the *design* question — **does the language
actually want the behavior commit Y enforced?** That answer comes from the human,
not from "Y is newer" or "Y is what passes."

- If yes — the design is ratified — migrating the stale tests is legitimate, and
  it is **surgical**: per-test, never a blind `sed` across every match. Negative
  tests, parked families, and unrelated uses hide in the same grep.
- If the design call is unmade or the tightening is suspect, the move is to
  *surface it* — or to pin the breakage as failing tests. Never mass-edit red to
  green. "Test fails → edit test until green" with no ratified design answer is
  **conformance fraud**, the exact twin of the fabrication failure above.

If you spawn a discriminator for this question, brief it for the **opposite**
mandate from the fabrication case: its job is to **surface both readings with
evidence and the design question, and render NO verdict on which side moves.**
Brief it explicitly that **the compiler may be the wrong side.**

This is not optional framing. "Find the rule this breaks" structurally **cannot**
catch a conformance move — editing tests to match the compiler breaks no rule, it
just silently anoints the newer artifact as truth. A discriminator that concludes
"the tests are stale, migrate them" has adjudicated a design call that belongs to
the human. That is exactly how this gate failed once: it returned a confident
"migrate" verdict, and only the human caught it. A discriminator briefed solely to
hunt for broken rules is blind to the failure that breaks no rules.

## The mirror trap, named plainly

A red test is a **design question, not a test bug.** Hold both halves at once:

- "Make the compiler accept forbidden X" → fabrication. Catch it by demanding a
  passing example; recast it as a negative test.
- "Make the failing test conform to the compiler" → conformance. Catch it by
  demanding a ratified design answer; surface the question, don't pick a side.

Both poison the product. Both anoint one artifact as ground truth in a repo that
has none by design. The unifying lesson across both faces: **a subagent surfaces
the design question with evidence for both readings; it never picks which side of
the tests-vs-compiler tension moves.**

## Running the gate

- Make it **adversarial and independent** when the stakes warrant: spawn a fresh
  discriminator subagent, served the standards, **blind to why the seam was
  proposed** — but briefed for the *right shape of question* per the two mandates
  above. A finding the Arbiter is excited about is exactly the one to hand a
  skeptic.
- A discriminator is a sealed shell like any other scout. It judges *content* —
  the rule, the passing example, the two readings — never *process*. It does not
  get the wander, the roles, or the right to make a methodology-level call. Which
  is also why a conformance discriminator must be told, in words, not to render a
  verdict: left to its own altitude it will reach for one, and it has no standing
  to.
- Only moves that clear the gate proceed to phase 3 (arbitrate → commission).
- **Record what the gate killed and why.** That is Gardener signal — it marks
  where the rulebook needs sharpening, and a felt rule that keeps getting
  violated at this gate is a candidate for promotion to a hard wall (tenet 5).

## Why this lands here and not on the contestant

Say it once more because it is the load-bearing line: the petals fall here, on the
walk, where both arbiters can see them — never inside a sealed contestant that
would build whatever it was handed. The gate is upstream of the seal on purpose.
A bad premise caught at 2.5 costs a sentence; the same premise caught after merge
costs a poisoned compiler and a human's spider-sense. Spend the sentence.
