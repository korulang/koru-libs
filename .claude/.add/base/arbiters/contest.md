# Phase 4 — Contest (send the contestant off from the walk)

The commission is distilled and the two arbiters have landed their shared
decision (Phase 3). Now the work goes *out*. A contestant is a minion sent off
from the walk to build one slice and report back — it does not join the wander,
it serves it. You and the human keep walking; the legwork fans out.

This is the **sealed shell** made concrete. The contestant gets the *content* of
the bed it is building in — the commission, the substance, the standards — and
**never the process**: not the wander, not the roles, not the promotion
lifecycle, not the Gardener stance, not the right to make any
methodology-level call. The lossy commission and the sealed shell are the same
act named from both ends; the lossiness *is* the sealing. That seal is what
keeps a contestant's judgment fresh on the slice, and it is what makes ADD
non-recursive by construction — the garden stays with the walkers; a contestant
cannot spawn its own walk.

## Spawn with worktree isolation

Spawn the contestant(s) with `isolation: "worktree"` (background it for long
work). Each one gets a clean, isolated checkout so parallel contestants never
collide, and so a slice that doesn't merge simply evaporates with its worktree
— petals falling. Pick the model deliberately (the spine's model-tiering rule):
top model when the slice lands in the product; mid-tier for throwaway probes
and scaffolding. Hand each contestant **only the commission**: the distilled
target, value, non-negotiables, forcing-function framing, and the orientation
pointer. Do **not** pour in the deliberation, the other findings, or the
reasoning that picked this seam over its neighbors. That context is the wander;
it stays on the walk.

**Every contestant is served the standards first.** Sealed from the process is
not sealed from the rules. The contestant's prompt must instruct it to read the
repo-root standards before it does anything else (for Koru: `CLAUDE.md` and
`AGENTS.md`; a seeded project records its own canonical paths) and to treat the
**Language Truth Hierarchy** as binding — a passing test is strong evidence a
shape is intended-legal; the absence of one is a red flag, not a green field.

## Three valid outcomes — a clean frontier beats a forced green

A contestant has three honest ways to come back. None of them is failure.

- **Bridge** — it works cleanly. The slice closed the gap with the change it was
  commissioned to make. A coverage or feature win, ready for Judge.
- **Breakthrough** — closing the gap needed a deeper change than the commission
  named (e.g. a compiler change underneath the surface fix). The contestant makes
  it and **proposes it for review** — flagged as deeper, not smuggled in as if it
  were routine. The arbiters decide at Judge whether that depth is wanted.
- **Frontier** — it hit a wall it could not cleanly close, so it **pinned the gap
  as a failing test** and reported where the edge is. This is a map of the
  boundary, not a defeat. A clean frontier — an honest pinned red — **beats a
  forced green** every time. The cherry blossom falls and the falling is the
  point: red is appreciated here, and a contestant that reports the wall is doing
  the job exactly right. Never brief a contestant to make a red turn green at any
  cost; brief it that pinning the wall is a first-class outcome.

The one thing a contestant must never do is manufacture a green — conform a
failing test to the compiler, or invent syntax to make a forbidden shape
compile, to avoid coming back with a frontier. A sealed shell **cannot catch a
bad commission** and cannot adjudicate which side moves; if its slice runs into
a design question, the honest move is to surface it as a frontier and hand it
back to the walk, never to settle it.

## Run a TARGETED SUBSET, never the full suite

Commission the contestant to run **only** the named cluster plus the test ranges
that exercise the code path it touched (an emitter change → the relevant
`230`/`320`/`330` ranges, and so on) — enough to self-check the slice and its
obvious neighbors. Do **not** commission a full-suite sweep per contestant.

This is not just a speed concern, though a full `--no-cache` sweep is slow even
parallelized and multiplies across a fleet. The deeper reason is **phantom
failures**: a contestant runs in its own worktree, where package-path artifacts
(e.g. a sibling-repo import that resolves off the real checkout but not the
worktree) manufacture failures that have nothing to do with the slice. A
contestant that runs the whole suite will dutifully report those phantoms, and
the Arbiter then has to hand-disprove each one. Keep the contestant on its slice
and its neighbors, where the results are trustworthy.

**Name the project's KNOWN worktree phantoms in every brief** (earned 2026-06-10:
a koru worktree's lib symlink pointed at the main checkout's source and
manufactured 34 false reds; the briefs that pre-named known phantoms got clean
flag-not-chase reports, the discovery cost a contestant a debugging detour).
Keep the project's phantom list in its memory/orientation notes and paste it
into each commission as flag-not-chase items.

**Brief contestants to drive long-running work to completion in-run.** A
subagent's background monitors and task notifications cannot re-fire it after
its run ends — a contestant that launches a sweep and "pauses until the monitor
fires" has silently terminated with the work dangling (this happened twice in
one session). The brief says: foreground waits, generous timeouts, your job
ends only when the result is in hand.

## The breadth check is the Arbiter's job, never the contestant's

The contestant proves its **slice**. Confirming that the merged change introduces
no new regressions across the *whole* suite is the Arbiter's gate, run once on
the merged tree back on the walk (Phase 5 / Judge) — never delegated into a
contestant, never inferred from a contestant's "looks clean." This division is
the sealed shell again: breadth is a whole-garden judgment, and whole-garden
judgments live with the walkers by design. A contestant has no altitude to make
it, and asking it to is how phantom failures get treated as real.

When every contestant has reported — Bridge, Breakthrough, or Frontier — carry
what came back to **Phase 5 — Judge**, where the two arbiters verify the claims,
re-check legality, and run the full sweep.
