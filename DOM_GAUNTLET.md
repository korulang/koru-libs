---
gauntlet: dom
kind: gauntlet
status: open
reference: krausest/js-framework-benchmark (keyed)
control: vanillajs-keyed
rung: 1 (conformance) → 2 (performance)
vehicle: koru/dom — a DOM component library on the koru/vaxis template
opened: 2026-08-07
---

# DOM_GAUNTLET — can a Koru program put rows on a screen, and how many

A gauntlet, not a challenge: **depth against the world.** The bar is somebody
else's, it is published, and it is not ours to move.

## The reference — named, fetchable, comparable

[krausest/js-framework-benchmark](https://github.com/krausest/js-framework-benchmark),
**keyed** division. It is the right reference for three reasons and one of them
is the ruling that got us here:

- **It is a whole app.** Not a library API comparison. Lars ruled out shipping
  Koru modules into someone else's app, so the only admissible comparison is
  *whole program against whole program* — which is exactly what this benchmark
  is, and the only benchmark of its class that is.
- **The operation set is a fixed, mechanical spec.** Create N rows, replace,
  partial-update, select, swap, remove, append, clear. No judgment, no score to
  flatter.
- **The opponents are already on the board.** Vanilla JS, React, Vue, Svelte,
  Solid and the state libraries under them all have published numbers. We never
  run them. We run ourselves and read their column.

**The control is `vanillajs-keyed`**, not a framework. Same discipline as
`tests/benchmarks/005_target_parity` in koru: the interesting number is the
distance to the loop a person would write by hand. The frameworks are in the
table for scale.

## The rung — split, and the split is the leash

**Naming the rung is the only reluctance this door has, so it is named twice.**

### Phase 1 — conformance · RUNG 1 · unattended

The benchmark specifies the **exact DOM** each operation must produce: element
structure, row count, label text, the class on a selected row. A structural
assertion against a golden derived from `vanillajs-keyed` is a **fact**, not a
verdict. No model in the path, reproducible, uncorruptible.

→ **No leash between rounds. Wide fan-out. Exit-on-bar is legitimate.**

This is the entire gauntlet for now, and that is not a hedge — it is the half
that earns the autonomy.

### Phase 2 — performance · RUNG 2 · batch-boundary leash

Timings are mechanical but **noisy**. Statistical closers are rung 2 by the
ladder, and rung 2 walks at batch boundaries.

→ **Returns to Lars at batch boundaries, never round-by-round. Exit only on a
holdout, never on the fitted set.**

**Phase 2 does not open until Phase 1 is green.** A performance number for an
app that renders the wrong DOM measures nothing and does it confidently.

## The floor — stated plainly, because it is unusual

**Koru has never drawn a pixel.** Measured 2026-08-07 across all 348 `.kjs`
files and every `.k` in the koru tree: zero `document.`, zero `querySelector`,
zero `createElement`, zero `innerHTML`. `std/io:print.ln` lowers to a bare
`process.stdout.write` (`src/js_emitter.zig:1463`); `fs.kjs` and `args.kjs`
`require` node.

The JS target today is a **node CLI target**. So the expected calibration
baseline is **0 of N operations**, and that is the honest starting board — not a
failure, the floor.

## The vehicle — koru/dom, on the vaxis template

`koru-libs/vaxis/index.kz` (3652 lines, 30 procs) is the template, and three
things port:

1. **The `run` shape.** One long-running proc owns the terminal for its whole
   body — init → loop emitting effects → deinit — and consumers write effect
   branches, never an outer loop. Swap terminal for document: `! ready` is first
   paint, `! key k when …` becomes `! click e when …`, and `! resize _` is
   already the right event name.
2. **`component` — and it may port nearly free.** `component(greet) { <text>{{
   name:s }}</text> }` is a `[comptime|transform|pre]` tor that synthesizes a
   whole Koru event plus an implementing flow: `{{ name:s }}` becomes the typed
   input shape, `name={{ who:s }}` forwards a parent's prop, and composition
   afterwards is ordinary Koru flow — `if`, `for`, nesting. It runs at Stage C
   and has **no runtime existence and no target**. The only target-bound thing
   about it is that its generated flow calls `write-at`.
3. **Dependency declaration.** vaxis pulls libvaxis via `~std/deps:requires.zig`.
   `koru_std/package.kz:50-102` has `~std/package:requires.npm`, which walks the
   AST *through imports*. Same shape. (Unpinned — no hash, unlike `requires.zig`.
   Note it; do not fix it here.)

## The thesis under test — this is not a benchmark side effect

**vaxis is immediate-mode.** `write-at` then `render()` repaints a cell grid
every frame. A terminal is ~2000 cells, so that is free. The DOM is retained and
this benchmark hands you 10,000 nodes — repainting per frame is precisely what
every JS framework exists to avoid. A naive vaxis-shaped port loses on the exact
operations the benchmark measures.

The proposed answer is the store. `std/store:watch` compiles **into the write
path** — the producer owns the `if`, no runtime registry (koru `690_001`). That
is the mechanism that keeps the *authoring* surface immediate-mode while the
*DOM* updates stay fine-grained: you write as though you repaint, and the
compiler already knows which column changed, so it touches one text node.

React pays for that with a vdom diff. Solid and Svelte pay with a runtime signal
graph. **Koru would pay at compile time.** That is the claim this gauntlet
exists to test, and the benchmark is built to test exactly it.

Supporting measurement, koru `cbdc0750`: with nothing subscribed, the announce
chain was **77% of node runtime** and eliding it was 4.3×. That path is cold and
near-untested — exactly **one** watch test is js-ok (`690_005`) out of 101 in
`690_STORE`.

## RULED 2026-08-07 — how Koru writes HTML

Lars's ruling, and it is the spelling the markup surface is built on.

**Components are capitalized. Everywhere** — declaration, call site, and markup
tag, one spelling throughout. Not capitalized-in-markup-only; there is no second
spelling to reconcile.

So the markup rule is the smallest it can be:

- **Starts with a capital → ours.** Compile it to a call to that component's
  synthesized event.
- **Anything else → passed through untouched.** Not "looked up in a table of
  HTML elements" — genuinely not inspected.

**That second half is the whole reason this rule is better than the alternative,
and it is Lars's observation:** lowercase does not mean "an HTML element", it
means "the rest — not ours". So the compiler never needs to know what HTML *is*.
No element table, no vocabulary to maintain, and SVG, elements added to HTML
later, and third-party custom elements all work without anyone doing anything.

The rejected alternative was a hyphen rule (`<div>` element, `<todo-row>`
component), which required an embedded list of every HTML element name
specifically so the compiler could know that `table` was one — and still
collided on `table`, `progress`, `label`, `select`, `output` and `main`.
Capitalization collides with nothing, because HTML's element names are lowercase
by specification and always will be.

**Verified before building on it (2026-08-07):** a capitalized event name
compiles today with no compiler change. A program that compiles was taken, one
event name and its call sites capitalized, and recompiled clean — the emitted
JavaScript differs on exactly three lines, all of them the identifier. The
capitalization is transparent to the compiler.

The terminal library keeps its own convention for now. The two do not have to
agree; build both, see which reads better, converge later or don't.

## The budget — declared before the first spawn

- **Tonight:** the brief, the ledger, the board, and **one calibration pull**.
  No fleet. ≤3 agent spawns.
- **The run proper:** budgeted in rounds, set at the walk after the calibration
  board is read. Not set here, because the calibration is what tells us what a
  round costs.

A gauntlet without a declared budget is not autonomous, it is unbounded.

## The closer, and how it certifies itself

The closer is a **structural DOM assertion harness**. Its contract:

- It **derives the operation list from the reference itself**, never from a
  recollection of it. Nobody writes the spec down from memory here.
- It renders a verdict per operation: `pass`, `fail`, or **`cant-tell`**.
- It reports its own **`cant-tell` fraction** on every run. That number is the
  honesty check, and it gates the fleet.

**The calibration is a positive control.** Point the closer at
`vanillajs-keyed` — a known-good implementation — before ever pointing it at
Koru. If it cannot certify the reference's own control at ~0% `cant-tell`, the
closer is broken and no round run against it means anything.

Worked precedent, koru's JS-parity map: run one reported **DO NOT TRUST, 29%
unclassified**, hiding three real resolution bugs. Fixed, it self-certified at
**0.3%** and the plan inverted. Had the fleet launched on run one, every
contestant would have built against a lie, in parallel, for a day.

Same discipline as `005_target_parity`'s checksum guard: a check that has never
fired is not a check with a good record, it is a check with no record.

## The board

`dom/board/` — computed only, monotonic, in-tree. Per round: **the bar, the
current number, the delta, and what moved.** Plateau is *computed*, never felt.

A hand-patched number here is a corrupted instrument steering an unsupervised
fleet. Nothing in the board is written by hand, ever.

## The ledger

`dom/LEDGER.md` — one line per exclusion, with a reason.

**A contestant may PROPOSE an exclusion. It may never enact one.** An unratified
exclusion is conformance fraud with better paperwork — the parity-run form of
editing the test to match the compiler. Ratification is Lars's, on the walk.

This is where the human judgment lives at rung 1, and it is the whole reason the
diffs do not need any.

## Exit conditions

- **The bar is met** — on rung 1 this is a real finish. Take it.
- **Plateau** — the closer stopped moving across N rounds. Computable from round
  two, because calibration gave us round one.
- **Budget exhausted** — declared above.
- **The ledger grew faster than the score** — a run producing mostly exclusions
  is discovering the bar was wrong. Worth more than the parity. Stop, walk.

## The standing guard

**The bar is a measure, not a telos.** A `koru/dom` that reached parity while
drifting from the scene loses to one that missed and held it. Beat someone
else's product as your only standard and you have built someone else's product.

What we want from this is not a row in their table. It is the **feature mining**:
every place the app falls out to `|js` is a place the language could not reach,
and that count is the real deliverable. A `koru/dom` that beats React while
being 60% host-JS is a finding we would want to know, and would never learn from
a stopwatch.

**So the headline metric is two numbers, not one:** operations conformant, and
the fraction of the app that escaped to `|js`.
