---
name: arbiters-challenge
description: The challenge doctrine of Arbiter-Driven Development — generators you replay, catalogs that grow, families of challenges, chained pipelines. Fire whenever a challenge comes up in ANY form, not only when a generative day is named on the walk — running or replaying a standing challenge, creating a new one, tuning an existing brief, asking "should this be a challenge?", proposing meta-challenges, or reasoning about a challenge catalog or family. Also the routing target when `/arbiters` names a Generative day. If the conversation touches challenges and this skill is not loaded, that is the firing failure this skill exists to fix.
---

# Challenge — replay the generator, grow the catalog

This skill is the home of ADD's challenge doctrine. It is a **skill, not only a
phase file, on purpose**: doctrine that loads only when a phase router names it
never fires in conversations *about* challenges — creating one, tuning one,
wondering whether work should become one. (Encoded 2026-06-11, after a session
where the challenge doctrine sat unread while the two arbiters discussed exactly
what it covers — the agent grounded against a project's challenge *instance* and
never opened the method's generator doctrine, because nothing fired on the
topic.) The topic is the trigger. If challenges are being discussed, this file
belongs in context.

Within a `/arbiters` run, this is the **other basin door** — the generative day.
Where Scout grounds a named path and Muse dreams a new one, a Challenge is
something different: a **standing generator you replay from zero**, and each
replay hands back a fresh, finished artifact. The human says "let's run a
challenge" (or names which one), and you spend the session *replaying* rather
than *deriving*. The whole loop and the *why* live in
`../arbiters/ARBITER_DRIVEN_DEVELOPMENT.md`; the spine is `../arbiters/SKILL.md`.

## A challenge is a generator, NOT a backlog

Hold this first, because the obvious misreading poisons everything downstream. A
challenge looks like a task sitting in a folder, so the reflex is to treat it like
a backlog item: do it once, cross it off, the list shrinks. **That is exactly
wrong.** A backlog is *consumed* — you work it down to zero. A challenge is
*replayed* — you run it from zero, infinitely, and it is never used up. The Koru
`Never: maintain a backlog` rule is not violated by a challenge catalog, because a
backlog accumulates *pending work* while a catalog accumulates *finished
artifacts* from a generator that stays.

The worked example is the **synth challenge** (`~/src/intranquil/docs/SYNTH_CHALLENGE.md`):
one sealed brief, replayed dozens of times, and the synth catalog — `filament`,
`hearth`, `tether`, `vellum`, `gyre`, `mica` — exists *only* because that one
brief can be re-run and each run yields a new instrument. Its closing line is the
whole doctrine: **"The catalog is the long-running artifact; individual challenges
are one slice through it."**

## Challenges are repo artifacts — and a goal of the method

The briefs and their catalogs are **version-controlled artifacts of the repo
they serve** — artifact #5 on the method's artifact list, alongside `SCENE.md`
and the hub. In-tree, committed, diffable, with a named home (a challenges
directory, briefs named and ordered explicitly). A challenge living in a chat
log or a head is an anecdote, not an artifact. And they are not byproducts:
**producing standing challenges is part of what the methodology is FOR.** The
telos converts human touches into things that fire on their own — prose becomes
runnable invariants, recurring commission-shapes become replayable challenges.
A repo with no standing challenge is an early repo with a visible absence, the
same way "no hub yet" is. The Gardener reads the absence; the walk decides when
recurrence has earned the promotion.

## A challenge is a garden of things — the ecology

A challenge is not one thing, and a mature project does not grow *a* challenge —
it grows a **challenge ecology**: a family of standing generators, each covering
a different organ of the product. The worked example is intranquil's four:

- `SYNTH_CHALLENGE` — grow the instrument catalog (the sound-making organ)
- `PRESET_CHALLENGE` — grow each instrument's expressive range
- `PANEL_CHALLENGE` — grow the visual/control surface
- `AUDITION_CHALLENGE` — grow the judging/listening surface

Four briefs, four catalogs, one product — and the family shape is the point:
when a project has exactly one challenge, that is usually an *early* state, not
a final one. Each organ of the product that produces divergent, catalog-shaped
work can earn its own generator (by recurrence — see the meta-layer below; an
organ earns a brief the same way any recurrence earns promotion). Siblings stay
**independent**: each brief seals on its own, replays on its own, and judges
against its own catalog. The ecology is plural, not coupled.

## Chained challenges — catalogs feeding catalogs

Independence is the default, but it is not the only shape. The second structure
an ecology can grow is the **chain**: a staged pipeline where **one challenge's
catalog is the next challenge's input.** The worked example is the vocabulary
pipeline (6digit-world): find real-world-data use cases (stage 1's catalog:
dataset-grounded use-case directories) → float an ontology from each data source
(stage 2's catalog: named vocabularies) → encode signals and world models from
the ontology (stage 3's catalog: runnable instruments).

The rules that keep a chain honest:

- **Each stage is itself a replayable brief** — sealed, self-grounding against
  its own catalog, with its own done-gates. A chain is not one long task split
  into thirds; it is N generators, each independently replayable.
- **The link between stages is the catalog, never a conversation.** Stage 2's
  contestant reads stage 1's *artifacts* (runnable, on disk) — it is never
  handed a transcript, a summary, or the walk. The sealed shell holds at every
  link; chaining adds no new aperture.
- **Stages replay at different rates.** A chain is not a lockstep pipeline run
  end-to-end each time: stage 1 might replay monthly while stage 3 replays
  daily against the standing output of stages 1–2. Each catalog is a stable
  shelf the next stage pulls from, not a buffer that drains.
- **The walk arbitrates between stages.** What flows down a chain is what
  *survived judging* — the human taste-gate sits between every catalog and the
  stage that drinks it. A chain that auto-feeds unjudged output downstream has
  rebuilt the unattended pipeline ADD refuses to be.

## Why a challenge makes a session productive with no walk

The founding ADD problem is "I don't know what we're working on — propel us
forward." Muse→Scout→Commission *derives* a bespoke slice to answer it. A
challenge answers it a different way: **the work is already decided, and the
challenge re-grounds itself.** You pull a standing generator off the shelf and
you're productive in one move. That is why it earns its own door.

Mechanically, a challenge **is a pre-baked, reusable Commission** (Phase 3) — the
lossy charge distilled *once*, written down as a sealed brief, and replayed
instead of re-distilled each run. The dedup-and-diverge step (below) replaces the
Scout's gap-finding: the contestant re-derives "what's missing" by reading the
catalog, every replay. Walk → Scout → Discriminate → Commission collapses into
*pick the challenge, replay it.*

## The anatomy of a replayable challenge

What makes a brief *replayable* rather than a one-shot task — pulled from the synth
challenge, because these are the load-bearing parts:

- **A sealed second-person brief.** Written *to the contestant* — "you ARE the
  contestant; do not ask which direction; pick one, name it, ship." It is the
  sealed shell as a *file*: a lossy commission that carries content (the
  substance, the standards, the done-bar) and never process (the wander, the
  roles). A challenge that pauses to ask the human which variant to build has
  negated its own design.
- **Variance is the metric.** Replays are only productive if they *differ*. The
  brief must say so in as many words — variance across contestants is the single
  most important measure of success — or the fleet converges and the catalog stops
  growing in reach.
- **Self-grounding against its own output.** Before building, the contestant reads
  the existing catalog and brings something *not already there*. This is the step
  that makes infinite replay productive: the challenge is aware of its own prior
  outputs and diverges from them, every time. It is the Scout's gap-finding,
  internalized into the brief.
- **Hard done-gates plus a human taste-gate.** Objective gates the contestant can
  self-check (it builds, it loads, it isn't silent/NaN/degenerate) *and* a final
  judgment only the human can render ("yes — that's what you said it would be").
  The objective gates are why each replay yields something **releasable by
  construction**; the taste-gate is why it's worth keeping.
- **Zero-friction append.** Adding an artifact must cost no integration work — a
  build that auto-discovers the new submission, a self-contained directory, a
  one-line catalog entry. The pit of success, literal: the right move (ship
  another) is the path of least resistance.

## Running a challenge — the day

1. **Pick the challenge** (the human names it, or you offer the catalog's menu).
2. **Spawn contestants** the normal sealed way (`../arbiters/contest.md`) — each
   handed *only* the brief, served the standards first, blind to each other so
   variance survives. The brief already carries the commission; you do not
   re-derive it.
3. **The contestants self-ground, diverge, build, and self-check** against the
   done-gates.
4. **Judge on the walk** (`../arbiters/judge.md`) — verify the claims yourself,
   apply the taste-gate, and the survivors **append to the catalog**. Losers
   evaporate with their worktrees; petals fall.

A challenge day can spin this loop **many times** — that is the inner cycle: the
basin ripple. You stay generative, the catalog grows, and you never have to climb
a rim until the breath calls for it.

## Creating and tuning a challenge — the meta-layer is gardening

Running a challenge is object-level. **Creating or tuning one is meta-level, and
it is a Gardener act** (`../arbiters/gardener.md`) — you are tending a
*generator*, not a bed. The two are different leverages:

- **Creating** a new challenge widens the catalog's reach: more variation, bigger
  output for less input. The trigger is **recurrence** (the Gardener's law): when
  you notice you keep bespoke-commissioning the same *shape* of work, that
  recurrence has earned promotion into a standing generator. (This is the third
  promotion target — see `../arbiters/gardener.md`.) The same law grows the
  *ecology*: a second organ of the product showing challenge-shaped recurrence
  earns the family's second brief.
- **Tuning** an existing challenge is *higher* leverage than running it, because a
  better generator improves **every downstream replay at once.** This is the
  flywheel applied to the generators themselves.

Because tuning changes all future outputs — and can orphan the existing catalog
(sharpen a non-negotiable and yesterday's entries may fall out of spec) — **a
challenge brief is a slow-clock object, governed like `SCENE.md`:** read-many,
write-rarely, deliberate, logged. The brief is to its catalog what the scene is to
the repo — a slow-clock generator-of-ideal, with the catalog as its fast clock.
Tuning is a Gardener-day act, not a casual per-run tweak.

The generator-of-generators is real and already runs: a fleet of proposers →
adversarial judges → a synthesizer, auditing the loop and proposing new challenges
(the "challenge-challenge" in `6digit-world`). That fleet is sealed; the *adoption*
of a proposed challenge stays with the walkers. Creating generators never crosses
the wall into a sealed shell that could spawn its own walk — ADD stays
non-recursive by construction even one level up.

## The boundary: divergent vs. convergent

A challenge is for **divergent, catalog-shaped work** — domains where variance is
the value and there are many valid outputs (synths, world models, scenarios,
pedagogy). It is the **wrong** instrument for **convergent work** — "close the
keystone," "fix the one bug," "ship the one release" — where there is a single
right answer, not a catalog of variants. Those are *tasks*: the ordinary walk
(Scout → Commission → Contest), not a generator. Do not challenge-ify the
one-right-answer work; the moment you do, "variance is the metric" becomes a
license to produce noise around a problem that wanted a single correct move.

## The catalog stays runnable — the flywheel holds

The catalog is the long-running artifact, and it survives the "docs are transient"
rule for one reason: **its entries are runnable, not prose.** A synth builds,
renders, and gets listened to; a world model executes. The catalog is accumulating
*code that runs*, not a design doc rotting toward context-poisoning. Keep it that
way: an entry that can't be run isn't a catalog entry, it's a lie waiting to
mislead the next replay.

When the challenge day is done, carry the grown catalog back to the walk and hand
off (Phase 7) like any other run.
