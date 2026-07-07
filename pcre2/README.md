# pcre2 — the definitive Koru PCRE2 edition

**One-line pitch**: Battle-tested Perl-compatible regex with the compiled
pattern and match buffer turned into compiler-enforced obligations.

**Entry type**: new lift

**Author**: Claude (Opus 4.8, koru-libs LIFT_CHALLENGE contestant, session
`agent-a1d5c23c393e94074`, 2026-07-03)

## What the C library does, and what we lift

[PCRE2](https://www.pcre.org/) is the Perl-Compatible Regular Expressions
library — the regex engine inside git, PHP, nginx, Apache, and countless others.
It brings the full PCRE dialect (backreferences, lookaround, named groups,
Unicode properties) that a bounded DFA cannot express.

Its C API hands you two heap resources you must free by hand, in order:

- `pcre2_compile()` returns a `pcre2_code *` you must `pcre2_code_free()`.
- `pcre2_match_data_create_from_pattern()` returns a `pcre2_match_data *` you
  must `pcre2_match_data_free()`.

and it makes you drive iteration yourself with a raw offset cursor into the
ovector — where an empty match loops forever unless you hand-code the nudge.

This edition compiles those footguns away. The compiled pattern becomes a
phantom obligation (`Regex<compiled!>`): forget to free it, or use it after
freeing, and the **build fails**. The match-data buffer never touches your
hands at all — `find.all` owns it, iterates every match for you (empty-match
nudge included), and frees it exactly once. Each match arrives as a
per-iteration **borrow** valid only inside its `! match` body.

## The happy path

```koru
~import libs/pcre2
~import std/io

~libs/pcre2:compile(pattern: "(\\w+)@(\\w+)")
| ok re |> libs/pcre2:find.all(re, subject: "alice@example and bob@work")
    ! match m |> libs/pcre2:group.text(m, index: 1): user |> libs/pcre2:group.text(m, index: 2): host |> std/io:print.ln("{{ user:s }} @ {{ host:s }}")
    | done re2 |> libs/pcre2:free(re2)
    | err e |> libs/pcre2:free(e.re)
| err e |> std/io:print.ln("bad pattern: {{ e.msg:s }}")
```

Five entry points, each impossible to misuse: `compile`, `find.all`,
`group.text`, `group.count`, `match.start`, discharged by `free`.

## The quadrifecta self-audit

- **DX**: The whole `pcre2_match_data` lifecycle — create, size-from-pattern,
  extract from ovector, free, and the empty-match infinite-loop trap —
  disappears. You write `find.all(re, subject: ...)` and get a `! match` body
  per hit; captures are `group.text(m, index: N)`. A newcomer never learns that
  PCRE2 has a match-data object, an ovector, or a code-unit width. The one thing
  they must do — free the compiled pattern — the compiler either auto-inserts
  (see `examples/extract_emails.kz`, which has no explicit `free`) or demands.

- **Performance**: The lift is pure compile-time type threading; at runtime this
  is a thin call straight into `libpcre2-8`, identical to a hand-written C loop
  (`pcre2_compile_8` once, `pcre2_match_8` per step, one `pcre2_match_data`
  reused across the whole scan, freed once). No per-match allocation on the
  happy path — captures are returned as borrowed slices into your own subject
  string, not copied. UNMEASURED against a raw-C baseline; the generated Zig is
  the same sequence of libpcre2 calls a careful C author would write, so the
  claim is "no runtime tax," not a benchmarked number.

- **Correctness**: Wrong usage is a build error. `tests/negative_use_after_free.kz`
  frees the regex then reuses it and fails with
  `error[KORU030]: Use-after-discharge: binding 're' was already discharged`.
  An uncompilable pattern is a loud `| err` branch carrying PCRE2's own
  diagnostic and the byte offset (`tests/features.kz` case 3), never a silent
  null or a stub answer. Out-of-range / non-participating capture indices return
  `""` rather than reading out of bounds (`group.text|zig`, index.kz).

- **Resource safety**: The `compiled` obligation is enforced end-to-end —
  `tests/negative_forgotten_free.kz` run with `--auto-discharge=disable` fails
  with `error[KORU030]: Resource '_' <compiled!> was not discharged`. Because
  `find.all` only *borrows* the pattern, the obligation lives with the caller
  across the whole loop; you can discharge it by hand (`tests/basic.kz` writes
  `free` explicitly) or let the compiler insert the single legal disposer at
  every branch exit (`tests/auto_dispose.kz` and `examples/extract_emails.kz`
  carry no `free` at all — auto-discharge fills it in). The
  per-match borrow `*Match<match!>` (index.kz:131) is proven scoped by the
  auto-inserted `unmatch` discharge (index.kz:187): capture it past the `! match`
  body and the phantom checker rejects the build (KORU030), the same wall
  sqlite3's `! row` uses. The match-data buffer is unleakable by construction —
  it is created and freed inside `find.all` and never surfaced to the caller.

## What it explicitly doesn't do (yet)

- **Compile-time pattern validation.** The pattern compiles at *runtime*; a
  malformed literal is caught as a loud `| err` at run, not at build. That is the
  honest fit for PCRE2 (a runtime engine whose value over Koru's built-in
  `std/regex` DFA is exactly the runtime-only PCRE features). Lifting literal
  patterns to a build-time `@compileError` — mirroring `koru_std/regex.kz`'s
  `analyze`+compile-error path — is the natural v1.
- **Owned captures / single `find`.** Captures are borrows valid only inside the
  `! match` body (they point into match-data reused each iteration). There is no
  `find`-first-only entry that returns an owned `Match` you can keep. Copy out
  with `std` inside the body if you need to retain a capture. v1.
- **No flags, named groups, substitution, or JIT.** `compile` takes options `0`;
  no `PCRE2_CASELESS`/`PCRE2_MULTILINE`, no `group.by_name`, no
  `pcre2_substitute`, no `pcre2_jit_compile`. Scoped-out v0 surface.
- **8-bit code units only.** UTF-8 / bytes (what a Koru `[]const u8` is). No
  16-/32-bit builds.

## Toolchain findings

Building the first library to actually drive an effect-branch (`!`) producer
that wraps a C library through **end-to-end codegen** surfaced two real compiler
defects. Both would also bite the sqlite3 exemplar's `! row` path
(`query.literal`) — but no sqlite3 test drives that path (its tests all use the
`~query` comptime-transform instead), so neither was caught. Both are floated
here, not fixed (this is a library submission, not a compiler change), and the
lift ships cleanly around each with the gap stated.

### Finding 1 — module `c`/type refs from an inlined effect body

An effect-branch producer's proc body is emitted at **two sites with different
scopes**: (1) inlined into the *consumer's* frame, where the wrapper module's
decls (the `@cImport` alias `c`, and module types like `Match`) are **not** in
scope; and (2) as the module's own event handler, where they **are**. The
sqlite3 exemplar documents reaching `c` via `const c = @import("root")
.koru_libs.sqlite3.c;` (index.kz:98) and references its `Statement` type bare
(index.kz:111). Driven end-to-end that idiom breaks both ways:

- bare `Match` → `error: use of undeclared identifier 'Match'` at the inlined
  site;
- local `const c = ...` → `error: local constant shadows declaration of 'c'` at
  the handler site.

Raw Zig errors leak from generated code; no koru-level diagnostic points at the
cause. Two further wrinkles: the module actually registers as
`koru_libs.koru_pcre2` (a `koru_` prefix), **not** `koru_libs.pcre2` as the
exemplar's documented path implies; and there is no spelling using the name `c`
that satisfies both sites.

**Minimal repro**: `tests/TOOLCHAIN_REPRO_effect_module_scope.kz` (fails with
the shadow error; self-contained, no PCRE2).

**Ship-around**: reach every module decl through one non-colliding module alias
— `const px = @import("root").koru_libs.koru_pcre2;` then `px.c` / `px.Match`
(index.kz:145). This is the same aliasing rationale vaxis/pq already use for
name clashes; here it is *forced*, not chosen.

### Finding 2 — dotted auto-release event name is mis-referenced in codegen

A borrow minted by `! match *Match<match!>` is discharged by a release event the
compiler finds **by signature** and auto-inserts. If that event has a **dotted**
name (sqlite3's exemplar spells it `release.row`), the declaration registers
flat as `release_row_event` but the auto-inserted call is emitted as
`<pkg>.release.row_event.handler` (the dot kept, splitting a namespace that
does not exist) →
`error: struct '<pkg>' has no member named 'release'`. The dot→underscore
transform that is applied correctly everywhere else (`find.all` →
`find_all_event`, `group.text` → `group_text_event`) is not applied on the
auto-release reference path.

**Ship-around**: name the release event with a **single non-dotted segment** —
`unmatch` (index.kz:187). It is still found by signature (it consumes
`<!match>`), so the borrow-escape guarantee is fully preserved; only the
cosmetic `release.x` naming convention is given up.

## Proof of life

```
$ koruc --check pcre2/index.kz
✓ Shape checking passed

$ koruc run pcre2/tests/basic.kz
...
alice @ example
bob @ work
done

$ koruc run pcre2/tests/features.kz
...
groups=2 start=0 word=2015
groups=2 start=5 word=12
groups=2 start=8 word=25
scanned
nomatch-ok
bad pattern at offset 1

$ koruc run pcre2/examples/extract_emails.kz
...
alice / example.com
bob / work.org
carol / mail.net

$ koruc run pcre2/tests/negative_use_after_free.kz
error[KORU030]: Use-after-discharge: binding 're' was already discharged and cannot be used

$ koruc run pcre2/tests/negative_forgotten_free.kz --auto-discharge=disable
error[KORU030]: Resource '_' <compiled!> was not discharged. Call one of: libs.pcre2:find.all, libs.pcre2:free

$ koruc run pcre2/tests/TOOLCHAIN_REPRO_effect_module_scope.kz   # finding 1, expected to fail
output_emitted.zig: error: local constant shadows declaration of 'c'
```
