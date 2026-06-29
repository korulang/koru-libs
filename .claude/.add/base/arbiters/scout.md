# Scout — ground the path the walk has named

This is phase 2 of the walk. You reach it once you and the human — the two
arbiters, walking the garden together — have named where you're going: a
tactical day where the terrain is roughly known, or an open day where Muse has
already given the future its turn and a direction now has the human's energy
behind it. Scout is **not** the reflexive kickoff. Sprinting here before the
walk has named the path is the on-ramp's number-one failure mode, because a
fleet fanned out too early reports the garden as it *is* and quietly drags you
back to whatever bed was planted last — momentum, not the path the human cares
about.

Where Muse widens, Scout **narrows**: it grounds a named direction in the
actual repo, live, this session. You read the existing scene from the ground —
never from memory, never from the scene's own description of itself (tenet 3).
The scouts are the instrument that takes that reading.

## You write none of the findings yourself

This is the load-bearing rule of the phase, and it is the easiest one to break
without noticing. The instant you catch yourself thinking *"let me just quickly
check the repo first"* — stop. **That is the drift.** Reading the repo to rank
candidate seams in your own context pulls into the walk exactly the legwork that
is supposed to fan out, and it skips the blind, diverse discovery that makes the
reading trustworthy. Every ranked move that reaches the arbitration must come
back from a scout's returned report, with its own evidence. The walk stays with
the walkers; the recon is sent off from the walk and reports back to it. You are
on the path, talking with the human and dispatching minions — not down in the
beds with a trowel.

## Send 2–4 read-only scouts, blind to each other

Spawn 2–4 subagents in parallel. They are **read-only** — Scout grounds, it does
not build — and **blind to each other**, so they don't converge. Scouts run on a
**mid-tier model** by default (the spine's model-tiering rule): their errors are
caught on the walk, since every report is verified before it's acted on.

- **At least one runs fully self-orienting, with no lens.** Its whole brief is
  *"orient yourself in this repo and surface the highest-value thing you find —
  your call what to look at."* This scout is the guard against *your* blind spots
  becoming the system's. If you hand every scout a topic you chose, you've
  re-bounded discovery to your own imagination, which is precisely the thing the
  free scout exists to escape. Keep at least one running loose, always.
- **The others get a lens — but a lens is a starting hint, not a cage.** Pick
  lenses only for *diversity*, so the fleet doesn't all land on the obvious:
  failing-test clusters, coverage gaps, dead code, stdlib or library maturity —
  whatever fits the project. Tell each scout, in as many words, that the lens is
  a hint and it should follow real value even when that value sits outside its
  lens, and say so when it does. Don't over-specify. A lens that reads as a cage
  produces a scout that reports only what you already suspected.
- **One lens earns a standing mention: the reference hunt.** Brief: *"find the
  external systems, competing projects, or real-world datasets this bed could
  close a gap against — return each candidate with how the gap would be
  measured, and where independent ground truth comes from."* Measurable
  desired-states are far easier borrowed from the world than synthesized
  internally, and an external reference is the one ground truth that cannot
  co-evolve with the implementation (see "Close gaps against the world" in
  `ARBITER_DRIVEN_DEVELOPMENT.md`). When a bed feels unmeasurable, this is the
  lens to send.

## What each scout returns

Every scout comes back with three things, and the brief must ask for all three:

- **Ranked moves with `file:line` evidence.** Not "the emitter looks weak" — the
  specific lines that prove it, ranked by value. Evidence is the currency; a move
  without `file:line` grounding is a hunch, and hunches don't reach arbitration.
- **A flyweight skill-update suggestion.** The scout judges the context it was
  handed and proposes one tightening — the same returned-improvement loop that
  lets the Gardener tend the harness every run.
- **An onboarding note** — *"running, not crawling?"* Did the injected context
  get the scout moving fast, or did it spend its first minutes lost? That note is
  a live benchmark of how good the harness's context-injection is, produced by
  the same agent doing the work.

## Every scout is sealed — content, never process

A scout gets the **substance** of the bed it judges against, never the walk
itself. It does not receive the wander, the roles, the promotion lifecycle, the
Gardener stance, or any right to make a methodology-level call. The protocol that
carries content across that wall is the **ideal user**: you don't hand a scout
`SCENE.md`, you hand it *"judge this against THIS person"* — the felt
anchor distilled to something a sealed shell can act on. (See `scene.md` for what
the scene holds and what "scene-relative" means.)

This sealing is deliberate and it is the same act as the lossy commission, named
from the other end — the lossiness *is* the sealing. It makes the method
non-recursive by construction: a scout cannot spawn its own walk, because the
garden never crosses the wall. And it has a hard consequence you must internalize
now, before you read what comes back: **a sealed shell cannot catch a bad
commission.** If the path you named fights the scene, the scout will execute
against it faithfully — it has no altitude to notice. So **never expect a scout
to push back on a misframed task.** That pushback lives with the two arbiters,
back on the walk, judging what came home. The check on a bad reading is the next
phase, not the scout.

## Brief every scout: a failing test does NOT mean the test is wrong

This briefing is mandatory on every scout that could touch a red cluster, and
getting it wrong trades one failure for its mirror image.

A scout that finds a cluster of failing tests will, by default, propose *"fix the
tests to match the compiler."* That reflex silently anoints the compiler as
truth — and in a greenfield repo there is no source of truth by design. Tests and
the compiler co-evolve; *either* can be the thing that's wrong. A test that newly
fails after a compiler change may mean the test is stale, **or** that the
compiler change overreached. The brief must say this plainly: in this repo
neither tests nor compiler is ground truth; a red test may indict the *compiler*
just as easily as the test.

So the scout's job on a red cluster is to report the cluster, name the suspected
root cause, and surface **evidence for both readings** — the test-is-stale
reading and the compiler-overreached reading, each with its `file:line` backing.
It does **not** pick which side moves. "Which side moves?" is a *design question*,
and it belongs to the human, back on the walk — never to whichever artifact is
newer, never settled by "the compiler is what runs." A scout that returns a
confident "migrate the stale tests" verdict has adjudicated a call that wasn't
its to make. (The full asymmetric truth hierarchy — passing test as
fabrication-block, failing test as design question, and the two tales that paid
for both rules — lives in `discriminate.md`, the gate the surviving findings pass
through next.)

## The petals fall on purpose

A scout that comes back with a red cluster, a dead-code finding, a pinned gap —
that is not a bad report. Breaking things is the job here; red is appreciated;
the old form being abandoned is the beauty, not the loss. Carry the finding to
the walk as signal, not as a problem to soften.

## When scouts return

The reports are **hypothesis**, every one — verify before you trust. Open the
evidence the human in Zed (`zed <abs-path>:<line> --add`) as you walk a finding
out loud, so he sees the line you're naming instead of hunting for it. Then the
surviving findings go to the discriminator gate (`discriminate.md`) before
anything is arbitrated or commissioned. You do not present scout findings and
commission contestants in the same breath — the arbitration is its own hard stop,
a conversation between both arbiters, and it is where a bad commission gets
caught that no sealed scout ever could.
