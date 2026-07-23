# COMPONENT_CHALLENGE — grow the vaxis component catalog

A **replayable generator**, not a task and not a backlog. You run it from zero,
it hands back one **reusable widget** plus any walls it hit, and it is never
used up.

**Singular contestant is the default.** One sealed contestant per replay; variance
accumulates across replays, not inside a fleet.

## Purpose — explicit, and it is NOT a prettier todo

This challenge exists for exactly two things:

1. **Grow a pristine catalog of idiomatic vaxis components** — widgets you can
   drop into markup. Context-candy for how koru TUI components are written well.
2. **Stress the component / markup / layout substrate** until something breaks.
   A pinned hole beats a demo that compiled by dodging.

APP_CHALLENGE grows apps. LIFT_CHALLENGE grows C lifts. This generator grows the
**component organ**. Todo *drinks* from the catalog; it is not the goal.

## You are the contestant

You ARE the contestant. Do **not** ask which widget. Read the catalog, pick a
slice nobody has taken, name it in **lowercase kebab**, build it, ship.
Asking negates the design. Lars judges *after* you ship.

## THE BAR — widget boundary (non-negotiable)

A catalog entry is a **named reusable component**, not a mini-app.

**Required:**

1. You declare `koru/vaxis:component(<name>) { … }` for the widget itself.
2. The demo's `app` (or host) **uses it as a tag** in markup —
   `<selection-list …/>`, `<button …/>`, `<text-field …/>` — with props.
3. A reader can point at **one component declaration** and say: that is the
   widget. Selection logic, button press chrome, field buffer — whatever the
   thesis is — lives **inside** that boundary (or in clearly named children
   it owns), not in the top-level `! draw` / `! key` pipeline.

**Disqualified on sight (earned 2026-07-23, first replay):**

- A full-screen demo where `! draw` / `! key` *are* the widget, and `component`
  only names leaf chrome (`list-row`, `title-bar`, …). That is an **app-shaped
  composition**, not a component. Evaporates at the taste-gate even if it
  builds.
- "Composition thesis" without a reusable tag boundary. Nesting and store
  binding are welcome — **as props/children of the named widget**, not as a
  substitute for one.

If the language cannot yet express a real widget boundary for your pick —
**Frontier**: float the wall, pin it, ship nothing fake.

## The charge

Ship **one** ambitious widget as a runnable demo under
`/Users/larsde/src/koru-libs/examples/`, through `koruc` + public `koru/vaxis`.

Aim past comfort: focus, text input, validation, scrolling, selection,
dialogs, reactive props — over another static row of `<text>`.

### Ship shape (zero-friction)

- **File:** `examples/component_<name_with_underscores>.k`
  (`build.zig.zon` `.name` must be a Zig identifier — hyphens fail.
  Component **tags** stay kebab: `component(selection-list)` →
  `<selection-list/>`; the *filename* uses underscores.)
- **Header comment:** thesis in one sentence + any holes floated.
- **Catalog:** one line under Replays in `challenges/component/CATALOG.md`.

Touch `vaxis/index.kz` **only** when you need a new *primitive*. Clean code
rejected → **STOP**, float, pin, no route-around.

### Markup law

Lowercase kebab tags: `<text>`, `<dock>`, `<stack-panel>`, `<my-widget/>`.
Pascal layout tags are dead.

## Variance is the metric

Read `challenges/component/CATALOG.md` and seed `examples/component_*.k`.
Bring something **not already there**. Diverge on kind, state, layout nesting,
interaction — not a second greet.

## Self-ground — never invent

- Koru law: `/Users/larsde/src/koru/tests/regression`
- vaxis: `/Users/larsde/src/koru-libs/vaxis/index.kz` + existing component demos
- Compiler: `/Users/larsde/src/koru` → `zig-out/bin/koruc`
- Do not turn this into an APP increment or a LIFT

## Holes — float and pin, never fix, never route around

~50% chance it's you. Float exact program + error. Pin when real. Stop.

## Done-gates — self-checked before you ship

1. **Widget boundary** — named `component`, used as a markup tag from `app`;
   logic lives inside that boundary (see THE BAR).
2. **`koruc` builds and runs** the demo from `examples/`.
3. **Catalog divergence** — named against seed/replays; not a clone.
4. **Thesis in one sentence** — what *widget* claim this proves.
5. **Walls named or "hit no wall".**
6. **Catalog line appended.**

## The taste-gate — Lars

Objective gates are necessary, not sufficient. "It builds" does not mean it is
a component. Survivors stay; the rest evaporate. Petals falling is the point.

## Slow-clock

Governed like `SCENE.md`. First replay (2026-07-23) produced an app-shaped
demo under a soft "composition thesis" clause — **struck**; THE BAR tightened.
Retune again when the next replay teaches something.

## Zero-friction append

Drop the `.k` file, add one catalog line. No integration tax.
