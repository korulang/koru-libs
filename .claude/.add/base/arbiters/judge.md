# Judge + merge — read what came back, on the walk

This is phase 5 of the walk: the contestants have returned from their worktrees,
and you and the human are back on the path with their diffs in hand. **Judging
happens on the walk.** The contestants ran off blind, did the legwork, and came
back to report; the verdict on what they brought is the two arbiters' to render,
together, never a thing you rubber-stamp alone and never a thing the contestant
renders on itself. A sealed shell cannot grade its own commission — it had no
altitude to notice the brief was wrong, so the check on a bad commission was
never the subagent and isn't now. It is the two arbiters, back on the walk,
judging what came back.

So the first move when a contestant reports is not to read its summary and
believe it — it is to **verify its claims yourself.** Treat the writeup as
hypothesis (tenet 3 — you measure the existing scene from the actual repo, never
from the artifact's description of itself; a contestant's "looks clean" is the
artifact describing itself). Read the diff. Re-run the build. Re-run the tests it
claims pass. The contestant proved its slice to the depth a sealed shell can; the
breadth and the legality are yours.

## Verify mechanics — read the diff, re-run the work

- **Read the actual diff**, not the summary of it. Open it for the human as you
  walk it — `zed <abs-path>:<line> --add` on the lines you're reasoning about out
  loud, so he sees the code under discussion without hunting for it. Walk the one
  you're *talking about now*; don't auto-open all twelve files of a sweep.
- **Re-run the build and the tests the contestant claims green.** A claim of
  passing tests is not a passing test until you've watched them pass on the
  merged shape. This is tenet 3 applied at the seam: a corrupted instrument makes
  every downstream move blind, and "the contestant said so" is the corrupted
  instrument.
- Weigh the outcome it returned on its own terms. A **Frontier** — a clean
  failing test pinning a gap it refused to fake-close — is a real result, not a
  loss; a clean frontier beats a forced green. A **Breakthrough** — a deeper
  change it made in-worktree and proposes for review — is a design question back
  to the walk, not an auto-merge. A **Bridge** is the clean win. None of the
  three merges on the contestant's say-so alone.

## Verify legality — re-run the 2.5 question on the diff

Mechanics are the wrong axis if the intent was forbidden. "The change does what
it intended" says nothing about whether the intent was *allowed* — and this is
the exact gap that once poisoned the compiler for a commit. So before any merge,
**re-run the discriminate question (2.5) on the diff itself:**

- Does this diff make the compiler **accept something an invariant forbids?**
  Does it **loosen a rule** — strip a check, widen a parser, relax a gate — to
  get to green?
- **A green suite proves the change works, not that it is allowed.** In a
  greenfield repo there is no source of truth by design (tenet 1, both ends of
  the gap visible); tests and compiler co-evolve, and **a passing test can itself
  encode an illegal premise.** A test going green is not a ratification of the
  shape it exercises.
- So check the diff against the **standard** — `CLAUDE.md` / `AGENTS.md`, the
  project's rulebook — not just against the test runner. The asymmetric truth
  hierarchy is the lens; both faces of it apply here at merge time.

### The asymmetric truth hierarchy at merge (preserve the teeth)

- **A passing test is strong evidence a shape is intended-legal.** Use it to
  block *fabrication*: a diff that makes a new syntactic shape compile must be
  backed by a passing example of that same shape. **If no passing example exists,
  that is a red flag, not a green field** — the merge-time verdict is "this isn't
  ratified, pin or repro," never "it compiles and the suite is green, ship it."
  This is the rule whose absence let `~decide = ~if(...)` — a `~` inside a flow,
  forbidden by the first rule in the handbook — get ranked, commissioned, built,
  and **merged**, because no link in the chain was holding the rulebook and the
  arbiter verified the wrong axis (that the change did what it intended, never
  that the intent was allowed). The merge gate is exactly where that chain
  should have broken.
- **A failing test tells you nothing about *which side* is wrong** — and this
  matters at merge because a contestant may have closed a red cluster by editing
  the tests to match the compiler. That is **conformance**, the mirror of
  fabrication: it forces the *tests* to fit an unratified premise instead of the
  compiler. A diff that turns red to green by editing tests **breaks no rule** —
  which is exactly why a mechanics check and a "find the rule this breaks" check
  both sail right past it. So at merge you ask the design question yourself:
  **does the language actually want the behavior that turned those tests red?**
  That answer belongs to the human (the language designer), not to "the compiler
  commit is newer" or "the compiler is what runs." If the design call is unmade,
  the diff does not merge as a test-conforming green; the move is to surface both
  readings and the design question — the compiler may be the wrong side — and let
  the walk decide which side moves. A confident "the tests were stale, I migrated
  them" is a verdict on a call that wasn't the contestant's to settle; catch it
  here.

A diff you're excited to merge is exactly the one to hand the skeptic's question
before it lands.

## The full sweep is the Arbiter's gate — run once, at turn end

Contestants ran a **targeted subset** by design (phase 4): the named cluster plus
the ranges their change touches, enough to self-check the slice and its obvious
neighbors. **The breadth check was never the contestant's job** — it is yours,
and it runs **once, at the end of the turn, on the merged tree.**

- After you've merged the winner(s), run the full
  `--no-cache --parallel 8` sweep on the working branch. That sweep is the
  Arbiter's gate: it is the only thing that confirms "no new regressions across
  the whole suite," and a contestant's "looks clean" is not a substitute for it.
- `--no-cache` matters because the gate's whole value is trusting the green. A
  cached pass measures yesterday's tree. Run it cold.
- Run it on the **merged** tree, not in a contestant's worktree — worktree
  package-path artifacts (a sibling-repo import that resolves off the real
  checkout but not the worktree) manufacture phantom failures you'd then have to
  hand-disprove. The merged working branch is the real instrument; measure
  there (tenet 3).

## Merge the winners, discard the rest

- **Merge winners from their worktree** to the working branch. Only the diffs
  that cleared both gates — mechanics verified, legality re-checked against the
  standard — and only after the full sweep on the merged tree is green.
- **Discard the rest.** A contestant that lost, or whose premise turned out
  illegal under the 2.5 re-check, or whose Frontier is a pin-not-a-merge, leaves
  nothing behind on the branch. Worktrees auto-clean; the retrospective (phase 6)
  sweeps any that a contestant left locked or dirty.
- Cherry blossom: discarding a built-but-unmerged contestant is petals falling,
  not work lost — the form was tried, judged, abandoned; nothing here is precious.

What merges defines the existing scene the next walk will measure. So the verdict
that lands here is load-bearing twice over: it ships the slice, and it sets the
ground the next gap is sliced against. Render it on the walk, with both arbiters,
having actually read what came back.
