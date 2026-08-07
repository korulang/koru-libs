# yyjson — write-side depth pass notes

**One-line pitch**: lifted yyjson's mutable/write API into `koru/yyjson`, so
Koru can BUILD JSON and not only read it — with the rendered buffer carrying
its own obligation, because C makes you free it separately and everyone
forgets.

**Entry type**: depth pass on `yyjson` (read v0 shipped 2026-07-10)

**Author**: Claude (Opus 5), koru-libs write-lift commission, 2026-08-07

## Why this existed to be done

`koru-examples/kopium/auth.kz:41-65` builds its OpenRouter request body by
hand — a literal prefix, a character-by-character escape loop, a literal
suffix — and its own comment says why:

> FINDING: this exists because yyjson is read-v0 — building JSON has no koru
> surface yet (the serialize depth pass ECOSYSTEM.md names). The messages
> array is single-turn for the same reason: replaying history means
> serializing the transcript, which wants the real builder.

So the cost of the missing half was not hypothetical: it was a hand-rolled
escaper in live code, and a *feature* (multi-turn history) cut because
serializing a transcript by hand was not worth it.

## What is bound

Fifteen new tors, mirroring the read side's vocabulary:

| write | mirrors | notes |
| --- | --- | --- |
| `build` | `parse` | mints `*Builder<open!>` |
| `build.close` | `close` | discharges it |
| `new.object` / `new.array` | — | container nodes |
| `new.string` / `new.int` / `new.double` / `new.bool` / `new.null` | `as.*` | leaf nodes |
| `object.set` | `object.get` | |
| `array.push` | `array.get` | |
| `root.set` | `root` | |
| `render` / `render.pretty` | — | mint `string<rendered!>` |
| `render.free` | — | discharges it |

C entry points used: `yyjson_mut_doc_new`, `yyjson_mut_doc_free`,
`yyjson_mut_doc_set_root`, `yyjson_mut_obj`, `yyjson_mut_arr`,
`yyjson_mut_strncpy`, `yyjson_mut_sint`, `yyjson_mut_real`, `yyjson_mut_bool`,
`yyjson_mut_null`, `yyjson_mut_obj_add`, `yyjson_mut_arr_add_val`,
`yyjson_mut_is_obj`, `yyjson_mut_is_arr`, `yyjson_mut_write_opts`, `free`.

## What is deliberately NOT bound

Fully listed with reasoning in README "What it explicitly doesn't do (yet)".
The short form, and the one entry that is a *design* decision rather than a
scope cut:

- **File I/O** (`yyjson_mut_write_file`) — `std/io` already owns paths.
- **The immutable/mutable bridge** (`yyjson_doc_mut_copy`,
  `yyjson_mut_doc_imut_copy`) — **this one is load-bearing.** Not binding it
  is what keeps a `*Node`'s shape statically knowable, which is the premise
  the single-path `object.set`/`array.push` rest on (below). Binding it later
  is not additive; it means revisiting that decision honestly.
- **JSON Pointer / Patch / Merge-Patch** — real, separable, not started
  rather than half-done.
- **`uint64`** — no `new.uint`, because there is no `as.uint` to mirror. A
  *symmetric* hole beats an asymmetric one; close both in one pass.
- **All write flags but `PRETTY`** — see "the default is the contract" below.

## The three design calls worth arguing with

### 1. Two obligations, not one

The obvious design gives the builder an obligation and lets the rendered
string live in its arena. That is wrong, and the reason is specific:
`yyjson_mut_write` allocates its buffer from **libc's** allocator, not from
the document arena (`yyjson.h:1383`: "it should be freed with free() or
alc->free()"). A C caller therefore owes two frees, and the string is the one
they forget — closing the doc *feels* like finishing the job.

Two C frees, two Koru obligations: `build` mints `*Builder<open!>`, `render`
mints `string<rendered!>`. The second uses the same spelling `std/io` already
uses for allocator-owned buffers (`read-file` → `string<allocated!>` →
`std/io:free`), so it is not a new idiom.

Keeping the rendered string **off** the arena is also what makes it useful:
you can render a request body, close the builder, and only then hand the
string to an HTTP tor. Arena ownership would have made that ordering a
use-after-free — the exact bug the read side exists to prevent, reintroduced
by the write side.

### 2. Assembly does not branch

`object.set` and `array.push` are single-path and abort on a wrong-shape
target, where their read-side mirrors `object.get`/`array.get` branch. This
looks like an inconsistency. It is the file's own rule applied correctly.

Read off the read side, the rule is: **data conditions branch; programmer
errors abort.** `not-found`, `out-of-range` and `wrong-type` all depend on
what was in the JSON. `root`'s `orelse @panic` and `parse`'s OOM
`catch @panic` do not. A wrong-shape assembly target is the second kind:
a `*Node` can only come from a `new.*` in the caller's own flow (there is no
tor that hands you a Node out of parsed data — see the unbound bridge above),
so whether `v` is an object is fixed three lines up and never depends on input.

A `| not-an-object` arm would be unreachable by construction, and that is
precisely what makes it harmful: every caller writes it by rote and fills it
with the same cleanup as the happy path, so a node mixup stops being a crash
and becomes a **silently missing field**. It would also bury `render`'s
genuinely-reachable `err` under a ten-deep pyramid of arms that cannot fire —
counted, not estimated: the kopium body needs six `object.set` and one
`array.push`.

The flat chain in `examples/build_request.kz` is the payoff, and it is not
cosmetic: one branch in the file is the one branch that can happen.

### 3. The default is the contract

`render` passes `YYJSON_WRITE_NOFLAG` and there is no `flg:` parameter.
`ESCAPE_UNICODE` would render `å` as `\u00e5`; `ESCAPE_SLASHES` would render
`anthropic/claude-haiku-4.5` as `anthropic\/claude-haiku-4.5`. Both are legal
JSON and neither is what hand-written code produces. An `flg: i32` escape
hatch would have been one line and would have made the byte-agreement
guarantee below unstatable.

## Proof

### Byte agreement (the acceptance test)

`tests/kopium_body_parity.kz` transcribes kopium's escape loop verbatim,
feeds one koru string literal to both sides (`hand-rolled` returns the prompt
alongside its output, so a typo could not fake agreement), and prints both:

```
hand-rolled: {"model":"anthropic/claude-haiku-4.5","stream":true,"messages":[{"role":"user","content":"she said \"go\\stop\"\n\tnål ✓"}]}
yyjson     : {"model":"anthropic/claude-haiku-4.5","stream":true,"messages":[{"role":"user","content":"she said \"go\\stop\"\n\tnål ✓"}]}
agree      : true
```

The prompt carries a double quote, a backslash, a newline, a tab, a two-byte
`å` and a three-byte `✓`.

**One divergence, found by probing for it, and it is in the lift's favour.**
The hand-rolled loop's `else` arm is `if (ch >= 0x20) out.append(...)` — it
*drops* control bytes below 0x20 other than `\n`/`\t`. Given a prompt
containing `\x07` and `\x01`:

```
hand-rolled: ..."content":"bell: soh: done"...
yyjson mut : ..."content":"bell:\u0007 soh:\u0001 done"...
agree      : false
```

The hand-rolled version silently corrupts the text; `render` escapes it
correctly. So the two agree on every input the hand-rolled version handles
correctly and differ exactly where it was already wrong. That is worth
knowing before anyone migrates kopium and sees a diff.

### Leak-clean, at both compile time and runtime

Compile time — both refusals demonstrated, not asserted:

```
$ koruc tests/negative_forgotten_build_close.kz --auto-discharge=disable
error[KORU030]: Resource 'doc' carries obligation <open!> was not discharged. Call: koru.yyjson:build.close

$ koruc tests/negative_forgotten_render_free.kz --auto-discharge=disable
error[KORU030]: Resource 'body' carries obligation <rendered!> was not discharged. Call: koru.yyjson:render.free

$ koruc tests/negative_use_after_build_close.kz
error[KORU030]: Use-after-discharge: binding 'doc' was already discharged and cannot be used
```

`negative_forgotten_render_free.kz` closes the builder *correctly* and drops
only the string, so the diagnostic can only be about the second obligation.

Runtime — `leaks --atExit` on `examples/build_request.kz`'s binary (two
renders, two frees, one close) reports `0 leaks for 0 total leaked bytes`.
The instrument was checked for vacuity: the same C sequence with only
`free(buf)` removed reports `1 leak for 512 total leaked bytes`, stack
`ROOT LEAK: <realloc in yyjson_mut_write_opts_impl>`.

### Additive — read side untouched

Every read tor keeps its exact signature. Verified by running the read side
before and after the change: `tests/basic.kz`, `tests/features.kz` and
`examples/read_config.kz` all produce output identical to their documented
EXPECTED blocks, and both read-side negatives still fail with their
documented diagnostics.

## What fought back

**The resource discipline did not fight at all** — and that is the reportable
result, because the commission asked me to stop and say so if a mutable doc's
obligation could not be expressed the way `Doc<open!>` is. It can, exactly:
`*Builder<open!>` / `*Builder<!open>` / `*Builder<open>` behave identically to
`Doc`, including use-after-discharge across a module boundary. The second,
*string-valued* obligation (`string<rendered!>`) also worked first try — the
spelling already existed in `std/io`. No qualified-phantom spelling was needed
anywhere, because no user-defined tor in the examples or tests takes an
obligation-carrying parameter; every obligation is minted and discharged
inside a single flow.

Three things did fight:

1. **Multi-line chains and branch arms.** A build chain is long and wants to
   wrap. An indented `|` arm following a leading-`|>` continuation line is
   *silently swallowed* (no diagnostic) and every arm after it is reported as
   `KORU010: stray continuation line`. Bisected to a crisp four-case rule and
   filed as README "Finding 3" with a std/io-only repro,
   `tests/TOOLCHAIN_REPRO_indented_branch_after_continuation.kz`. Ship-around:
   arms at column 0. Separately, a *trailing*-`|>` continuation is miscompiled
   even with no branches (`expected ',' after field` in the emitted Zig).

2. **Zero-argument call syntax and label punning.** `build` takes `{}` and is
   called `build()`; `render.free(body)` is rejected because `body` does not
   pun with the parameter name `text`. Both are documented behaviour, not
   defects — noted because they cost a compile cycle each.

3. **A merge conflict in the compiler tree, mid-run.** `koru/src/ast.zig`
   grew literal `<<<<<<< Updated upstream` markers between two of my compiles
   (a conflicted `git stash pop` from another session), which broke the
   backend rebuild with `expected type expression, found '<<'`. Reported
   rather than touched, since that tree was out of scope; resolved by its
   owner. Recorded here only because it is the kind of failure that looks
   like your own bug for ten minutes.

**Translate-c was clean this time.** The read side had to hand-roll
`as.bool` around a mistranslated inline accessor (README Finding 2). Every
mutable-API function used here — including the `yyjson_mut_val_one` macro
family that expands to the same bitfield writes — survives `@cImport` intact.
Verified with a standalone `zig build-exe` probe against `yyjson.h` before
any Koru was written, which is also where the byte-agreement result first
came from.
