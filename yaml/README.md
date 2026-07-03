# yaml — the definitive Koru libyaml edition

**One-line pitch**: A streaming YAML parser that makes libyaml's per-event leak footgun uncompilable.

**Entry type**: new lift

**Author**: Claude Opus 4.8 (koru-libs lift-challenge contestant, session 2026-07-03)

## What the C library does, and what we lift

[libyaml](https://github.com/yaml/libyaml) is the reference C implementation of
YAML 1.1 — the same parser engine behind PyYAML, Ruby's Psych, and most
language YAML bindings. Its streaming API is a two-level resource machine: a
`yaml_parser_t` you must `yaml_parser_initialize` and `yaml_parser_delete`, and
a stream of `yaml_event_t`s where **every** event returned by
`yaml_parser_parse` must be `yaml_event_delete`d (each event owns
heap-allocated scalar / tag / anchor buffers).

The classic footgun is the second one: a `while` loop that parses events but
forgets `yaml_event_delete` in the loop body leaks on *every iteration* — a
silent, unbounded leak that a passing test never catches. This edition lifts
both levels into Koru's phantom obligation system and fuses them into a single
`Cursor<live!>` handle, so forgetting to delete an event or close the parser is
a **compile error**, not a runtime leak.

The API is five verbs:

```koru
~import libs/yaml
~import std/io

~libs/yaml:open(input: "name: Ada\nrole: pioneer\n")
| ok p |> libs/yaml:begin(parser: p)
    | at c |> libs/yaml:kind(cur: c)
        | k kk |> std/io:print.ln("{{ kk.name:s }}") |> libs/yaml:finish(kk.cur)
    | eof pp |> libs/yaml:close(parser: pp)
    | err ep |> libs/yaml:close(parser: ep)
| err e |> std/io:print.ln("could not open: {{ e:s }}")
```

- `open` mints `Parser<open!>` — the obligation to dispose of the parser.
- `begin` converts an open parser into a live `Cursor<live!>` positioned at the
  first event (or hands the parser straight back on an empty stream / error).
- `advance` consumes a live cursor, deletes its current event, parses the next,
  and mints a fresh live cursor — a single obligation threaded through the walk.
- `finish` consumes a live cursor and does the full cleanup (delete event +
  close parser) in one move.
- `kind` / `scalar` inspect the current event, threading the obligation so you
  can look before you dispose.

The fused-cursor shape is deliberately the language's own resource-lifecycle
idiom: koru's enforced lifecycle suite fuses a connection and its open
transaction into one `Transaction<active!>` state rather than tracking two
handles at once. This edition does the same for parser + event.

## The quadrifecta self-audit

- **DX**: the happy path is `open → begin → (kind/scalar…) → advance/finish`,
  and there is exactly **one** handle to carry at any moment — the cursor. A
  newcomer never learns libyaml's `yaml_parser_t` / `yaml_event_t` lifecycle,
  never sees `yaml_event_delete`, never worries about the input-buffer aliasing
  rule (libyaml borrows your input pointer for the parser's whole life — this
  edition owns a private copy, `index.kz` `open`). The obligation names in
  error messages (`libs.yaml:finish`, `libs.yaml:advance`) tell you exactly
  which call you forgot.

- **Performance**: the lifting is entirely compile-time — the phantom
  obligations are erased before codegen, so the runtime is a thin FFI shim over
  libyaml with **no** extra tax on the parse itself (libyaml does all scanning
  and allocation). The one allocation the wrapper adds is a single heap `Cursor`
  per walk, *reused* across every `advance` (the event is parsed in-place into
  the same wrapper), plus one private copy of the input. This matches the
  allocation shape a careful hand-written libyaml C client would use. Status:
  **UNMEASURED** beyond "it parses real documents and runs clean" — no
  benchmark was run, so no speed claim is made.

- **Correctness**: wrong usage does not compile. Two negative tests prove the
  obligations bite (both under `--auto-discharge=disable`, the flag koru's own
  suite uses to bare the obligation tracking):
  - `tests/negative/forgotten_close.kz` — open a parser, discard it →
    `error[KORU030]: Resource '_' <open!> was not discharged`.
  - `tests/negative/forgotten_finish.kz` — get a live cursor, never
    advance/finish it → `error[KORU030]: Resource 'c' <live!> was not
    discharged`.

- **Resource safety**: the two leak classes libyaml is infamous for are both
  uncompilable. The parser's `open!` obligation (`index.kz` `open`, discharged
  only by `close` or `finish`) and the event's `live!` obligation (folded into
  `Cursor`, discharged only by `finish` or re-minted by `advance`) mean the
  compiler will not let you forget either delete. Under default settings the
  auto-discharge pass even inserts the missing disposer for you; the negative
  tests disable it to prove the underlying tracking is real, not cosmetic.

## What it explicitly doesn't do (yet)

- **Unbounded streaming loops are blocked by a compiler bug.** The natural form
  — a `#loop` that `advance`s until `eof` — does not compile today because of a
  cross-module obligation / back-edge defect in the compiler (see Toolchain
  findings and `tests/frontier/loop_crossmodule_backedge.kz`). Straight-line
  walks of a bounded number of events work and are what the passing tests and
  examples use. When the compiler bug is fixed, the loop becomes the headline.
- **No document/DOM API.** Only the streaming event API is wrapped; there is no
  `yaml_parser_load` document tree, no node navigation, no aliases/anchors
  resolution.
- **No emitter.** Read-only: this is a parser, not a serializer
  (`yaml_emitter_*` is unwrapped).
- **No typed schema binding.** Scalars are returned as borrowed `[]const u8`
  text (valid until the next `advance`/`finish`); there is no int/bool/null
  coercion or tag interpretation yet.
- **Scalar text is a borrow, not a copy.** `scalar`'s `text` points into the
  event's internal buffer and is invalidated by the next `advance`/`finish`.
  Read it before advancing. (The parser-open + event-live *handles* are
  obligation-tracked; the borrowed *slice's* narrower lifetime is documented,
  not yet phantom-enforced.)

## Toolchain findings

**1. CONFIRMED BUG — cross-module phantom obligation across a `#loop` /
`@loop` back-edge (KORU030).** An obligation minted in an imported module and
threaded through a loop's back-edge is rejected with a namespace mismatch:

```
error[KORU030]: Phantom state mismatch: expected 'index:live'
                but got 'libs.yaml:live!' for argument 'c2'
```

`index:` is the imported file's own module name; `libs.yaml:` is the alias it
is imported under. The identical obligation threads correctly in a straight
line (repeated `advance` calls — `tests/walk.kz`, `tests/scalars.kz` pass), and
same-file obligations loop fine (koru's own
`330_085_obligation_held_across_back_edge` is green). Only the back-edge
re-resolution of a *cross-module* obligation drops the import-alias
normalization. It is **not** held-across specific: the failing `c2` is the
loop's own threaded variable, freshly re-minted each turn by `advance`.

Minimal repro: `tests/frontier/loop_crossmodule_backedge.kz` (pinned RED).
This is the single wall between this package and its natural streaming loop.

**1a. The error message for that bug is itself weak.** It leaks
compiler-internal module qualifiers (`index:` vs `libs.yaml:`) to the user and
gives no guidance — there is nothing the *user's* code can do differently. A
koru-level message ("this obligation was minted in an imported module and is
not yet supported across a loop back-edge") would be a pit-of-success wall;
the current one reads as an internal invariant leaking out.

**2. OBSERVATION (grounded, flagged — I am not certain this is a bug vs. my
misuse).** My first design returned multi-field branch payloads carrying
per-field obligations, e.g. `next → | event { parser: *Parser<open!>, ev:
*Event<live!> }`. In that shape I **could not get either obligation to bite**,
even with `--auto-discharge=disable`: leaking `ev` (never dropping the event)
or leaking the `parser` field both compiled and ran silently. Direct
single-obligation payloads (`open → | ok *Parser<open!>`) enforce correctly.
koru's own *enforced* lifecycle suite (the `2104`/`app/db` series) uses **only**
direct single-obligation payloads, threaded one at a time; the `sqlite3`
exemplar does use multi-field obligation payloads (`| row { conn: <opened!>,
stmt: <prepared!> }`), but its `~proc`s are bare and now KORU110-stale, so that
path appears unexercised against the current compiler. I redesigned around the
enforced idiom (the fused `Cursor`), which made pillar 4 sound. Worth
confirming upstream whether per-field obligation tracking in multi-field
payloads is unimplemented or whether I was structuring it wrong — I did not
change any compiler code, and I'm ~50/50 on which reading is right.

**3. Minor.** The `|zig` proc-variant tag is required (bare `~proc` →
KORU110), matching `vaxis`/`pq` house style but not the `sqlite3` exemplar,
which still uses bare procs. Not a bug in this package; a note that the
exemplar is stale.

## Proof of life

All commands run from the repo root with
`KORUC=/Users/larsde/src/koru/zig-out/bin/koruc`.

**Gate 1 — `koruc --check`:**

```
$ $KORUC --check yaml/index.kz
✓ Shape checking passed
```

**Gate 2 — every test runs end-to-end (`koruc run`):**

```
$ $KORUC run yaml/tests/basic.kz
Opened, read one event, closed!

$ $KORUC run yaml/tests/walk.kz
1: stream-start
2: document-start
3: mapping-start
-- finished --

$ $KORUC run yaml/tests/inspect.kz
kind = stream-start (non-scalar)

$ $KORUC run yaml/tests/scalars.kz
scalar = hello world
```

**Examples:**

```
$ $KORUC run yaml/examples/inspect_events.kz
event 1: stream-start
event 2: document-start
event 3: mapping-start
(cursor finished: event deleted, parser closed)

$ $KORUC run yaml/examples/first_scalar.kz
first scalar: "the definitive edition"
```

**Gate 3 — negative tests fail to compile with `--auto-discharge=disable`:**

```
$ $KORUC run yaml/tests/negative/forgotten_close.kz --auto-discharge=disable
error[KORU030]: Resource '_' <open!> was not discharged. Call one of: libs.yaml:close, libs.yaml:begin, libs.yaml:error-text

$ $KORUC run yaml/tests/negative/forgotten_finish.kz --auto-discharge=disable
error[KORU030]: Resource 'c' <live!> was not discharged. Call one of: libs.yaml:finish, libs.yaml:advance, libs.yaml:scalar, libs.yaml:kind
```

(Both compile and run under default settings — auto-discharge inserts the
missing disposer; disabling it lays the obligation bare.)

**Pinned compiler bug (expected RED):**

```
$ $KORUC run yaml/tests/frontier/loop_crossmodule_backedge.kz
error[KORU030]: Phantom state mismatch: expected 'index:live' but got 'libs.yaml:live!' for argument 'c2'
```
