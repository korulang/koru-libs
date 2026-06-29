# Arbiter-Driven Development (ADD)

> Born in Koru; the method is project-agnostic. This file is the **why** — the
> prose spine you read to *understand* ADD. The skills (`arbiters-init`,
> `/arbiters`, the Gardener) are where you *execute* it; they stay terse and
> defer here.

*For people with ADD.* You wake up with no plan. Sixteen hours later the course
of the project has changed — and you got there by **walking and talking**, not by
writing a spec. That is the purpose, stated plainly: start a session
**near-scratch** — armed only with the `prose` tool, the current state of the
repo, and the garden you keep — and get moving on *something* of high value,
without a backlog to consult or a plan to inherit. If it isn't obvious what the
point is on a given run, that *is* the point: re-derive the work live, every time.

## The thesis: conversational development scales

The industry's answer to "chatting with the AI doesn't scale" is **spec-driven
development**: write the spec first, hand it to the agent, the spec becomes
persistent memory (GitHub Spec Kit, AWS Kiro). It treats the exploratory,
conversational style as the amateur mode and paves over it.

ADD is the contrarian bet: **conversational development *does* scale — you just
move the conversation up to the orchestration layer.** You stay in the loose,
exploratory mode. You talk to *one* agent — the Arbiter — and the work fans out
beneath you into fresh, isolated agents. You keep the part you love (thinking out
loud, changing your mind) and get parallel scale anyway. The spec-driven crowd
reinvented "the repo is the source of truth" and then walked it backwards into
documents. ADD keeps it pointed forward: the **repo is the living backlog**, and
agents read the agenda *off it* every time.

## Development is gap-closing

Underneath the thesis is a single definition of work. Development is the distance
between an **ideal scene** and the **existing scene**, turned into a slice. No work
without a gap; no gap without both ends visible. Every loop of ADD is that
subtraction made concrete: you read where you want to be, you measure where you
actually are, and the difference is the only thing worth building. This is why
ADD has no backlog and needs none — the gap regenerates itself live from two
surfaces that are always present, so there is never a stale list to maintain.

## Close gaps against the world — the external reference

Gap-closing needs both ends visible, and the *desired* end is the hard one:
synthesizing honest, gappable metrics from inside your own project is
genuinely difficult — invented numbers drift toward proxies. The unlock is to
**borrow the desired state from reality**: an existing system, a competing
project, a public dataset with independent ground truth. The proving ground was
audio — a plugin clone is gap-closing against a black box that already exists,
and the gap (A/B-distinguishability, ULP-distance from a reference runtime) is
measurable for free.

The **reference ladder**, generalized from that proving ground: **bit-exact**
(exact diff against a reference implementation) → **behavioral A/B**
(indistinguishable from the black box on the same inputs) → **subjective** (no
reference exists; the human taste-gate closes). Generalizing out of any one
domain means finding the next domain on a rung *with a closer*.

The deep property, and why this section sits next to the truth hierarchy: **an
external reference is the one ground truth that cannot co-evolve with your
implementation.** Tests and compiler co-evolve — that is why neither is ground
truth and conformance fraud is always possible. But you cannot edit the
reference plugin to match your clone, and you cannot nudge the tide gauge
toward your prediction. Reference-anchored gaps are immune to conformance
fraud by construction, which makes them the strongest measures the method can
hold. Hunt them on purpose (the Scout's **reference hunt** lens, `scout.md`).

Three disciplines ride along:

- **The reference anchors the *measurable*; the scene anchors the *wanted*.**
  Parity with an existing system is a measure, not a telos — chase it blindly
  and you are building someone else's product (tenet 6, the proxy trap).
- **In-sample ≠ out-of-sample.** Fit against history; trust only the holdout
  the contestants never saw.
- **Prefer ground truth from an independent source** — judged by a different
  instrument (or agency) than the one that produced the data you fit on.

## The garden

The load-bearing metaphor is a **garden**, and it is chosen with care over "a
finished house." A garden is never finished — it is *felt* not specified, alive,
tended, a little different every season. That is the exact stance ADD wants:
well-architected but still fluid. The ideal scene **is** the garden.

`SCENE.md` is not a doc *about* the garden. Reading it **is** stepping into the
garden — you walk the beds, you feel the north star, you sense what the place says
no to.

The **wander** is the heart of it, and it is why the methodology is named
**ARBITERS**, plural on purpose: it is the two of us — human and agent — walking
and judging *together*. Scouts and contestants are sent off *from* the walk and
report *back* to it. That plurality is the whole reason it is "arbiters" and not
"pipeline": there is always a conversation at the center, and the subagents serve
it rather than replace it.

The **cherry blossom** — sakura — is transience: blossoms fall and the falling is
part of the beauty, not a loss; that is the greenfield stance exactly, where
breaking things is the job, red is appreciated, nothing is precious, and petals
dropping are the old form being gladly abandoned.

### Why the garden is load-bearing, not decoration

The garden is **why ARBITERS refuses to run headless.** It returns to the walk
between every phase. The conversation is mandatory; the human and the agent walk
it *together*; scouts serve the walk, they never replace it. This is the
operational rule the metaphor carries everywhere it appears — and it carries that
rule on *every* appearance precisely because a cold subagent, handed
"wander through the cherry blossom garden" as a bare banner, will optimise it
straight out unless the words are load-bearing. So: the garden, the wander, and
the blossom never sit as ornament. Each time one shows up, it is enforcing
"return to the walk; do not go headless."

## The eight tenets

These are the canonical statement of the method. This is their only full home —
everywhere else references them by number or name.

1. **Development is gap-closing.** Every loop is the distance between an ideal
   scene and the existing scene, turned into work. No work without a gap; no gap
   without both ends visible.

2. **The ideal scene is felt, not enumerated.** It lives in `SCENE.md` — read on
   every walk, written only by the slow clock, and never handed to a sealed
   subagent. The ideal **user** is the transmissible anchor. We say no to the
   slices; rarely to the scene. (Garden form: you don't blueprint a garden, you
   walk it.)

3. **Measure where you are, live.** The existing scene is read from the actual
   repo every session — never from memory, never from the scene's own description
   of itself. A corrupted instrument makes every downstream move blind.

4. **Low friction, high transparency — co-equal with shipping the slice.** The
   harness is engineered so that staying oriented costs no willpower and the true
   state is unavoidable. Every retrospective asks: what friction did we tolerate,
   what state stayed invisible?

5. **Build the pit, not just the floor.** Three promotions, triggered by
   **recurrence** not prophecy: a felt principle that keeps getting violated
   graduates to a hard wall (compiler reject, gate, pinned test); a manual
   high-friction loop graduates to an engineered organ; a recurring slice-*shape*
   graduates to a **replayable challenge** (a standing generator that grows a
   catalog). The harness is the enforced residue of every gap closed hard enough
   to never reopen.

6. **Aim the slope at the scene.** The pit-of-success machinery is amoral — it
   rolls work toward whatever the harness rewards. Point the gradient at the ideal
   scene and the ideal user, never at the proxy metric. Three real bugs beat one
   mass-unblock.

7. **Feedback is a candidate, not a command.** External signal — website feedback,
   stakeholder resonance — enters at session start, is tested *against* the scene
   by scouts, and is arbitrated by the two arbiters. It may argue for mutating the
   scene; it never silently becomes it.

8. **Upstream first.** When a defect is traced to a generator — the method, a
   skill file, a template, a toolchain — fixing the generator precedes all work
   downstream of it, *including the work that surfaced it*. The fix is paid once
   upstream and collected on every downstream artifact forever; meanwhile every
   downstream move is built on a known-bad generator. Downstream resumes only
   when the human explicitly defers the upstream fix. This is the priority the
   agent's defaults invert — the pull to ship the visible artifact and leave the
   generator fix as a deferred offer. The offer is the dodge.

## Plant, walk, tend

The three skills are one continuous figure — three things you do to a garden:

- **`arbiters-init` = plant the garden.** Author `SCENE.md` — the first walk, the
  ideal user, the feeling. A one-time bootstrap, not the daily run.
- **`/arbiters` = walk the garden.** Read the scene, measure the existing scene,
  slice the gap. This is the run.
- **The Gardener = tend the garden.** Prune what fights the scene, plant the
  pit-of-success walls that keep growing on their own, reshape the beds.

## The breath — inhale, exhale, and the cauldron of days

Walking the garden is not one uniform activity; it **breathes**. The day-types sit
on a single axis from hard **inhale** to hard **exhale**, and the shape of that
axis is a **cauldron** — two high, effortful **rims** with a common, shallow
**basin** between them:

- **Muse** is the **inhale rim** — rare, hard, generative: dream what isn't there
  yet (the future).
- **Tactical (Scout)** and **Generative (Challenge)** are the **basin** — common,
  daily, low-amplitude: ground the next move, or replay a generator so the catalog
  grows. This is where most days are spent.
- **Gardener** is the **exhale rim** — rare, hard, consolidating: prune, tighten,
  promote, pay down debt (the soil).

You climb a rim only **every once in a while**, and from the basin you climb
**either** one — whichever the day calls for (vision gone stale → Muse; exhale
overdue → Gardener). Over wall-clock time this oscillation *is* the breath, and it
is a **cycle within a cycle**: the challenge loop ripples fast in the basin, nested
inside the slow rim-to-rim breath.

**The structural bias to design against: the method leans inhale.** Muse, Scout,
and Challenge all *make more*. The Gardener is the only organ that *takes away* —
and for a long time it lived only as a tail-phase (the retrospective), with no
front door. So it never got invoked, and work drifted ever further from
releasable. This is the real, mechanical source of the "I never polish, I never
ship" problem: not a discipline failure, a **missing door**. The fix is cheap and
structural — **the Gardener is a first-class day-type, present on the walk's menu,
read every run.** It *invites* the exhale (you can always drop back into the basin
and inhale again — it never gates), but naming it every walk turns over-inhaling
into a choice you *saw* rather than an accident you backed into. That is tenet 4
applied to the breath itself: the exhale-debt must not be invisible state.

The eventual organ for this is a **live exhale-debt gauge** — a world model
(WMFX-style; see `6digit-world`) that taps the dev-work faucet and emits an
"exhale overdue" signal, making the Gardener door *glow* when you have held your
breath too long. The trigger is **signal-driven, not a metronome**: you exhale
when the modeled debt crosses, not when a timer elapses (a fixed-period exhale
would be cargo-culting the ritual — the methodology is a servant). Until that
organ exists, the door's mere **presence** on the menu is the keystone.

This is also where the old **inhale/exhale** intuition lands: inhale is the basin
and the Muse rim (build fast, let red accumulate as breadcrumbs); exhale is the
Gardener rim (stop building, consolidate). ADD keeps the rhythm but replaces the
crude two-season switch with a continuously-steered breath — and it replaces
exhale's naive "delete the lying test" reflex with the asymmetric truth hierarchy
(a failing test is a design question, never automatically the test's fault).

## SCENE.md — the garden made hand-walkable

`SCENE.md` is the garden turned into a felt file. It lives at the **repo root** as
`SCENE.md` — *not* inside `.claude/`; it is a felt vision the human should see in
plain sight, not buried in a tooling dotdir. Project-local, project-owned,
travelling with the repo. Each project has its own garden.

It contains: a north star · ideal user(s) · the feeling · loose directions ·
what-it-says-no-to · and a light **tending log** (last-mutated, by which loop) so
the slow clock is visible — tenet 4 applied to the scene itself.

The header a cold reader must obey is fixed discipline: **read-many,
write-rarely**; scouts get the ideal-user, **never** this file. There are two
clocks at play — the scene is slow and sticky, the existing scene is fast and
live — and a reader who confuses them measures from the wrong instrument.

The scene **subsumes and upgrades** the old scattered "north star" pointer. The
toolchain/orientation skill stays terse and is the *existing-scene* instrument;
`SCENE.md` is the *ideal*. One garden holds **many beds**: a north star plus named
beds (sub-scenes), and a session picks which bed to walk.

`SCENE.md` is **born-original** — authored unique per project, never copied from a
reference and never reconciled against a template. It is therefore **excluded
entirely** from the `arbiters-init` upgrade-mode 3-way merge: pure local
sovereignty. There is no reference `SCENE.md`, ever. And a thin honest stub
("no north star yet — here is the seed") beats a faked-complete scene: init must
not block on a complete scene.

## The hub — the existing scene, rendered

`SCENE.md`'s counterpart on the fast clock. Where the scene holds the *ideal*,
the hub renders the *measured present*: invariants, gaps, and statuses
**computed from the repo, never hand-maintained.** It is the board the two
arbiters read together — the place where they meet over the *same* rendered
state instead of each holding a private picture of it, and where a declared
invariant self-appears the moment it exists. Trust→sight, given a street
address: an invariant you can watch fire is one the human no longer has to
carry in their head.

Name what the hub actually is, because it sets the design pressure as the
system grows: **an attention market, ranked by surprise.** Attention is the
scarce currency the whole method economizes — surprise is what bids for it.
As instruments multiply (and especially once channel-watchers watch the
faucets themselves), surprise streams will outnumber what any walk can
attend; the hub's deepest job is the *ranking* — deciding which surprises
deserve the two arbiters' next glance. A hub that renders everything equally
has abdicated; the board exists to spend the human's attention well.
(Encoded 2026-06-11, the night the watcher conjecture fired.)

A project without a hub keeps its current state in the human's memory — which
is precisely the cognitive expenditure the method exists to eliminate. The hub
is therefore not project decoration; it is an artifact of ADD itself (see the
artifact list below), and "we don't have a hub yet" is a visible gap, not a
neutral absence. Two rules keep it honest: everything on the board is
**computed** (a hand-edited status is a corrupted instrument, tenet 3), and its
ceilings **ratchet toward the scene, never away** (loosening a threshold to turn
a red green is the forbidden move; which side moves is the human's design
question).

What carries across projects — earned from the first two hubs (6digit-world's
panel, membrane's walk, 2026-06-10):

- **Local-only, never published.** The hub is the meeting room for the two
  arbiters, not a broadcast surface. Publication pressure corrupts the
  instrument the same way hand-editing does — a board dressed for an audience
  starts decorating success.
- **The honesty contract.** Every number carries its source, visible at the
  point of reading (hover a cell, see where it came from — provenance is for
  the person who didn't generate the board). A missing value renders as an
  explicit blank (`—`), never a plausible guess. Failure renders loud.
- **Freshness is visible.** Live endpoints and generated artifacts are both
  valid shapes — a project with a running server renders live; a project whose
  state is run-products generates a status artifact. Either way the board shows
  *when* its numbers were computed and *how* to recompute them, so staleness
  can never masquerade as truth.
- **Glanceable home, every tile a door.** The front page is one screen of
  computed vitals; each tile opens into the deeper room that explains it. The
  glance is the human's entry; the rooms are where the two reason together.
- **The board is never writable — but it may hold doors into the system's own
  mutation surfaces.** The forward mechanics of any living system are fallible,
  and perfecting them is a non-goal; what they get wrong is resolved by
  *providing more information*, ideally conversationally. So a hub may host a
  repair console — a chat surface, a merge tool — but repair flows through the
  system's own front door and shows up on the board as recomputed state. A
  repair surface that edits the board directly is the corrupted instrument
  again, one layer up.

## Outcome-gating — the human judges what fires, never the files

The human's taste-gate lands on **outcomes**: the synth is auditioned, never
its DSP read; the instrument is watched flinching at history, never its
harness reviewed; the ontology arrives as "what emerged, what resisted, and
the number behind each," never as file paths. Intermediate artifacts —
briefs, ontologies, model sources, harness code — are the agent's and the
machines'; presenting one to the human for reading is dragging the taste-gate
down to a layer where it doesn't belong. (Encoded 2026-06-11, from the
human's own correction: "the artifacts should be hidden from the user and the
only thing the user should look at is the end outcome.")

Two consequences keep it honest. First, the burden inverts: if an outcome
cannot yet be made observable, the agent says so plainly instead of handing
over prose — an unobservable outcome is a missing surface, which is itself a
gap on the board. Second, the cost is named: defects in ungated artifacts
surface only downstream, one replay later, as bad outcomes. That trade is
accepted deliberately — it is the telos (human attention only where
irreplaceable), and the mitigation is never "have the human read more"; it is
*make more of the outcome watchable.*

## Roles

Each role has one job and a one-word name. They triangulate the work in *time*,
plus one that faces the machine:

- **Arbiter** *(you + the orchestrating agent)* — the only conversation you have,
  the two who walk the garden. Curates every phase; commissions the work; decides
  what merges. Its core value is **lossy compression** at the seams (below).
- **Muse** — the **future**. Divergent ideation. Proposes directions, including
  clean pivots and things not yet in the code. *Widens.*
- **Scout** — the **present**. Read-only reconnaissance of the actual repo;
  returns evidence-grounded, ranked moves (`file:line`). *Narrows.* Not the first
  responder — you dream before you ground.
- **Contestant** — builds **one** commissioned slice in an isolated git worktree.
  Blind to the deliberation, so it brings fresh judgment. Returns a diff + writeup.
- **Gardener** — the **soil** (the harness: toolchain, tests, prose,
  context-injection). "Pit of success" as a role — the *harness-is-the-product*
  thesis given a seat. Named for *koru*, the unfurling fern: it cultivates the
  conditions for growth, prunes the dead — including the documentation the merged
  code now embodies — and enriches the soil. Runs as a **retrospective with an
  immediate action plan**, not a front-loaded hunter.

Orientation isn't a role — it's an instrument: **`prose`**, depth-dialed
(`snap → whisper → gossip → standup`) by how lost you are. It reads the **past**.

## The two seams (this is the whole trick)

Both boundaries are **lossy compression**, and the lossiness is the *feature*:

1. **Commission** *(kickoff → contest)* — the Arbiter distils everything kickoff
   surfaced into one self-contained charge: target (grounded) · value ·
   non-negotiables · forcing-function framing · orientation pointer · **the
   standard it must conform to** (the project's rulebook / invariants — a pointer
   is enough). It does **not** carry the deliberation, the rejected ideas, or the
   other findings. A contestant blind to all that brings fresh judgment instead of
   inheriting our biases — which is what keeps variance alive. But blind to the
   *deliberation* is not blind to the *rules*: drop the standard from the charge
   and the contestant will earnestly build something the language forbids. That is
   not hypothetical — see the worked example below.

2. **Handoff** *(run → run)* — the same move, one level up. The retrospective's
   last act is a marked **`↪ HANDOFF`** sign-off, set with `prose baton set` and
   spoken into the session (position · advisory next-move · explicit permission to
   pivot). It persists durably in the `~/.prose` vault and rides the journal for
   free; the next fresh session reads *it* via `prose baton`, not the whole
   transcript (a raw `prose grep "↪ HANDOFF"` is the fallback). It is **not** a
   seam-list — listing accumulating seams is the backlog we refuse. The Scout
   re-derives live work from the repo each run; the handoff just says *you are
   here*.

## The sealed shell

Subagents get the **content**, never the **process.** A scout needs the substance
of the bed it judges against; it does *not* get the wander, the roles, the
promotion lifecycle, the gardener stance, or the right to make methodology-level
calls.

The **ideal user** is the protocol that carries content across the wall: you don't
hand a scout `SCENE.md`, you hand it "judge this against *this person*." The lossy
commission and the sealed shell are the **same act named from both ends** — the
lossiness *is* the sealing.

Withholding the methodology from subagents makes ADD **non-recursive by
construction**: the garden stays with the walkers; a subagent cannot spawn its own
walk.

And the consequence that closes the loop: **a sealed shell cannot catch a bad
commission.** If the brief is wrong, the scout executes it faithfully — it has no
altitude to notice "this fights the scene." So the check on a bad commission is
never the subagent; it is the two arbiters, back on the walk, judging what came
back. Never expect a scout to push back on a misframed task — that pushback lives
with the walkers by design.

## The pull-feedback valve (session start)

Step 0 of a run pulls website / stakeholder feedback. Scouts test each item
**scene-relative** — not codebase-relative — and the two arbiters arbitrate.

The reason it must be scene-relative is sharp: "does this fit the codebase" says
yes to almost anything, because the codebase is permissive. "Does this pull toward
the ideal scene" catches well-meaning feedback that quietly imports a foreign
philosophy — a `Result` type, say, or a happy-path branch: implementable,
reasonable, and a direct contradiction of "branches are equal, no happy path." The
scout flags the items that fit the code but fight the scene; those are exactly the
ones to arbitrate, usually to reject.

Discord and stakeholders are **not just an audience** — they are a slow-clock
loop-closer (stakeholder resonance, tenet 7). But it is a **weak, lagging,
gameable** signal: read in aggregate over time, never as a per-post verdict. One
enthusiastic reaction becoming "evidence the direction is right" is
broadcast-volume sneaking back in.

## Pit-of-success (Gardener doctrine)

The Gardener has three promotion targets: (a) a felt principle that keeps getting
violated → a hard wall (compiler reject / gate / pinned test); (b) a manual
high-friction loop → an engineered organ; (c) a recurring slice-*shape* → a
**replayable challenge** (a standing generator — see "Replayable challenges"
below). The trigger is always **recurrence, not prophecy** — a thing graduates
because it kept happening, not because someone predicts it will. Aim the slope at
the **scene**, not the pass-count.

The Gardener also **mutates the scene.** That is the second flavour of rejection:
scout work faithfully executed, the diff clean, and it *still felt wrong* — which
is the signal to reshape the beds rather than fix the slice.

The stance: a well-tended garden does not *force* the walk, it *invites* it.
Compiler walls are hedges; low-friction sightlines are clear paths.

## The flywheel: code is the memory, docs are transient

This is the engine that prevents context contamination, and it is **universal** —
not a Koru-specific thing:

- **Running code is the durable memory; documents are transient scaffolding.**
  Knowledge lives in what executes. A design doc, a plan, a spec is a temporary
  staging area for an idea on its way into code — not a parallel source of truth
  to maintain alongside it.
- **Once code embodies an idea, the document describing it is dead weight** — and
  worse than neutral: a stale doc that lingers is exactly the context that
  contaminates the next session, because an agent reads it as live intent and
  builds against a plan the code already moved past.
- **So pruning is an active Gardener verb, not passive decay.** After a slice
  merges, the retrospective goes and *deletes* the parts of the docs the code now
  carries. Expunging implemented documentation is the same act as keeping the
  flywheel spinning: less to contaminate, more trust that what's still written is
  what's still wanted.
- **Design questions still belong to the human.** When code and a doc genuinely
  disagree about *intent* — not mere staleness — a subagent surfaces the tension
  with evidence and stops; it never deletes the doc to settle the conflict in its
  own favour. Pruning is for *superseded* docs, never for *contested* ones.

`SCENE.md` is the one deliberate exception to "docs are transient" — it is the
slow clock made into a file, the ideal that the fast-clock code is measured
against. It is tended, never expunged.

### The documentation tiers

"Docs are transient" is not one rule but a ladder. Every written thing in an
ADD project sits on exactly one rung, and knowing the rung tells you its
lifecycle:

1. **Session prose** — fully transient. The journal carries it for free
   (`prose` reads it back); nothing is maintained.
2. **Working documents** — markdown with sketches embedded beside the draft
   prose (shared-canvas exports, hand drawings). Staging areas for ideas on
   their way into code. **Meant to be torn down once encoded** — the Gardener
   prunes them, and a sketch that has been consumed into invariants falls with
   the petals.
3. **Method-instructive documents** — `SCENE.md`, this file, challenge briefs.
   Slow-clock, tended, never casually expunged.
4. **Runnable truth** — code, tests, invariants; with diagrams *generated from
   the code* (Mermaid projections), regenerated rather than maintained. A
   hand-drawn sketch is tier 2 and dies; a generated diagram is tier 4 and
   cannot drift, because it is computed from the thing it describes.

The pull is always downward: prose wants to become runnable. "Hard to encode"
is a real category — genuinely unencodable prose legitimately feeds the ideal
scene — but it is **not a license to cheat**: it never excuses leaving
encodable things unencoded.

## Persistence: no backlog

Four surfaces carry everything between runs. Nothing else is maintained:

- **Repo** — the work (merged code is the state). Commit liberally — git is a
  continuous store, not a ceremony; small frequent commits are the fast clock's
  journal.
- **`SCENE.md`** — the ideal scene (the slow clock, tended not expunged).
- **Journals** — the memory (`prose` reads them; the `↪ HANDOFF` lives here).
- **Skill** — the process (kept current by the flyweight loop).

That's why you can just yap. Each day's conversation leaves its trace in exactly
the places tomorrow's kickoff already looks. No document to keep alive.

## The artifacts — what a tended ADD project accumulates

A project that has been walked and tended grows a recognizable set of organs.
This list is load-bearing three ways: it is `arbiters-init`'s planting
checklist, the Gardener's tending checklist, and a blind session's map of where
to look. Its deeper function is **pit-of-success applied to the method itself**:
naming the artifacts turns a missing organ into a *visible absence* — "we don't
have a hub yet" becomes a gap you can see instead of a thing nobody thought of.

Each artifact carries its clock; anything that can't name its clock and its
tend-or-tear-down rule isn't an artifact, it's clutter.

1. **`SCENE.md`** — the garden made hand-walkable. Slow clock; born-original;
   tended, never expunged.
2. **The hub** — the measured gap rendered as a board; where the arbiters meet
   the same state. Computed from the repo, never hand-maintained.
3. **The invariant registry** — declared runnable invariants that self-appear
   on the hub, with the ratchet rule (tighten toward the scene, never quietly
   loosen). "Prose encodes as measurable," as a file.
4. **The regression wall** — the single gate everything passes. Fast clock,
   always live; the Arbiter's full sweep runs against it at merge.
5. **The challenge catalog + sealed briefs** — briefs are slow-clock generators
   governed like `SCENE.md`; the catalog is their fast-clock accumulated output.
   Both live **in the repo, version-controlled** — a challenge that exists only
   in a chat log or a human's head is an anecdote, not an artifact. And this
   organ is not a byproduct: **producing standing challenges is one of the
   methodology's stated outputs**, the telos made concrete — recurring
   commission-shapes drain out of the human's head into in-tree generators
   that fire without them. A repo with none is an early repo with a visible
   absence, exactly like "no hub yet."
6. **The `↪ HANDOFF` baton** — position-only sign-off, set via `prose baton` and
   persisted to the `~/.prose` vault (it rides the session journal too), read back
   by `prose baton`. Transient by design at the read surface; each supersedes the
   last. The baton is honest about what it is: **the prose placeholder for the
   track (artifact 9)** — lossy by construction, until the real organ exists.
7. **Working documents** — tier-2 markdown + sketches (see the documentation
   tiers). On the list precisely *because* their lifecycle is "die": the
   Gardener needs them named in order to prune them.
8. **Generated diagrams** — tier-4 Mermaid projected from runnable code.
   Regenerated, never edited.
9. **The track** *(named absence — not yet built anywhere)* — a durable,
   surprise-indexed memory of what has gripped the collaboration: which
   invariants fired, which conjectures survived, what seized the walk's
   attention and why — readable by the next session the way a playhead reads
   a mounted tape. The distinction it encodes: *the track is state; the
   playhead (a session's live attention) is experience* — and today only the
   track is missing. The baton (artifact 6) is its prose prosthesis. This
   entry exists to make the absence visible on every walk; building it is a
   future organ, not a checklist item. (Named 2026-06-11.)

## Where prose still belongs — the residue layer

The standing rule is kill prose, encode runnable invariants — and the rule
stands. But it has one honest exception, and naming it prevents both abuses:
**prose is the fallback encoding for invariants that cannot yet be expressed
as mathematics.** When a walk surfaces something load-bearing — a truth about
the endeavor itself, a conjecture the engine has no words for yet — it is
captured in prose *as an invariant awaiting graduation*, not as documentation.
The two abuses this guards against: writing prose where math was available
(laziness wearing philosophy's coat), and refusing to write down a real
invariant because it isn't encodable yet (losing it to the session). Prose in
this role carries a graduation path: it sits where the next walk re-reads it,
and when the encoding becomes possible, it graduates and the prose dies. The
worked example: "the watcher IS the surprise-encoding" lived as a spoken
conjecture for one hour on 2026-06-11, then graduated to a harness-gated
instrument the same night — prose was its larval stage, and the larva's job
is to be temporary. (Doctrine from the human, same night: "this is where
prose actually has a place: when we find these invariants that are very hard
or impossible to encode as mathematics.")

## The flyweight feedback loop

Every agent — Scout or Contestant — returns, alongside its work, **skill-update
suggestions** and an **onboarding note** ("did the injected context get me
*running, not crawling*?"). That note is a live, continuous **benchmark of how
good our context-injection is**, produced by the same agents doing the work. The
Gardener synthesises these in the retrospective and tightens the harness. Better
skill → agents run better → they surface better improvements. The benchmark and
the self-improvement are the same act.

## Contest outcomes (all valid)

- **Bridge** — it works cleanly. Coverage / feature win.
- **Breakthrough** — it needed a deeper (e.g. compiler) change; the contestant
  made it in-worktree and *proposes* it for arbitration.
- **Frontier** — it hit a wall it couldn't cleanly close, so it **pinned the gap
  as a failing test** and reported. A map of where the edge is. A clean frontier
  beats a forced green.

## Replayable challenges — generators, not backlogs

A contest is usually a one-off: distil a bespoke commission, run it once, merge the
winner. But some commissions are worth **replaying** — and a replayable commission
is a different animal: a **generator**, run from zero infinitely, never consumed.

The distinction is sharp and easy to get backwards. A **backlog** accumulates
*pending work* and you grind it to zero. A **challenge catalog** accumulates
*finished artifacts* from a brief that *stays* — run it again and it hands back
another one. The worked example is the Intranquil **synth challenge**: one sealed
brief, replayed dozens of times, and the entire synth catalog (`filament`,
`hearth`, `tether`, `vellum`, `gyre`…) exists *only* because that brief is
re-runnable. Its own closing line is the doctrine: **"the catalog is the
long-running artifact; individual challenges are one slice through it."** This is
why a challenge catalog does **not** violate "no backlog" (persistence, below): it
is a standing generator, not a queue.

What makes a brief *replayable* rather than one-shot:

- **It is a pre-baked, reusable commission** — the lossy charge distilled once and
  written down as a sealed second-person brief ("you ARE the contestant; pick a
  direction, ship; do not ask which"). The seal still holds: content, never
  process.
- **Variance is the metric** — replays are only productive if they differ.
- **It self-grounds against its own output** — before building, the contestant
  reads the existing catalog and brings something not already there. This
  internalizes the Scout's gap-finding into the brief, which is *why* a session is
  productive with no walk: the work is decided and re-grounds itself.
- **Hard done-gates + a human taste-gate** — objective self-checks (builds, loads,
  isn't degenerate) make each replay **releasable by construction**; the final
  "yes, that's what you said" stays with the human.
- **Zero-friction append** — adding an artifact costs no integration work.

**The meta-layer is gardening.** *Running* a challenge is object-level (the catalog
grows). *Creating or tuning* one is meta-level — a Gardener act (pit-of-success
promotion (c)). Tuning is the higher leverage, because a better generator improves
**every downstream replay at once** — the flywheel applied to the generators
themselves. And because tuning changes all future outputs (and can orphan the
existing catalog), **a challenge brief is a slow-clock object governed like
`SCENE.md`**: read-many, write-rarely, deliberate, logged. The brief is to its
catalog what the scene is to the repo — slow-clock generator-of-ideal, fast-clock
output. The generator-of-generators (a "challenge-challenge": proposers →
adversarial judges → synthesizer) is real, but adoption stays with the walkers, so
ADD remains non-recursive even one level up.

**The boundary:** challenges are for **divergent, catalog-shaped** work where
variance is the value (synths, world models, scenarios). They are the wrong tool
for **convergent** work — one bug, one keystone, one release — which is a *task*
for the ordinary walk. Don't challenge-ify the one-right-answer work, or "variance
is the metric" becomes a license to produce noise.

## The asymmetric truth hierarchy

In a greenfield language there is **no source of truth by design** — tests and the
compiler co-evolve. That creates an asymmetry every scout and arbiter must hold:

- A **passing** test is *strong evidence* a shape is intended-legal — use it to
  block **fabrication**. No passing example of a shape is a red flag, not a green
  field. Before you build a shape, find the test that proves it is wanted.
- A **failing** test tells you **nothing** about which side is wrong. Tests and
  compiler co-evolve; "which side moves?" is a **design question for the human**,
  never settled by "the compiler is newer" or "the compiler is what runs."

This is the Koru instantiation of the flywheel — it needs both a test surface and
genuine unspeccability to exist at all — but the asymmetry itself is the teeth.

### Tale 1 — fabrication

`~decide = ~if(...)` — a `~` inside a flow, forbidden by the handbook's first
rule — got ranked, commissioned, built and merged, because no link in the chain
held the rulebook. The Scout ranked it, the arbiters commissioned it, and the
contestant did exactly what it was asked: it taught the parser to strip the
leading `~` so the forbidden code compiled. It "worked." The suite stayed green.
The arbiter verified the wrong axis — *that the change did what it intended*, never
*that the intent was allowed* — and merged it. The compiler was poisoned for one
commit before the human's spider-sense fired on the words "RHS" and "tilde."

The lesson: a lossy commission that drops the **standard** doesn't just waste a
loop — it drives a falsehood into the thing you're building. The fix was to serve
every subagent the standard, and to add the premise-discriminator at the
commission seam. "Verify it yourself" means verify **legitimacy**, not mechanics:
check the diff against the standard, not just the test runner.

### Tale 2 — conformance

The mirror of Tale 1 surfaced on a red cluster of `for`-loop tests: scouts and
even an adversarial discriminator converged on "the tests are stale, edit them to
match the compiler." Every link reasoned identically — *the compiler commit is
newer, the tests no longer pass, therefore the tests are wrong.* That is
**conformance fraud**, the exact twin of fabrication: instead of forcing the
compiler to fit an unratified premise, it forces the *tests* to. Both silently
anoint the newer artifact as truth.

A discriminator briefed only to "find the rule this breaks" **structurally cannot
catch this** — editing tests to match the compiler breaks no rule. So the
conformance-question discriminator gets the **opposite mandate**: surface both
readings plus the design question, render **no verdict** on which side moves, and
be told explicitly that **the compiler may be the wrong side.**

The unifying lesson across both faces: **a subagent surfaces the design question
with evidence for both readings; it never picks which side of the
tests-vs-compiler tension moves.** That pick belongs to the human, back on the
walk.

## Tension is gold

The truth hierarchy handles tests-vs-compiler; this generalizes it. **A detected
internal inconsistency — two invariants fighting, a doc and the code disagreeing
about intent, a rule contradicting a rule — is a harvest event, not an
embarrassment.** It marks, with precision nothing else offers, exactly where a
measure is too crude or a premise is unratified. The system catching *itself* in
a contradiction is the methodology working, and the collision usually yields a
better design than either side held alone (the receipt: an invariant that
counted every tracked `.md` as prose-rot fired on an honest README of a runnable
harness — and the collision produced the "untethered prose" refinement neither
invariant would have found in isolation).

The discipline is the same as everywhere else: **surface the tension on the
walk; never patch it quietly.** Silencing one side to make the dashboard calm —
bumping a ceiling, deleting the doc, special-casing the rule — converts the
highest-value signal the system produces into invisible state. Which side moves
is a design question, and it belongs to the human.

## The methodology is a servant, not a law

One closing discipline, paid for in full by the tales above. The moment you *know*
a change is wrong, you have already left the loop — there is nothing left to
discover, so "run the audit phase" is cargo-culting the ritual. When reality stops
fitting, the move is to break out and use judgment, not to find the right phase to
file the problem under. Knowing when you've deviated is the actual skill. The
garden is tended by people who walk it, not by a pipeline that runs itself.
