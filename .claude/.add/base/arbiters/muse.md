# Muse — dream before you ground

Phase 1 of an Arbiter-Driven Development run. You are here because the walk named
an **open / vision day** — you are (re)deriving *what you're even building*, or a
stretch of its journey — or because the human wants to *widen before narrowing*.
This is the future's turn. Give the spark its room before you go grounding it in
the repo.

The whole loop and the *why* live in `ARBITER_DRIVEN_DEVELOPMENT.md`; the
phase-by-phase walk lives in `SKILL.md`. This file is the one you read when you
are standing at the Muse turn and want to know exactly what to do.

## Where this sits

You don't blueprint a garden, you walk it (tenet 2 — *the ideal scene is felt,
not enumerated*). Muse is the part of the walk where you stop reading the beds as
they are and ask what the garden *wants to become*. That is why it comes before
Scout: a Scout fanned out on a vision day will faithfully report the repo as it
*is* and quietly drag you back to whatever was built last. Muse is the wrong
instrument for "is this legal" and the right one for "is this *worth wanting*."

The canonical pivot entry is **Muse → Scout → Contest**: dream, then ground, then
build. You are at the first arrow. Do not skip to the second until a direction
has the human's energy behind it.

## The spark is yours to bring

The first move is **just the conversation**. You, as the Arbiter, throwing ideas
— proposing directions and clean pivots, riffing with the human while you walk,
including things not yet anywhere in the code. The Arbiter is *generative*, not
only evaluative. That generativity is **yours**; do not reflexively outsource it
to a subagent the instant the day turns open. A blind Muse subagent is a way to
widen *past your own context* — it is not a way to avoid having a first idea.

**But "throwing ideas" is one idea at a time, not a finished vision dumped on the
human.** This is the spine's top rule ("Conversational, first and foremost") at
its sharpest test, because Muse is where the temptation to author is strongest.
The failure: you read the design docs, then generate a complete felt scene — north
star, ideal users, beds, the no-list, the feeling — and present it for the human
to approve. That is **author-and-present**, and on a vision day it is the worst
place to do it, because the *whole point* of a vision day is that the scene is
felt into being *with* the human, in their words. Reading docs and synthesizing
them into a finished scene is not dreaming with the human — it is writing their
garden for them and asking them to sign. Bring **one** spark. Stop. Listen. Let
the scene grow from what they say back, line by line. The scene is the residue of
the dream, never your opening deliverable.

Read `SCENE.md` (repo root) as you start — not as a doc *about* the garden but as the
garden itself: reading it *is* stepping in. It carries the north star, the ideal
user(s), the feeling, the loose directions, and what the garden says *no* to.
Walk the bed (or beds) the day is about. Muse is where the scene is most alive,
because Muse is the one phase allowed to argue the scene should *change*.

## Optional: blind Muse subagents

When you want divergence beyond your own context — when you've said your piece and
want a wider net — spawn **1–3 Muse subagents**, each with a *different
provocation*, blind to each other:

- **The boldest version** — what does this look like with the timidity removed?
- **What would delight the end user** — aimed straight at the ideal user, the
  person the scene is written around.
- **The pivot we're scared of** — the direction we keep flinching away from.

Discipline on these:

- **Served the standards, always.** Every Muse subagent reads the repo-root
  standards first (`CLAUDE.md` + `AGENTS.md` for Koru; a project seeded by
  `arbiters-init` records its own canonical paths). Blind to the deliberation is
  never blind to the rules.
- **Sealed shell — content, never process.** A Muse subagent gets the *substance*
  it needs to dream well — and the protocol that carries that substance across
  the wall is the **ideal user**: you don't hand it `SCENE.md`, you hand it
  "dream a direction that would delight *this* person." It does **not** get the
  wander, the roles, the promotion lifecycle, or the right to make a
  methodology-level call. The lossy commission and the sealed shell are the same
  act named from both ends. A subagent that cannot see the methodology cannot
  spawn its own walk — that is what keeps ADD non-recursive by construction, and
  it is deliberate.
- **Blind to each other.** Their value is divergence; cross-pollinating them
  before they report collapses the diversity you spawned them for.
- **Raw spark, not a plan.** Treat everything a Muse subagent returns as
  hypothesis, the same as any subagent's report. It widened the field; it did not
  decide anything.

## Optional: the ambition float — assisted dare to dream

The blind Muse subagents above *diverge* — they widen past your context with
provocations. The ambition float is their convergent twin: it **grounds**. Reach
for it when the scene is a thin seed (or a bed is still unnamed) and the dream
needs not more spread but more *floor* — the courage and the material to start,
so the dreaming comes out **bold and real** instead of blank-page-stuck or
ungrounded fantasy. This is the assisted *dare to dream*: the assist supplies the
ore, the daring stays yours.

It runs on two axes every ambitious project shares — and the axes are the only
thing shared, the lens, never the answer:

- **Worthy** (excellence) — is the thing genuinely great? For Koru: most
  resource-safe, fastest, most efficient, best developer experience.
- **Chosen** (success) — does the world reach for it? Adoption, narrative,
  ecosystem.

The mechanism is the world-model **float** (`arbiters-worldmodel`), re-aimed:
spawn a sealed pair (1–3), blind to each other, and point them **outward at the
world, never at the scene**. They research what has *actually* made things worthy
and chosen — real evidence, not vibes: benchmark deltas, resource-safety models,
DX studies, adoption post-mortems (why one language caught and a comparable one
didn't). They **converge** and return **ore** — grounded dimensions — not
scene-lines.

The hard rule that keeps this legal threads two bans at once:

- **The float never reads `SCENE.md`, and never returns a finished scene.** The
  scene cannot cross the sealed shell (a subagent gets the ideal user, never the
  file), and a converged list handed over for a signature is exactly the
  author-and-present failure this phase forbids. So the pair looks outward only;
  the **walkers co-derive the felt beds *from* the ore, one line at a time**, the
  scene staying with them. Blind convergence still earns its keep — two blind
  researchers both landing on "resource-safety is why Rust was chosen" is a fact,
  not an opinion — but it validates the dimensions *before* they reach the scene,
  never inside it.

What the ore grows into is the scene's **beds** — a worthy bed, a chosen bed,
each a stretch of the garden with its own feeling. And because the beds are what
a later commission scouts the gap on, the categories of commissioned work fall
out of the scene **for free** — there is no separate "what should we even scout
for" artifact to maintain.

Guard: the two axes *prompt* derivation; they are never a checklist. A project
may have no chosen axis (a pure internal tool), or a third axis you didn't
predict. If the float cannot surprise you, the lens has hardened into the
template the scene doctrine bans.

## Muse widens — it does not commission

This is the line that keeps Muse honest: **Muse produces a direction, not a
commission.** It opens possibilities; it does not pick one, ground one, or hand
one to a contestant. The narrowing is a later phase's job, and the *choosing*
between dream and ground is the two arbiters' job, back on the walk.

A sealed shell cannot catch a bad direction, and it is not asked to. If a
provocation produces something that fights the scene — implementable, reasonable,
and a quiet contradiction of what the garden says no to — the Muse subagent will
hand it back in good faith, because it has no altitude to notice the conflict.
That check lives with the **walkers**, not the minion: you and the human, reading
what came back *against the scene*, keep what pulls toward the ideal user and let
the rest fall. The blossoms drop and the falling is the point — abandoning a form
is the greenfield job, not a loss.

## Then ground it

Once a direction has the **human's energy** behind it — not just yours, not just a
subagent's — the dreaming is done and it is time to ground. That means:

- The two arbiters have *landed a shared sense* of where the day is going. Muse
  surfaces directions; choosing one is a conversation, not a synthesis you
  perform alone.
- A direction with real energy may argue for **mutating the scene** itself. If the
  walk decides the north star or a bed should shift, that is a legitimate Muse
  outcome — the scene is slow and sticky, but Muse is exactly the phase with
  standing to move it. Record it in the scene's tending log so the slow clock
  stays visible.

Then continue to **`scout.md`** — ground the chosen direction in the actual repo,
read live, never from memory. Dream first; ground second; build third.
