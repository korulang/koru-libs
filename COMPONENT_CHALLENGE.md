# COMPONENT_CHALLENGE — grow the vaxis component catalog

A **replayable generator**, not a task and not a backlog. You run it from zero,
it hands back one widget (or one composition thesis) plus any walls it hit, and
it is never used up.

**Singular contestant is the default.** One sealed contestant per replay; variance
accumulates across replays, not inside a fleet. Retune after a couple of runs if
the generator wants a different shape.

## Purpose — explicit, and it is NOT a prettier todo

Read this first. This challenge exists for exactly two things:

1. **Grow a pristine catalog of idiomatic vaxis components** — context-candy for
   how koru TUI markup is *actually* written well. Every surviving line is
   exemplary.
2. **Stress the component / markup / layout substrate** until something breaks.
   A well-characterized, pinned hole is worth more than a widget that compiled
   by dodging.

We are **not** building a complete widget toolkit in one replay, and we are **not**
polishing `todo_tui` as the goal. Todo (and future apps) *drink* from this catalog;
APP_CHALLENGE grows apps. This generator grows the **component organ**.

## You are the contestant

You ARE the contestant. Do **not** ask which widget, which layout, which direction.
Read the catalog, pick a slice nobody has taken, name it in **lowercase kebab**
(markup tags match event names — `<button>`, `<text-field>`, `<checkbox>`), build
it, ship. A replay that pauses to ask has negated its own design.

Variance across contestants is the point. Your choice IS the contribution. Lars
judges *after* you ship, by reading and running. Not before. Not during.

## The charge

Ship **one** ambitious, idiomatic component (or one tight composition of a few)
as a **runnable** demo under `/Users/larsde/src/koru-libs/examples/`, through the
real toolchain (`koruc` + public `koru/vaxis`), that either:

- proves a **new widget kind** the catalog does not already have, or
- proves a **new composition thesis** (how widgets nest, share state, take focus,
  bind to `std/store`, live inside `<dock>` / `<stack-panel>`, …)

Aim past comfort. Prefer the widget that forces a hard surface — focus, text
input, validation, scrolling, selection, dialogs, reactive props — over another
static row of `<text>`.

### Ship shape (zero-friction)

- **Default:** `examples/component_<kebab-name>.k` — self-contained, `koruc run`
  from `examples/` (same wiring as existing `component_*.k`).
- **Optional:** a short header comment naming the thesis and any holes floated.
- **Catalog:** one line in `challenges/component/CATALOG.md`.

Prefer declaring the widget with `koru/vaxis:component(…)` + markup in the demo.
Touch `vaxis/index.kz` **only** when the widget needs a new *primitive* (a new
layout tag, a new event). If clean idiomatic code is rejected — **STOP**, float
the wall, pin a koru regression, do not route around in the demo.

### Markup law

Tags are **lowercase kebab**, matching event and component names:
`<text>`, `<dock>`, `<stack-panel>`, `<todo-row/>`. Pascal layout tags are dead.

## Variance is the metric

Before building, **read the catalog** (`challenges/component/CATALOG.md`) and the
existing `examples/component_*.k` demos. Bring something *not already there*.

Diverge on axes that matter:

- **kind** — display, input, chrome, feedback, collection, overlay…
- **state** — pure props vs `std/store` vs ephemeral draft buffer
- **layout** — alone, inside `<dock>`, inside `<stack-panel>`, live fill + sweep
- **interaction** — keys, focus, validation, empty/full arms

Do **not** ship a second greet / another static three-line stack. That is noise.

## Self-ground — never invent

- **Koru syntax** — `/Users/larsde/src/koru/tests/regression` is law. Read a
  passing test before using a construct, or label it a guess.
- **vaxis public surface** — `/Users/larsde/src/koru-libs/vaxis/index.kz` and the
  existing component examples.
- **Compiler** — `/Users/larsde/src/koru` (`zig build` → `zig-out/bin/koruc`).
- **Sibling challenges** — APP_CHALLENGE (koru-examples) grows apps; LIFT_CHALLENGE
  (this repo) grows C lifts. Do not turn a component replay into an app increment
  or a new package lift.

## Holes — float and pin, never fix, never route around

On a suspected hole, assume ~50% chance it's your own misunderstanding. **Float
it**: exact program, koru-level error (or raw-host leak), "this might be me."
**Pin** a failing koru regression when the wall is real. Then stop — do **not**
solo-fix the compiler, do **not** dodge in the demo. The pinned hole is a
first-class deliverable.

## Done-gates — self-checked before you ship

1. **`koruc` builds and runs the demo** from `examples/` — no route-around, no
   hand-edited emission. Surviving code is pristine and grounded.
2. **Catalog divergence** — you can name which existing entries you read and why
   yours is not a clone.
3. **Thesis in one sentence** — what composition/widget claim this entry proves.
4. **Walls named or "hit no wall"** — if no wall, you may have aimed too low; say so.
5. **Catalog line appended** — `challenges/component/CATALOG.md`.

## The taste-gate — Lars

Objective gates make the entry releasable-by-construction. The final call —
"yes, that's catalog-worthy" — is Lars's, on the walk. Survivors stay; the rest
evaporate with their worktrees.

## Slow-clock

This brief is governed like `SCENE.md`: read-many, write-rarely. After a couple
of replays, retune if the generator is producing noise or missing an axis.
Tuning improves every future replay at once.

## Zero-friction append

Drop `examples/component_<name>.k`, add one catalog line. No integration tax.
No shared registry to update. The pit of success is the path of least resistance.
