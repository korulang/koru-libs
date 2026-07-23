# SCENE — koru-libs

> **How to read this file.** This is the garden, not a doc *about* it — reading it
> *is* stepping into the scene. **Read-many, write-rarely.** Two clocks: this scene
> is the **slow, sticky** ideal (where we're going); the `koru-libs-toolchain`
> orientation skill is the **fast, live** existing scene (where we are). **Scouts
> and Contestants get THE BAR below — never this file.** A `/arbiters` walk picks
> one **bed** (sub-scene) and slices the gap between this and the toolchain reality.

## North star (the garden)

**Premium, first-class Koru editions of the C libraries the whole world already
runs on** — the *same* battle-tested libraries (SQLite, libcurl, libpq, zlib, …),
lifted to the absolute standard. Not reimplementations. Not thin FFI. The
definitive version of a library you already trust, made impossible to misuse.

The home for what doesn't belong in the standard library — one step further out,
but held to a *higher* bar than std, not a lower one.

## THE BAR — the excellence quadrifecta (the soul of this project)

Every lift is held to four pillars at once, and **we never skimp on any of them.**
A library that buys one by sacrificing another is not done — the whole craft is
refusing that trade:

1. **Developer experience** — the ergonomics are so clean you forget there's a
   crusty C library underneath. The right thing is the easy thing.
2. **Performance** — at or above hand-written use of the raw C library. The lifting
   happens at compile time, never as a runtime tax.
3. **Correctness** — wrong usage is a *build error*, not a runtime surprise. The
   exemplar: SQLite SQL **prepared and type-checked at compile time** — a typo or a
   wrong binding won't compile.
4. **Resource safety** — leaks and use-after-free are uncompilable. Phantom
   obligations mean the compiler *will not let you forget* to close/finalize/free.
   *(The candidate fourth pillar — fold into Correctness if you'd rather a trifecta;
   kept distinct because phantom-obligation resource safety is koru's signature.)*

This quadrifecta IS the scene. Everything below serves it.

## What crosses the sealed shell — THE BAR, not a persona

The discipline needs one concrete, transmissible anchor to hand a sealed subagent
(a scout/contestant never sees this file). For this project that anchor is **the
bar, not an "ideal user."** A scout is commissioned: *"judge this against the
quadrifecta — does it skimp on DX, performance, correctness, or resource safety?
Does it clear the sqlite3 compile-time-prepared-statement standard?"* The judge
lens is a **demanding developer who knows the raw C original and will notice
instantly if we wasted their time or cost them a single one of the four pillars** —
carried as a *standard*, not a backstory.

## The feeling — what "right" feels like

Using one of these should feel like the library *finally got the treatment it
deserved.* Meticulous. First-class. No rough edges left for the user to discover in
production. The opposite of "good enough wrapper."

## Beds — nested sub-scenes (one garden, many beds)

The garden is the quadrifecta above; each bed is a stretch of it with its own
feeling. A walk **names the bed it's walking**. Standing beds:

- **The triage bed (Scout / brainstorm fuel).** Walk the world's well-known C
  libraries and triage which deserve a lift — high reliance × high footgun-surface
  × clear compile-time-safety win. `ECOSYSTEM.md` is the running roadmap; Scout runs
  grow and re-rank it.
- **The lifting bed.** Take a triaged library and give it the full quadrifecta
  treatment (the sqlite3 compile-time-prep pattern is the exemplar move).
- **The exemplar bed.** Sharpen `sqlite3` and `gzip` into the reference standard
  every new lift is measured against.
- **Per-library beds (nested).** A specific lift in flight — `curl`, `pq`,
  `vaxis`, … — is its own named bed: it inherits the quadrifecta but has its own
  feeling and its own gap. Split one out when a library gets real focus.
- **The component bed.** Grow the vaxis component catalog via
  `COMPONENT_CHALLENGE.md` — Charm Bubbles as craft reference, depth-first max
  polish on the active widget (now **progress**), singular contestant default.
  Sibling organ to LIFT (packages) and to examples' APP_CHALLENGE (apps).

## What it says NO to (rejected on sight)

- **"Thin wrapper / good-enough binding."** A 1:1 FFI passthrough that inherits the
  C footguns is the *anti-goal*. If it doesn't lift all four pillars, it doesn't ship.
- **Reinventing the library.** We wrap and lift proven C; we don't rewrite SQLite.
- **Trading one pillar for another.** Safety bought with performance, performance
  bought with footguns, DX bought with a runtime tax — all forbidden. The point is
  refusing the trade; compile-time lifting is how we get all four.
- **Runtime tax for compile-time-knowable things.**
- **Lower bar because it's "outside std."** Further from the core means *more*
  polish, not less.

## Tending log

- 2026-07-23 · **Charm progress walls 1–3 cleared** — Style fg/bg, grapheme
  printSegment, `progress-bar` meter primitive + `<progress-bar/>` builtin path.
  Proof: `examples/component_progress.k`. Spring animation still deferred.
- 2026-07-23 · **COMPONENT_CHALLENGE → Charm depth-first** — replay 02
  (`progress-bar` text dump) evaporated. Generator is now a Charm Bubbles port
  queue with **max polish before next widget**; active = Charm `progress`
  (fill, runes, %, color blend, width; spring when substrate allows). Known
  wall already in sight: `Style` is boolean-only — no fg/bg yet.
- 2026-07-23 · **COMPONENT_CHALLENGE retuned** — first replay (`selection-list`)
  evaporated at taste-gate: mini-app with leaf chrome, not a reusable markup-tag
  widget. Brief now requires THE BAR (widget boundary). Catalog struck.
- 2026-07-23 · **COMPONENT_CHALLENGE planted** — third organ beside LIFT: grow the
  vaxis component catalog (singular contestant default; retune after test runs).
  Brief: `COMPONENT_CHALLENGE.md`; catalog: `challenges/component/CATALOG.md`.
- 2026-06-29 · **planted** (arbiters-init first walk, dictated by Lars). North star,
  feeling, beds, and the no-list are his words sharpened.
- 2026-06-29 · **reframed** — dropped the "ideal user" persona (felt enterprise-y);
  the sealed-shell anchor is now **THE BAR** (the excellence quadrifecta + sqlite3
  exemplar). Excellence quadrifecta — DX · performance · correctness · resource
  safety, never skimp on any — encoded as the soul. Per-library lifts framed as
  nested beds. NOTE: the seeded `arbiters` skills still say "ideal user" in their
  prose; gardening them to "the bar" is an open follow-on (not yet done).
