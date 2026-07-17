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
   sketch. → **Concrete proposal below (2026-07-17), spiked in the runner.**
2. **v1 scope** — which outcome-kinds + which superpowers ship first. Nominated
   headline three: staged must-not-compile · leak-gate · cross-backend parity.
   → **Proposal below commits to exactly these three.**
3. **Differential/property + shrinking**: v1 or v2? (Leans v2, but the parity seam
   should exist in v1.)
4. **Fixture scope/caching vocabulary** (once-per-case / module / run).
5. **Naming**: "regression" is one *mode* (the over-time green→red tracking); the
   whole thing is closer to a *verification/conformance runner*.

---

## v1 proposal (2026-07-17) — inline annotation syntax + scope. DRAFT for Lars's glance.

### The sigil pair

- **`//~ …`** — a runner directive. koru's own `~` sigil inside a comment: reads as
  koru, greppable, can't collide with prose. The test file stays a plain koru
  program (comment-carried expectations are the compiler-suite convergence:
  Rust `//~`, Clang `expected-error`, Swift `#name` — and a frontend-parse-error
  test *can't* carry typed declarations, so comments are structurally required
  for the negative kinds anyway).
- **`//#name`** — a named line marker (Swift-style), referenced from a pin as
  `@name`. **Reserved in v1, not enforced** — see float F1 below.

### Grammar

```
//~ run                                      positive: compiles, runs, exits 0, no leaks
//~ compile_fail(frontend)                   negative, pinned to stage
//~ compile_fail(backend)
//~ error[KORU030]: Phantom state mismatch   diagnostic pin: ID + message substring
//~ error[KORU030]                           diagnostic pin: ID only
//~ leaks: allow <reason>                    opt out of the leak gate — reason REQUIRED
//~ backends: zig js                         parity declaration (grammar reserved, v1.1)
```

The `error[…]` pin deliberately mirrors the compiler's own diagnostic format —
koruc prints `error[KORU030]: Phantom state mismatch: expected …` (SHOWN, this
session) — so a pin is a prefix of the real diagnostic line. That makes future
autoupdate Carbon-trivial: *write the diagnostic line into the file as-is*.

### Semantics (enforced by the spike)

- **Kind is declared in-file, explicitly.** `//~ run` is an assertion
  ("expected-no-diagnostics"), distinct from "nobody wrote a check". The JSON
  `"kind"` in suite.k is retired — declaring it is now a hard per-case error with
  teaching. Expectations live in the test; the suite stays pure composition.
- **An unpinned negative is itself a failure** (the `no-error-pin` keeper):
  `compile_fail` requires ≥1 `error[…]` pin.
- **All pins must match**: each pin must find a stderr line containing both
  `[ID]` and the substring. Extra unexpected diagnostics are tolerated in v1
  (lenient, Rust-style). Strict-set matching arrives together with autoupdate
  (Carbon-style) — open fork below.
- **Stage check** from koruc's phase markers: phase progress goes to stdout
  (`→ ./backend.zig`, `Building executable...`), diagnostics to stderr, exit 1 on
  failure (all SHOWN this session). Backend reached + pinned `frontend` → fail,
  and vice versa. The full 4-stage vocabulary from koru's harness
  (FRONTEND_COMPILE_ERROR / BACKEND_COMPILE_ERROR / BACKEND_RUNTIME_ERROR /
  BACKEND_EXEC_ERROR) is the target; v1 scores the frontend/backend split only —
  the finer stages aren't distinguishable from a single `koruc` invocation yet,
  so the runner **rejects them with teaching** rather than silently accepting a
  pin it can't score.
- **Leak gate, default ON, overrides pass** — for positives AND negatives (the
  harness gates both, `scripts/regression_lib.sh:663`). Two surfaces, two
  detections (both grounded in-tree this session):
  - *koruc's own compile-phase leaks*: stderr line matching `memory address …
    leaked` (the Zig GPA report — the same grep `run_regression.sh` uses).
  - *the produced program's leaks*: koru-generated `main()` already counts
    `koru_allocator` alloc/free pairs and prints `KORU LEAK CHECK FAILED` +
    `exit(1)` itself (SHOWN in `gzip/tests/output_emitted.zig:751-758`) — the
    gate is koru-native at the program level; the runner recognizes the marker.
  `//~ leaks: allow` requires a reason (reasoned-skip principle) and forgives
  exactly the leak failure, never other nonzero exits.
  *Honesty note: the gate's red path is wired but not yet SHOWN — none of the
  three suite cases leaks, so no run has demonstrated a leak-failure end-to-end.*
- **Unknown or unenforceable directives are hard errors** — a directive that
  parses but isn't enforced is a label that lies (no-fallbacks). `backends:` and
  `@marker` are rejected with teaching until their enforcement lands.

### Real example — gzip/tests/deflate_use_after_finish.kz (annotated, in tree)

```koru
//~ compile_fail(backend)
//~ error[KORU030]: Phantom state mismatch
//~ error[KORU030]: was not discharged
```

pins (SHOWN — actual koruc stderr, this session):

```
error[KORU030]: Phantom state mismatch: expected '!libs.gzip:open|!libs.gzip:fed' but got 'libs.gzip:done!' for argument 'd'
error[KORU030]: Resource 'd' carries obligation <done!> was not discharged. Call: libs.gzip:deflate.release
```

The file's old prose `// EXPECTED: …` comment is replaced by the pins — the
expectation is now machine-checked, so it can't drift into a doc-lie.

### v1 scope — the headline three, committed

1. **Staged must-not-compile** (frontend|backend + ID/substring pins) — SPIKED.
2. **Leak gate** (default-on, overrides pass, reasoned opt-out) — SPIKED.
3. **Cross-backend parity** — grammar reserved (`//~ backends: zig js`),
   enforcement v1.1: needs the runner to drive the js target and diff outputs.
   The overridable `run` seam is where it plugs in.

### Toolchain floats (found while grounding — each might be me)

- **F1 — backend diagnostics carry the checker's name and the WRONG source
  line.** The phantom checker reports `--> phantom_semantic_check:25:0`: the
  *checker's name* where the file should be. The line number IS source-relative
  (SHOWN: adding 3 header lines moved the report 22→25 in lockstep) — but it
  points at the *first* `deflate.push` (line 25), not the offending
  use-after-finish push (line 27) that the message is actually about. Frontend
  errors DO carry the real location (`--> frontend_err.kz:3:1`, SHOWN).
  Consequence: named-line-marker pinning
  (`//#use-site` / `@use-site`) — the steal-list's *structurally required*
  feature for multi-line obligation errors — is blocked at the backend until
  diagnostics carry real `file:line`. This is the koru-level-diagnostics lift
  (the known systemic program), surfaced here as the concrete blocker.
- **F2 — the raw Zig stack trace leaks into koruc stderr** after the KORU030
  diagnostics (`backend.zig:95 … error.CompilerCoordinationFailed`). Known
  intentional escape-hatch gap, not new — noted because the runner deliberately
  surfaces koruc's stderr verbatim on failure, so this leak is now user-visible
  in the board output too.

### Aspiration — piggyback concurrent runs (Lars, 2026-07-17)

The koru repo's harness pain: multiple runs of the same suite get fired in the
same worktree (several agents, one tree) and race. Note this is a CORRECTNESS
bug, not just waste: koruc writes generated artifacts (`backend.zig`,
`output_emitted.zig`, `a.out`) into the test's own directory (SHOWN in
gzip/tests), so concurrent runs clobber each other's verdicts.

Design shape — **per-workdir run ledger + atomic case claims**:
- Shared journal (`.koru-regressions/journal.jsonl`), one line per scored case,
  written incrementally.
- A run claims a case via `O_EXCL` create of `case-<id>.claim` (pid +
  timestamp); the loser skips to the next unclaimed case and only at the end
  streams/waits on sibling-claimed results. Stale claims (dead pid, past the
  watchdog) are stealable.
- Emergent property: concurrent invocations become cooperating workers — the
  second run helps with the unclaimed tail, or degenerates to a viewer of the
  sibling's board when everything is claimed (the literal piggyback).
- Composes with the fingerprint result cache (steal-list keeper): key journal
  entries by hash(test file + transitive import closure + koruc version) and
  the ledger becomes a cross-time cache — unchanged cases never re-run.

Staging: in-flight dedup first (claims + journal, case id = file path, no
fingerprinting needed); fingerprint caching second (wants the import-closure
hash). Claims alone also kill the artifact race without any koruc change; an
out-of-tree output dir for koruc would be the toolchain-side alternative.

### Open forks from this proposal (the glance)

- (a) **Strict diagnostic-set matching + autoupdate** — RULED (Lars, 2026-07-17):
  lenient in v1; strict matching and autoupdate land TOGETHER as one v2 feature,
  never strict alone (strict without a promote flow punishes exactly the
  error-message tuning we most want to encourage). Optional cheap belt if wanted
  later: a `//~ diagnostics: N` count pin (the compiler already prints the count
  in its `──── diagnostics (N) ────` summary).
- (b) **Sigil bikeshed** — RULED (Lars, 2026-07-17): `//~` + `//#`/`@name` as
  proposed and spiked. (Rust precedent noted through gritted teeth.)
- (c) **`backends:` placement** — RULED (Lars, 2026-07-17): per-file
  (`//~ backends: zig js` in the test itself). Parity participation is an
  expectation, and expectations live inline; per-case in suite.k would recreate
  the two-file drift that retiring JSON "kind" killed. Key split: the file
  DECLARES which backends the test must hold on (standing contract); the
  invocation SELECTS which declared backends a given run exercises (quick run =
  zig only, full run = all declared, later a `--backends` sweep flag). No
  directive = primary backend only, explicit on the board — absence reads as
  "not claimed for js," never as silently-skipped green. (Matches koru's
  per-test LANGUAGES marker, minus the marker-file bureaucracy.)
