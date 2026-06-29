# Gardener — tend the garden (Phase 6, the retrospective)

This is the last leg of the walk. The slice has merged; the two of you are still
on the path, and before you sign off you turn and look back at the bed you just
worked. **Tending is not cleanup-as-afterthought — it is where the harness gets
tighter every loop.** The three skills are one continuous figure: `arbiters-init`
*plants* the garden (authors `SCENE.md`), `/arbiters` *walks* it (reads the scene,
slices the gap), and the Gardener *tends* it — prunes what fights the scene,
plants the pit-of-success walls that then keep growing on their own, and reshapes
the beds when a season's growth came out wrong.

A well-tended garden does not *force* the walk, it *invites* it. That line is the
whole stance: every wall you build here is meant to make the right next move the
path of least resistance, never to fence the walkers in. Hold it as you decide
what to promote and what to leave loose.

The Gardener runs as a **retrospective with an immediate action plan**, not a
front-loaded hunter. You are reacting to what *this* run surfaced, not prophesying
what future runs might need.

## Two sizes — the micro-exhale and the macro-exhale day

The Gardener is the **exhale**, and it comes in two sizes (the breath; see the
cauldron in `SKILL.md`):

- **Micro-exhale** — the retrospective tail of *every* build run. Small, automatic,
  the breath out after each breath in. The rest of this file is mostly this.
- **Macro-exhale** — a whole **day-type** you enter straight from the walk
  (`walk.md`), when the work has drifted far from releasable and the basin is
  thick with red. The *entire session* is tending: no building, no new features.
  This is the exhale rim of the cauldron, climbed every once in a while.

The macro-exhale day exists because the method **leans inhale** — Muse, Scout, and
Challenge all *make more*, and for a long time the Gardener had no front door, so
it never got invoked and work drifted ever further from shippable. Putting the
Gardener door on the walk's menu is the structural fix for the polish/release
headache: it *invites* the exhale, every walk, without ever gating the inhale.

**Exhale-with-teeth.** A whole day of "make it clean" is a whole day of temptation
to mass-unblock — to delete red until the dashboard looks shippable. That is
exactly the conformance fraud the asymmetric truth hierarchy forbids (a failing
test is a design question, not a test bug; the compiler may be the wrong side —
see `discriminate.md` / `ARBITER_DRIVEN_DEVELOPMENT.md`). On a Gardener *day* the
truth hierarchy is **louder, not quieter**. The exhale tightens signal; it never
manufactures green. Three real bugs beat one mass-unblock.

## Gather — the flyweight harvest

Every Scout and every Contestant returned, alongside its work, **skill-update
suggestions** and an **onboarding note** ("did the injected context get me
*running, not crawling*?"). Pull all of them together now. The onboarding notes
are a live benchmark of how good our context-injection is, written by the same
agents that just did the work — better skill, better-running agents, better
suggestions. The benchmark and the self-improvement are the same act.

Apply the small harness and skill fixes **now**, in this turn. **Flag** the larger
seams for the human rather than unilaterally reshaping the harness — a structural
change to the method is a walk-level decision, not a retro chore you narrate past.

**Gardening includes the method itself — close the outer loop.** When a learning
is *method-level* — a rule earned here that every project should inherit — it
does not stop in this project's local skill copy. The installed skills are a
gardened copy of a reference (`6digit-skills`); run `arbiters-reconcile` to carry
the learning upstream, and to pull upstream evolution back down. That is the
flywheel's outer loop: the session improves the code, the retrospective improves
this project's process, and reconciliation improves the method for every
project's next walk. A method-learning left only in the local copy is a gap the
next project re-discovers from scratch.

**Upstream defects don't wait for the exhale.** Tenet 8 (upstream first)
overrides the breath's pacing: when a walk surfaces a defect in a generator —
this method, a skill file, a template, the toolchain — the fix happens *then*,
mid-run, before downstream work resumes. A Gardener day is for accumulated
tending; a known-bad generator is not accumulation, it is live contamination of
every move made under it.

## Prune — implemented docs (the flywheel)

Running code is the durable memory; documents are transient scaffolding. **Once
the code embodies an idea, the document describing it is dead weight — and worse
than neutral.** A stale doc isn't passive: an agent reads it as live intent and
builds against a plan the code already moved past, so it is precisely the context
that contaminates the next session.

So read the docs that described what just merged — design notes, plans, specs,
even this skill's own stale lines — and **delete** the parts the running code now
carries. Pruning is an active Gardener verb. Expunging implemented documentation
is the same act as keeping the flywheel spinning: less to contaminate, more trust
that what is still written is what is still wanted.

One discipline, never broken: **prune *superseded* docs, never *contested* ones.**
When a doc and the code genuinely disagree about *intent* — not mere staleness —
*surface* the tension with evidence and stop. That is a design question for the
human; a subagent (or you, in retro reflex) never deletes a doc to settle a
conflict in its own favor.

## Sweep — the worktrees

`git worktree list`. Contest worktrees are supposed to auto-clean, but a *locked*
or *dirty* one (the contestant left edits behind) won't. Once you have confirmed
its work is merged or superseded, remove it (`git worktree remove --force`, after
`git worktree unlock` if locked) and delete the stale `worktree-agent-*` branch.
Leave legitimate long-lived worktrees — spikes, parallel features — alone. A petal
falling is part of the garden; a dead branch left clinging is not.

## The pit-of-success doctrine

This is the heart of tending, and it is the *harness-is-the-product* thesis given
a seat at the table. The Gardener does not just remove what is dead — it builds
the walls and the sightlines that make the next walk roll toward the scene on its
own. **The harness is the enforced residue of every gap closed hard enough to
never reopen.**

There are **three promotions**, and all are triggered by **RECURRENCE, not
prophecy**. A thing graduates because it *kept happening*, not because someone
predicts it will. If you find yourself promoting against a forecast rather than a
pattern of repeat violations, stop — that is the front-loaded hunter, building
fences nobody is walking into.

1. **A felt principle that keeps getting violated → a hard wall.** A norm that has
   lived only in the prose of the scene, and that the work keeps drifting across,
   graduates into something the harness *enforces*: a compiler reject, a gate, a
   pinned test. The principle stops depending on anyone remembering it. It is now
   load-bearing structure.
2. **A manual high-friction loop → an engineered organ.** A step the two of you
   keep doing by hand — the same dance, every run — graduates into a tool, a
   script, an injected piece of context that does it for you. The willpower it
   cost stops being spent.
3. **A recurring slice-*shape* → a replayable challenge.** When you notice you
   keep bespoke-commissioning the same *kind* of work — a new synth, a new world
   model, a new scenario — that recurrence has earned a **standing generator**. It
   graduates into a sealed, replayable brief (`challenge.md`) that re-grounds
   itself and grows a catalog, so the next instance is a *replay*, not a fresh
   derivation. Tending the generators — creating one, or **tuning** one (higher
   leverage, because it improves every downstream replay at once) — is the
   Gardener's work one level up. A challenge brief is a slow-clock object, governed
   like `SCENE.md`: write-rarely, deliberate, logged.

**Aim the slope at the scene, not the pass-count.** The pit-of-success machinery
is amoral — it rolls work toward whatever the harness rewards. If you point the
gradient at a proxy metric, you get the proxy and lose the garden. Point it at the
ideal scene and the ideal user every time. **Three real bugs beat one
mass-unblock**: a wall that turns a cluster green by erasing what the tests were
guarding is the slope aimed at the count, not the scene — exactly the move the
doctrine exists to refuse.

Walls are hedges and engineered organs are clear paths — both serve *invitation*,
not coercion. Build the one that makes the right move effortless; never the one
that merely punishes the wrong one.

## Reshape the beds — the Gardener mutates the scene

Pruning and promotion both assume the scene is right and the work drifted from it.
But there is a **second flavour of rejection**, and it is the Gardener's alone to
act on: **scout work that was faithfully executed — the commission was clean, the
contestant did exactly what it was asked — and it *still* felt wrong** when it
landed back on the walk. That is not a bug in the work. That is the bed itself
being shaped wrong.

When that happens the Gardener **mutates the scene** — reshapes the beds in
`SCENE.md` (repo root). The scene is slow and sticky; you say no to slices all the
time and to the scene only rarely. But "we built the thing we asked for and it
still fights the feeling" is exactly the rare signal that earns a scene edit.
Record it in the scene's light tending log (last-mutated, by which loop) so the
slow clock stays visible — that is tenet 4 applied to the scene itself.

This is the one place the sealed shell would have hidden the problem. A subagent,
served only the content and never the wander, **cannot** notice "this fights the
scene" — it has no altitude to. The check on a misframed bed was never the scout;
it is the two arbiters, back on the walk, judging what came back. The mutation
lives with the walkers by design.

## Tend the hub

The hub (the existing scene, rendered — see `ARBITER_DRIVEN_DEVELOPMENT.md`) is
a garden bed like any other, and tending it is a standing Gardener verb: when a
run grows a new organ or declares a new invariant, it earns a tile; when a
feedback loop closes, the hub is where it becomes visible; when a tile's
underlying state source dies, the tile is pruned, not left rendering a ghost.
The hub's honesty contract (computed-only, provenance, visible freshness) is
enforced here too — a hand-patched tile found during tending is a corrupted
instrument to fix at its source, never a shortcut to keep.

## Tend the instruments

The world-model regime is a garden bed with its own tending verbs (the
practice lives in the `arbiters-worldmodel` skill; this is the Gardener's
slice of it):

- **Check the ecology first** — before tending instruments, ask whether the
  repo is even in world-modeling *form*. Run `wm top`/`wm tree` here: is there a
  governed shape at all (a `wm/` adapter or `models/*`), or does the regime read
  as ungoverned / entirely **dark**? A repo with an ideal scene but no governed
  shape is a garden with nothing watching it — the tending act is then to
  *install the regime* (the `arbiters-worldmodel` skill's install recipe:
  faucets → governed shape → probes → spin), not to tend instruments that don't
  exist yet. The cheapest world-modeling failure is a beautiful scene over soil
  that was never prepared.
- **Re-drink** standing instruments on data that arrived since last tended,
  under the consumption ratchet — a missed surprise found here becomes a
  replay-tune, logged in the provenance ledger.
- **Promote** probes whose numbers have started wanting alarms into full
  instruments — and refuse the ceremony for numbers nobody acts on.
- **Prune** honestly: a faucet that ran dry is a dead instrument wearing a
  green badge; an instrument whose domain died renders a ghost. Tear down or
  fix the source — never leave a quiet tile whose silence means nothing.
- **Hone the larval prose** in the `arbiters-worldmodel` skill itself —
  graduate lines that earned encoding into briefs, contracts, or tool help,
  and delete them from the prose.

## The standing question — tenet 4

Every retrospective asks it, out loud, every time: **what friction did we
tolerate, and what state stayed invisible?** Low friction and high transparency
are co-equal with shipping the slice, not a nicety bolted on after. The harness is
engineered so that staying oriented costs no willpower and the true state is
unavoidable — and the only way it gets there is by this question catching, each
loop, the willpower-tax and the blind spot you quietly absorbed this run. A
friction you tolerated without naming is next loop's invisible drag; name it here
or promote it (organ or wall) so it stops recurring.

## Then hand off

Tending done, the walk closes with the grep-able sign-off (Phase 7) and the next
fresh session greps it back as its first step. The garden is never finished — you
have tended this bed, and the next walk will find it a little different. That is
the point.
