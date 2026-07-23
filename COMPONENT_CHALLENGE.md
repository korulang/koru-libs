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
2. **Stress the component / markup / layout / style substrate** until something
   breaks. A pinned hole beats a demo that compiled by dodging.

APP_CHALLENGE grows apps. LIFT_CHALLENGE grows C lifts. This generator grows the
**component organ**. Todo *drinks* from the catalog; it is not the goal.

## Reference library — Charm Bubbles (not Ink)

**Ink won adoption, not craft.** This catalog aims past React-in-a-TTY.

The reference surface is [Charm Bubbles](https://github.com/charmbracelet/bubbles)
(progress, spinner, textinput, list, viewport, …) — taste, chrome, behavior.
Port the *look and job* into koru/vaxis Path C (Window values, dock/stack markup,
store-reactive props). Do **not** port Bubble Tea's Model/Update/View ceremony.

## Depth-first polish — finish the current widget before the next

**Do not spray across the queue.** The active Charm target is polished to
**Charm-class max** before the catalog advances.

For the active target that means: filled meter that *looks* finished in a real
TTY — proportional fill, empty/full runes, optional percentage, **color**
(solid and blend/gradient across the bar — Charm's purple→pink fade is the
taste floor), width from the window, spring/animated transitions when the
substrate can express them. A label + `"value / max"` text dump under a Charm
name is **disqualified**, even if the widget boundary is clean.

When the language or vaxis cannot express that bar → **Frontier**: float the
wall, pin a failing koru regression, ship nothing fake. Mom and dad fix the
toolchain; the next replay retries the **same** widget until it clears.

Only then does the queue move.

## Active target (2026-07-23)

**Charm `textarea`** — sole focus until cataloged as Charm-class.
(`table` Bridge cataloged 2026-07-24 — header + pink selected row + `…` cell
truncation + page-aligned scroll.)

Queue (after textarea clears; do not skip ahead):

1. progress ← cataloged
2. spinner ← cataloged
3. textinput ← cataloged
4. list (simple) ← cataloged
5. viewport ← cataloged
6. paginator ← cataloged
7. help ← cataloged
8. table ← cataloged
9. textarea ← **here**
10. timer / stopwatch
11. filepicker

(`key` is non-visual — fold into help later, not a markup widget.)

## You are the contestant

You ARE the contestant. Do **not** ask which widget. The active target is
above. Build **that** widget to the polish bar, or Frontier the wall. Asking
negates the design. Lars judges *after* you ship — in the **gallery**, not a pre-merge taste
gate. Merge briskly; cast out the bad stuff later. Simpler.

## THE BAR — widget boundary (non-negotiable)

A catalog entry is a **named reusable component**, not a mini-app.

**Required:**

1. You declare `koru/vaxis:component(<name>) { … }` for the widget itself
   (Charm progress → `progress` / `progress-bar` — kebab tag).
2. The demo's `app` (or host) **uses it as a tag** in markup with props.
3. A reader can point at **one component declaration** and say: that is the
   widget. Meter chrome, fill math, color — lives **inside** that boundary
   (or clearly named children it owns), not in the top-level `! draw` /
   `! key` pipeline.

**Disqualified on sight:**

- App-shaped demos where `! draw` / `! key` *are* the widget and `component`
  only names leaf chrome (earned 2026-07-23, replay 01 `selection-list`).
- Charm **name** without Charm **craft** (earned 2026-07-23, replay 02
  `progress-bar` — boundary clean, meter absent; evaporated).

If the language cannot yet express a real widget boundary **or** the polish
bar for the active target — **Frontier**: float, pin, ship nothing fake.

## The charge

Ship the **active** Charm widget as a runnable demo under
`/Users/larsde/src/koru-libs/examples/`, through `koruc` + public `koru/vaxis`,
at the polish bar above.

### Ship shape (zero-friction)

- **File:** `examples/component_<name_with_underscores>.k`
  (`build.zig.zon` `.name` must be a Zig identifier — hyphens fail.
  Component **tags** stay kebab; the *filename* uses underscores.)
- **Header comment:** thesis in one sentence + any holes floated.
- **Catalog:** one line under Replays in `challenges/component/CATALOG.md`
  only when polish clears — not for Frontier scraps.

Touch `vaxis/index.kz` **only** when you need a new *primitive*. Clean code
rejected → **STOP**, float, pin, no route-around.

### Markup law

Lowercase kebab tags: `<text>`, `<dock>`, `<stack-panel>`, `<progress/>`.
Pascal layout tags are dead.

## Variance is the metric

Across *finished* catalog entries, diverge. While a target is active, replays
retry **that** target until it clears — depth, not novelty for its own sake.

## Self-ground — never invent

- Koru law: `/Users/larsde/src/koru/tests/regression`
- vaxis: `/Users/larsde/src/koru-libs/vaxis/index.kz` + existing component demos
- Charm reference: https://github.com/charmbracelet/bubbles (esp. `progress/`)
- Compiler: `/Users/larsde/src/koru` → `zig-out/bin/koruc`
- Do not turn this into an APP increment or a LIFT

## Holes — float and pin, never fix, never route around

~50% chance it's you. Float exact program + error. Pin when real. Stop.
Mom and dad own toolchain fixes between replays.

## Done-gates — self-checked before you ship

1. **Widget boundary** — named `component`, used as a markup tag from `app`.
2. **Charm-class polish** for the active target (see Depth-first polish).
3. **`koruc` builds and runs** the demo from `examples/` on a real TTY.
4. **Thesis in one sentence** — what *widget* claim this proves.
5. **Walls named or "hit no wall".**
6. **Catalog line appended** only if polish cleared.

## The taste-gate — Lars

Objective gates are necessary, not sufficient. "It builds" does not mean it is
Charm-class. Survivors stay; the rest evaporate. Petals falling is the point.

## Slow-clock

Governed like `SCENE.md`.

- 2026-07-23 · replay 01 evaporated (app-shaped); THE BAR = widget boundary.
- 2026-07-23 · replay 02 evaporated (Charm name, no meter); generator retuned
  to **Charm port queue + depth-first max polish**; active was **progress**.
- 2026-07-23 · **progress-bar Bridge cataloged** — Charm static meter (blend +
  `%`). Active advances to **spinner**. Spring deferred (needs ticks).
- 2026-07-23 · **spinner Bridge cataloged** — MiniDot + `! tick` ms + purple.
  Active advances to **textinput**.
- 2026-07-23 · **text-input Bridge cataloged** — prompt, placeholder, blink
  block cursor, scroll; append-char/pop-char. Active advances to **list**.
- 2026-07-23 · **list Bridge cataloged** (replay 07, glm probe) — bubbles/list
  simple delegate: title + paginated rows + ● ○ paginator, page-aligned
  scroll, "> " cursor + pink selected row. Items are a newline `string`
  payload (same path as text-input). Active advances to **viewport**.
- 2026-07-23 · **viewport Bridge cataloged** (replay 08, hy3) — visible-slice
  scroll window, host-owned offset, hard-clip, chromeless (pager chrome is
  host markup). Walls floated: arrows unreachable (0x3000 key filter vs kitty
  PUA); host can't see win height (max scroll = count-1, not count-height).
  Active advances to **paginator**.
- 2026-07-23 · **paginator Bridge cataloged** (replay 09, hy3) — standalone
  Dots + Arabic status chrome; host owns page/total; h/l navigate. Active
  advances to **help**.
- 2026-07-24 · **help Bridge cataloged** (replay 10, hy3) — bubbles/help:
  width-aware SHORT help (` • ` join, `…` truncation SHOWN at 100 & 46 cols)
  + column-aligned single-column FULL help; `?` toggles via host-store `mode`
  int; muted-key/soft-desc/dim-sep Charm palette; bottom-anchored. Bindings as
  a `key:desc`-per-line `string` payload. Holes floated: structured `[]Binding`
  + separate short/full lists + multi-column full help deferred (flat payload
  can't express column groups); rune width = 1 col/codepoint (wide CJK edge).
  Active advances to **table**.
- 2026-07-24 · **table Bridge cataloged** (replay 11, hy3) — bubbles/table:
  fixed-width columns (Padding(0,1)), bold header + dim `─` underline
  (BorderBottom), whole-row bold + pink `#EE6FF8` selected (DefaultStyles
  Selected = lipgloss "212"), `…` cell truncation (ansi.Truncate), page-aligned
  scroll keeps the cursor visible; host store owns cursor, j/k/g/G mutate.
  Holes floated: widget-owned scroll state (bubbles' smooth offset viewport)
  inexpressible on the stateless prop rail; typed `[]Column`/`[]Row` payload
  deferred. Active advances to **textarea**.

## Zero-friction append

Drop the `.k` file, add one catalog line. No integration tax.
