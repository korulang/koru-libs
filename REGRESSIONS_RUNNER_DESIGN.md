# koru/regressions — design brief

> Working design doc for a koru-native verification runner. Not shipped docs — our
> shared scratchpad for the co-design. Delete/move freely.

## What we're building (one paragraph)

A **koru-native verification runner**: a `koru/regressions` library (`.kz`, owns the
`|zig` subprocess primitives) + a per-project `suite.k` (pure koru). It **discovers
standalone koru test programs**, runs each through `koruc` (potentially across
multiple backends), reads each test's **self-described expectations**, scores them,
prints a board, tracks green→red **regressions over time**, and can **fire off
external engines** (mutation / AST-rewrite fuzzing) as jobs. It is a **runner**, like
koru's own regression suite — **not** a DSL that embeds test bodies.

## Architecture — decided

- **Runner, not embedder.** Test bodies stay as their own koru files next to their
  library (`gzip/tests/roundtrip.kz`), exactly like koru's `input.kz`. `suite.k` +
  `koru/regressions` run *over* them.
- **Composed by import, not magic numeric dirs.** koru's `^[0-9]+_` prefix taxonomy is
  replaced by an import graph: add a test = drop a file; add a lib to the suite = one
  import line.
- **Every marker → a typed koru declaration** the compiler checks, so a label *can't
  drift into a lie* (koru's harness has doc-only `EXPECT` labels that lie, + vestigial
  dead markers — we drop all of that).
- **Invocation:** `koruc suite test` (convention-discovery of `suite.k` — Lars fixed
  this in koruc).
- **Tests are self-describing:** a test carries its own expectations *inline*
  (resolved fork, below). The runner stays pure composition.

## Capability requirements (from koru's own harness — the keepers)

Outcome kinds the runner must score:
- compile + run + **exact output** · compile + run + **fuzzy** (substring/regex/NOT)
- **must-not-compile, pinned to stage + exact diagnostic** (the crown jewel — koru's
  4 stages: frontend / backend-compile / backend-runtime; an *unpinned* negative is
  itself a failure — `no-error-pin`)
- **compile-only** (explicit, guarded against the lazy-dodge)
- **AST-structure pin** · **comptime-output pin** (what it prints *during* compilation)

Fixtures: compiler flags · argv · stdin.

Cross-cutting gates: **memory-leak = first-class failure that overrides pass** ·
**cross-backend parity** (`LANGUAGES: zig js` → generalize to N targets) · watchdog
timeout (+ its self-test inversion) · custom-validator escape hatch (→ our fire-off
seam).

Lifecycle/triage: skip (reasoned) · todo (off the denominator) · broken (the *test*
is wrong) · benchmark (excluded from scoring) · priority (auto-cleared on pass) ·
**category-level markers cascade to children** (→ module-level declarations in the
import model).

Runner: discovery · selection (id/cluster/pattern/smoke) · **parallel** · fingerprint
**result cache** + backend-binary cache · **snapshots → history → diff → regression
detection with exit-1** (the thing that keeps the koru repo alive — non-negotiable) ·
board with staleness detection.

## Prior-art steal-list (consolidated, ranked)

### Compile-fail pinning (Rust/Clang/Swift/GCC/Zig/Carbon)
1. **Inline annotation on the offending line, substring match** — near-universal
   convergence; puts the assertion where the eye is, survives prose polish.
2. **Named/symbolic line markers, NOT positional offsets** — Swift `#name` / `@#name`.
   *Structurally required for koru*: obligation errors reference multiple lines
   ("opened here" + "consumed there" + "not discharged"). Offsets (`//~^^^`) rot.
3. **Diagnostic-ID pinning** — assert `KORU030`, not the message prose. Decouples the
   suite from error-message tuning (which will happen constantly per the
   pit-of-success doctrine). Message-substring optional secondary.
4. **Autoupdate with inline placement** — Carbon's `--autoupdate`: machine-writes the
   expectation lines back *next to the source*, diff-reviewed like any golden. Beats
   Rust's two-file inline+`.stderr` system for a fresh design.
5. **`expected-no-diagnostics`** — explicit "must compile clean," distinct from
   "nobody wrote a check."
6. **First-class "known bug, still pinned"** — GCC `dg-bogus`+xfail / Rust
   `known-bug`. Maps exactly to our "pin bugs as failing tests first."
7. CHECK-DAG (unordered) + CHECK-COUNT for cascading diagnostics · capture vars
   (`[[VAR]]`) for cross-diagnostic identity ("same obligation id leaked here as
   opened there").

### Golden ergonomics (ppx_expect/insta/Jest/turnt)
- **Inline expect + one-command promote** (ppx_expect `dune promote`) — expectation
  lives next to the code; `git diff` on promote *is* the review UI.
- **Interactive per-item accept/reject/skip** (insta review) as the default — NOT
  blanket `-u` (the rubber-stamp anti-pattern).
- **Redaction / fuzzy matchers** for nondeterministic output (glob/regex per line).
- **Obsolete-golden detection** as a surfaced category · **CI blocks new goldens**
  (forces promotion through local review).
- turnt's principle: *cheap test addition over precise assertion* — full-output
  capture + code review does the precision (matches "the test costs five minutes").

### Programmability (pytest/property/Go/RSpec/Bazel)
- **Fixtures = ordinary functions returning values** (pytest's power, minus stringly
  lookup — imports make "where's this from" answerable).
- **Tables = array literal + loop** (Go proves you don't need bespoke table grammar).
- **Shared contracts = higher-order functions you import** (RSpec's power, one
  primitive not two).
- **Suite caching = hash the transitive import closure** (Bazel-style, free from
  koru's import graph).
- **Collection-time generation**: run a test module once (cheap, side-effect-free) to
  enumerate the case set, *then* shard/parallelize.

### Property / differential — the headline
- Generator + **shrinker** as a runner service (proptest's composable-values model,
  not QuickCheck's per-type typeclass).
- **Stateful rule-machine** generating+shrinking a *sequence of calls* → in koru this
  is a resource-safe program over obligation-typed **handle pools** (the
  `openssl-write-blk` work). Prints a minimal failing *program*.
- **Cross-backend differential property testing**: same koru program on
  {zig, js, **GPU/MLIR**}, property-generated inputs, assert all backends agree,
  shrink on divergence. `LANGUAGES: zig js` is the seed. **Nobody has this.**

### Type-level + docs
- `expect_type` / `^?`-query answered by **koru's own checker** (can't drift; twoslash
  insight) — same promote machinery as value-expects, one DSL not a bolted-on tool.
- Doctests: executable README examples (docs can't rot) — cheap once inline-expect
  exists.

## The leapfrog thesis (why "install koru for the tests")

Every framework picks one axis: lit/FileCheck nails compiler-output pinning but is a
dumb text format; pytest nails programmability but only at runtime; tsd nails
type-assertions bolted onto a structural type system. **koru is the first place all
three collapse into one**, because a test *is* a program in the language:
- compose by import, generate by loop, parametrize by value (pytest's power, native)
- assertions checked by the **type system at compile time** — obligations, staged
  diagnostics (trybuild/tsd's power, native, not a bolted-on macro)
- **cross-backend differential incl. a GPU target** — which *nothing* in the field has

## Resolved fork — where do expectations live?

**(a) In the test file itself, inline** — grounded by the compiler-suite convergence
(Rust/Clang/Swift/GCC/Carbon/Zig all put the expectation in the source). koru-native
form: **named markers + diagnostic-ID pinning + autoupdate**. Test is self-describing;
runner stays pure composition. (Consistent with "runner, not embedder" — inline means
inside the *test program*, never inside the suite spec.)

## Open forks — for co-design (Lars's calls)

1. **The exact inline annotation syntax** — the editor's job. e.g. an obligation
   negative referencing two lines by name + a diagnostic ID. This is the thing to
   sketch.
2. **v1 scope** — which outcome-kinds + which superpowers ship first. Nominated
   headline three: staged must-not-compile · leak-gate · cross-backend parity.
3. **Differential/property + shrinking**: v1 or v2? (Leans v2, but the parity seam
   should exist in v1.)
4. **Fixture scope/caching vocabulary** (once-per-case / module / run).
5. **Naming**: "regression" is one *mode* (the over-time green→red tracking); the
   whole thing is closer to a *verification/conformance runner*.
