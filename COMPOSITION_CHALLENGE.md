# COMPOSITION_CHALLENGE — prove the catalog composes

A **replayable generator**, not a task and not a backlog. You run it from zero,
it hands back one **composed surface** that *uses* cleared COMPONENT tags — plus
any walls it hit — and it is never used up.

**Singular contestant is the default.** One sealed contestant per replay; variance
accumulates across replays, not inside a fleet.

## Purpose — explicit, and it is NOT another leaf widget

COMPONENT_CHALLENGE grew the leaf catalog (progress → filepicker). This generator
asks the harder question: **do those tags actually hold when wired together?**

Exactly two jobs:

1. **Grow a catalog of idiomatic compositions** — dock/stack surfaces where
   cleared `<tag/>`s share host state and still look Charm-class.
2. **Stress nesting, prop plumbing, focus/keys, and tick coalescing** until
   something breaks. A pinned hole beats a demo that reimplements a leaf in
   `! draw` to dodge the seam.

APP_CHALLENGE grows apps. LIFT_CHALLENGE grows C lifts. COMPONENT grows **leaves**.
This generator grows the **composition organ** — the proof the leaf catalog was
worth building.

## Reference — Charm *assemblies*, not new Bubbles ports

Do **not** invent a twelfth leaf. Reference how Charm apps *assemble* bubbles
(pager = viewport + paginator chrome; list + help; form = inputs + status).
Port the *assembly job* into koru/vaxis Path C: Window values, dock/stack markup,
store-reactive props. Leaves come from `challenges/component/CATALOG.md` Replays
only.

## Depth-first polish — finish the active composition before the next

**Do not spray across the queue.** The active composition is polished until it
*reads as one surface* on a real TTY — shared state honest, chrome coherent,
navigation obvious — before the catalog advances.

When the language or vaxis cannot express that bar → **Frontier**: float the
wall, pin when real, ship nothing fake. Mom and dad fix the toolchain; the next
replay retries the **same** composition until it clears.

Only then does the queue move.

## Active target (2026-07-24)

**`menu`** — compose catalog **`list`** + **`help`** into one surface.
(`pager` Bridge cataloged 2026-07-24 — viewport + paginator, one store.)

Queue (after menu clears; do not skip ahead):

1. pager (viewport + paginator) ← cataloged
2. menu (list + help) ← **here**
3. browser (filepicker + help) — or retune after menu teaches

## You are the contestant

You ARE the contestant. Do **not** ask which composition. The active target is
above. Build **that** assembly to the polish bar, or Frontier the wall. Asking
negates the design. Lars judges *after* you ship — in the **gallery**, not a
pre-merge taste gate. Merge briskly; cast out the bad stuff later. Simpler.

## THE BAR — composition boundary (non-negotiable)

A catalog entry is a **composed surface that drinks from leaves**, not a new
leaf and not a mini-app that paints everything itself.

**Required:**

1. The demo uses **at least two** cataloged COMPONENT tags as markup tags
   (`<viewport/>`, `<paginator/>`, …) — the real builtins / components from
   `examples/component_*.k` Replays. No reimplementing their paint in `! draw`.
2. A reader can point at a **named composition** — either
   `koru/vaxis:component(<name>) { … }` whose markup *nests* those tags, or a
   thin `app` dock that is obviously the assembly — and say: that is the
   composition. Shared store fields drive more than one leaf.
3. Host `! key` / `! tick` mutate store; **leaf widgets own their chrome/paint**.

**Disqualified on sight:**

- Reimplementing a cleared leaf's job in `! draw` / `write-at` / a new zig
  primitive "because wiring was hard" (earned instinct from COMPONENT replay 01).
- A single leaf with extra host chrome and a composition name (not assembly).
- Inventing a new Charm leaf instead of composing (that's COMPONENT's job).
- APP-shaped todo / full app — wrong organ.

If the language cannot yet express a real composition **or** the polish bar —
**Frontier**: float, pin, ship nothing fake.

## The charge

Ship the **active** composition as a runnable demo under
`/Users/larsde/src/koru-libs/examples/`, through `koruc` + public `koru/vaxis`,
at the polish bar above.

### Ship shape (zero-friction)

- **File:** `examples/composition_<name_with_underscores>.k`
  (`build.zig.zon` `.name` must be a Zig identifier — hyphens fail.
  Composition **tags** stay kebab; the *filename* uses underscores.)
- **Header comment:** thesis in one sentence + any holes floated.
- **Catalog:** one line under Replays in `challenges/composition/CATALOG.md`
  only when polish clears — not for Frontier scraps.

Touch `vaxis/index.kz` **only** when a *composition primitive* is truly missing
(almost never — prefer wiring leaves). Clean code rejected → **STOP**, float,
pin, no route-around.

### Markup law

Lowercase kebab tags. Leaves stay the catalog names. Nest them in `<dock>` /
`<stack-panel>` like the gallery and COMPONENT demos already do.

## Known substrate (read before you invent)

- Bare `! tick` installs alone — later `when` ticks drop (timer gallery hole).
  All tick arms `when`-guarded, or one coalesced store.
- Arrow keys may be unreachable (`codepoint > 0x3000`) — use `h`/`l`/`j`/`k`.
- Host often can't see `win` height — page-aligned / count-1 clamps OK; float
  honestly if the pager needs count-height.
- Nested `if | else |> if` page dispatch is ugly — prefer a single composition
  component; `cond` cleanup is mom/dad later, not your dodge.

## Variance is the metric

Across *finished* catalog entries, diverge. While a target is active, replays
retry **that** target until it clears — depth, not novelty for its own sake.

## Self-ground — never invent

- Koru law: `/Users/larsde/src/koru/tests/regression` (read via worktree rules)
- Leaves: `challenges/component/CATALOG.md` + `examples/component_*.k`
- vaxis: worktree `vaxis/index.kz` only
- Compiler: `/Users/larsde/src/koru/zig-out/bin/koruc`
- Do not turn this into APP, LIFT, or a new COMPONENT leaf

## Holes — float and pin, never fix, never route around

~50% chance it's you. Float exact program + error. Pin when real. Stop.
Mom and dad own toolchain fixes between replays.

## Done-gates — self-checked before you ship

1. **Composition boundary** — ≥2 catalog leaves used as tags; assembly named.
2. **Shared-state polish** for the active target (pager: page drives content + chrome).
3. **`koruc` builds** the demo from `examples/` (compile-prove; real TTY for humans).
4. **Thesis in one sentence** — what *composition* claim this proves.
5. **Walls named or "hit no wall".**
6. **Catalog line appended** only if polish cleared.

## The taste-gate — Lars

Objective gates are necessary, not sufficient. "It builds" does not mean the
assembly holds. Survivors stay; the rest evaporate. Petals falling is the point.

## Slow-clock

Governed like `SCENE.md`.

- 2026-07-24 · **planted** — COMPONENT leaf queue exhausted; composition organ
  stands up. Active = **pager** (viewport + paginator).

- 2026-07-24 · **pager Bridge cataloged** (replay 01, hy3) — named `pager`
  nests `<viewport/>` + dual `<paginator/>`; page+offset one stored mutation.
  Active advances to **menu**.

## Zero-friction append

Drop the `.k` file, add one catalog line. No integration tax.
