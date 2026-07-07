# Lift challenge

> **To AI agents reading this brief**: you ARE the contestant, not the
> assistant. Do **not** ask the user which library or which direction to
> pick. Do **not** ask if your concept is good enough before you ship.
> Do **not** request clarifications about things this brief leaves to
> your judgment — they are left to your judgment on purpose. Choose a
> target, name it, write code, ship. If you catch yourself drafting a
> message like "which of these would you like me to build?" — stop,
> delete it, and pick one yourself.
>
> The helpful-assistant instinct to confirm direction is the **wrong
> reflex** for this brief. Asking negates the experimental design.
> **Variance across contestants is the point. Your choice IS the
> contribution.** The user judges *after* you ship, by reading and
> running. Not before. Not during.

Lift a battle-tested C library into a premium, first-class Koru edition —
or take an existing lift in this repo and close its worst gap. The catalog
is the set of `@korulang/*` packages in this repo; each replay of this
brief grows it in breadth (a new lift) or depth (a quality pass). We need
all of it: bread-and-butter libraries the whole world runs on, sharpened
exemplars, and quality passes that make an existing lift impossible to
misuse. This brief is replayed from zero, forever; it is never "done."

## Two entry types

1. **New lift** — pick a proven C library not yet in the catalog
   (`ECOSYSTEM.md` is the triage shelf: high reliance × high
   footgun-surface × clear compile-time-safety win). Ship a **scoped v0**:
   the core API, quadrifecta-clean. Narrow and deep beats wide and thin —
   a thin wrapper over the full API surface is the anti-goal; five
   entry-points that are impossible to misuse are a lift.
2. **Quality pass** — pick an existing package and close its single worst
   pillar gap: a footgun made uncompilable, a runtime check moved to
   compile time, an API made unmisusable, stale idioms migrated to the
   current language. One complete move, not a grab-bag.

## THE BAR — four pillars, never skimp on any (the non-negotiable of

non-negotiables)

Every entry is held to all four pillars at once. An entry that buys one
pillar by sacrificing another does not ship — the whole craft is refusing
that trade:

1. **Developer experience** — ergonomics so clean you forget there's a
   crusty C library underneath. The right thing is the easy thing.
2. **Performance** — at or above hand-written use of the raw C library.
   The lifting happens at compile time, never as a runtime tax.
3. **Correctness** — wrong usage is a *build error*, not a runtime
   surprise.
4. **Resource safety** — leaks, use-after-free, and double-free are
   uncompilable, and a resource cannot be *prematurely finalized*: an
   obligation must be dischargeable only from a state that real work
   reaches, never straight from `init`. (This is the RAII/Drop blind spot —
   cleanup is guaranteed to *run*, but the resource is never forced to be
   *used*; `init → finish` with nothing in between must NOT compile.)
   Phantom obligations mean the compiler *will not let you forget* to
   close/finalize/free — nor let you finalize something you never used. The
   asymmetric-barrier pattern (`gzip`'s `fed` gate: `finish` requires a
   state only `push` can reach) is the house exemplar.

Judge your own work as a demanding developer who knows the raw C original
intimately and will notice instantly if you wasted their time or cost them
a single pillar.

## Three more non-negotiables

1. **The C library has to actually contribute.** We wrap and lift proven
   C; we never reinvent it. If your package would work identically with
   the C library deleted, it doesn't count. (Reimplementing SQLite in
   Koru is disqualified on sight; so is vendoring the C lib and then not
   calling it.)
2. **Koru's type system has to do the lifting.** Phantom obligations,
   compile-time validation, effect-branches — the lift must be something
   only this language can express. If your wrapper would port unchanged
   to Python or Go, it is a binding, not a lift, and it doesn't count.
3. **Never write syntax you haven't read in a passing test.** The Koru
   test suite (`/Users/larsde/src/koru/tests/`) is the law for what the
   language does — never docs, never analogy, never memory. Before using
   any construct, find it in a passing test. The exemplar package
   (`sqlite3/index.kz`) shows the house style for phantom obligations and
   effect-branch cursors — read it before writing your own.

## If the toolchain rejects your clean code — STOP, report, never route

around

This project sits downstream of the Koru compiler, and both are
greenfield. If code you believe is clean and idiomatic is rejected — or
compiles to broken output — do NOT contort your package to satisfy the
compiler (no scope hacks, no qualified-import workarounds, no "just one
wrapper"). A toolchain defect surfaced by honest library code is a
first-class finding, worth more than a shipped package that hides it.
Pin it (a minimal `.kz` repro), name it in your writeup, and ship what you
can honestly ship around it — with the gap stated, never papered over.
Likewise: a red test tells you something is wrong, not *which side* is
wrong — report both readings; never silently edit a test to match the
compiler.

## Duplicate prevention & variance

The catalog is a curated shelf of definitive editions. Before choosing:

1. **List the packages** — every top-level directory here with an
   `index.kz` is a shipped or in-flight lift.
2. **Read their READMEs** and skim their `tests/` to see what is actually
   covered, not what is claimed.
3. **Read `ECOSYSTEM.md`** — the triage roadmap of candidate libraries
   with their "Koru advantage" notes.
4. **Bring something not already there.** A second HTTP client is a
   duplicate; zlib, libyaml, pcre2, libgit2, a terminal, a crypto lib are
   open shelf space. For quality passes: pick the pillar gap nobody has
   closed, not the one already mid-repair.

Variance across submissions is the single most important metric of
success.

## Submission anatomy

**New lift** — a self-contained top-level package directory:

| File | Purpose |
|---|---|
| `<name>/index.kz` | The public API entry — the lift itself |
| `<name>/tests/*.kz` | Runnable tests; each one compiles and runs end-to-end |
| `<name>/examples/*.kz` | At least one honest example a newcomer can run |
| `<name>/package.json` | `@korulang/<name>`, with `koru.entry` |
| `<name>/README.md` | The writeup (template below) |

Package names are the C library's name, lowercase (`sqlite3`, `curl`,
`pq`) — the identity is "the definitive edition of the thing you already
trust," so the trusted name IS the name.

**Quality pass** — changes inside the existing package directory, plus a
`README.md` section (or `LIFT_NOTES.md` if the README would bloat)
documenting: the pillar gap closed, the before/after, and the proof.

## What "done" looks like (the gates)

1. `koruc --check <name>/index.kz` passes.
   (The compiler binary: `/Users/larsde/src/koru/zig-out/bin/koruc`,
   run from the repo root. Not on PATH.)
2. Every test compiles AND runs end-to-end:
   `koruc run <name>/tests/<test>.kz` — real output, no silent stubs.
   (Verified example: `koruc run sqlite3/tests/basic.kz` →
   `Opened and closed!`)
3. At least one **negative test**: a misuse (forgotten close, wrong-type
   bind, use-after-free, or a resource finalized before it was ever used)
   that FAILS to compile, proving the phantom obligations actually bite. An
   uncompilable footgun you can't demonstrate is a claim, not a lift.
4. No silent fallbacks anywhere — failures fail loudly with the actual
   error.
5. The writeup is filed (template below), including the quadrifecta
   self-audit: one honest paragraph per pillar, gaps stated plainly.
6. Lars reads and runs it, and the verdict is "yeah, that's the
   definitive edition."

Gates 1–5 you self-check. Gate 6 is not yours.

## Writeup template

```markdown
# <name> — the definitive Koru <C library> edition

**One-line pitch**: <what it lifts, in ≤20 words>

**Entry type**: new lift / quality pass on <package>

**Author**: <model name + session identifier, or human name>

## What the C library does, and what we lift

<Two or three sentences: the proven library underneath, and the specific
footguns/ergonomics this edition compiles away.>

## The quadrifecta self-audit

- **DX**: <what the happy path looks like; what a newcomer never has to know>
- **Performance**: <where the lifting happens at compile time; what the runtime cost is vs. raw C — measured or honestly "unmeasured">
- **Correctness**: <what wrong usage no longer compiles; cite your negative test>
- **Resource safety**: <which obligations the compiler enforces; cite file:line>

## What it explicitly doesn't do (yet)

<Scope cuts, honestly. A v0 that names its edges beats a v1 that hides them.>

## Toolchain findings

<Any compiler bug, bad error message, or missing language feature you hit —
with the minimal repro. "None" is a fine answer; a hidden one is not.>

## Proof of life

<The exact koruc commands you ran and their real output, pasted.>
```

## The toolkit

| You need | Where it is |
|---|---|
| The compiler | `/Users/larsde/src/koru/zig-out/bin/koruc` (`--check`, `build`, `run`) |
| The language's law | `/Users/larsde/src/koru/tests/` (passing tests only) |
| Compiler-repo standards | `/Users/larsde/src/koru/CLAUDE.md` — read first |
| The exemplar lift | `sqlite3/index.kz` + `sqlite3/tests/` |
| Compile-time DSL validation precedent | `/Users/larsde/src/koru/koru_std/regex.kz` (analyze + compile-error pattern) |
| The triage shelf | `ECOSYSTEM.md` |
| Package conventions | any shipped package's `package.json` |

## Go (no permission required)

1. Read `/Users/larsde/src/koru/CLAUDE.md` and `ECOSYSTEM.md`.
2. Read `sqlite3/index.kz` — the exemplar's house style.
3. List the package dirs, read their READMEs — dedup.
4. Pick your entry: a new lift from the shelf, or the worst pillar gap
   in an existing package.
5. Build. Ground every construct in a passing koru test.
6. Run the gates. Write the writeup. Stop — don't ask if you should do
   another one. If the user wants another attempt they'll spin up
   another contestant.

---

**Catalog upkeep**: when a lift ships, `ECOSYSTEM.md` gets its status
flipped and this repo gets the package directory — the catalog IS the
repo. When you discover a library worth lifting that isn't on the shelf,
add it to `ECOSYSTEM.md` even if you don't build it. The catalog is the
long-running artifact; individual replays are one slice through it.

*Planted 2026-07-02 on an /arbiters walk (modeled on intranquil's
`SYNTH_CHALLENGE.md`). This brief is a slow-clock artifact — read-many,
write-rarely; tuning it is a Gardener act, logged here.*
