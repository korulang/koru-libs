---
type: belief
id: frag-a-demo-that-renders-is-not-a-demo-that-works
provenance: raylib boids, 2026-08-04 — shipped as "boids", verified by screenshot, contained no flocking whatsoever. Lars spotted it in one glance: "very controlled and a bunch of stuff arranged on lines"
ts: 2026-08-04
---

# A demo that renders is not a demo that works — pixels verify the pipeline, never the behaviour (belief)

A boids demo was committed after being checked the way everything else here is
checked: build it, run it, capture the screen, look at the image. The window
opened, 160 amber dots appeared on the right background, the frame loop paced
correctly at 60fps. Every one of those observations was true and the demo was
worthless — there was no flocking in it at all.

The scatter used `(s*71) % 620` and `(s*137) % 440`, which lands on a regular
lattice, and the velocities came from `s%7` and `s%5`, which yields 35 distinct
directions. Nothing read anything else. It was a lattice translating.

## Why the check passed

The screenshot answered "did anything draw", and that had been the live question
for the previous hour — the window really had been black, for a real reason
(koru 697_012, a grid write swallowing its chain tail). Having just fixed a
rendering bug, a picture with dots in it read as success.

**The verification matched the last failure rather than the current claim.** The
claim was "boids". The check was "pixels". Those differ by the entire content of
the word.

## What follows

- **Name the behaviour the artifact is supposed to exhibit, then find the
  observation that would distinguish it from the nearest plausible fake.** For a
  flock that is: do sub-groups form, merge, and split over time? Two captures
  seconds apart answer it; one capture cannot, at any resolution.
- **A single frame is a type-check, not a test.** Anything animated needs at
  least two observations separated in time, because every static property of a
  flock is also a property of a lattice.
- **Freshly-fixed bugs distort the bar.** After a hard debugging session the
  first sign of life reads as completion. That is exactly when to state the
  acceptance criterion out loud, because the relief is doing the judging.

## The sibling failure, same day

`koru/concepts/frag-an-instrument-that-edits-the-specimen-fabricates-defects`
records the inverse from the same session: a probe harness silently rewrote its
INPUT, and six compiler bugs were reported that did not exist. Here the input
was fine and the OUTPUT was inspected too shallowly.

Both are the measurement apparatus reporting success about something other than
the claim. Instruments fail on both ends of the pipe, and neither failure
announces itself — the input case produced confident false positives, this one a
confident false negative about the work remaining.

## Open

Whether anything here can be automated. A checksum oracle works for the koru
ECS benchmark because the workload is deterministic and its answer is a number;
a flock has no natural scalar. The nearest cheap instrument is probably a
clustering statistic over two frames — mean nearest-neighbour distance should
FALL as sub-flocks form, where a lattice holds it constant. Not built, and it
may be more apparatus than a demo deserves.
