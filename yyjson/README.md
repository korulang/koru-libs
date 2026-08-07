# yyjson — the definitive Koru yyjson edition

**One-line pitch**: The fastest conformant JSON library, wrapped so a value
read from a freed document is a compile error instead of a dangling pointer —
and so a rendered document you forget to free is one too.

**Entry type**: new lift

**Author**: Claude (Sonnet 5, koru-libs LIFT_CHALLENGE contestant, session
`agent-a8b66a8f5a5164dfa`, 2026-07-10)

## What the C library does, and what we lift

[yyjson](https://github.com/ibireme/yyjson) is the fastest conformant JSON
library in C — single-file, permissively licensed, used inside PHP internals
and by projects like ScyllaDB. Per `ECOSYSTEM.md`'s own Orisha demand triage,
JSON parse/serialize was the single biggest hole in the whole koru-libs
catalog: a webserver framework that cannot read a request body or write a
response is not usable, and until this lift the catalog had no JSON support
at all.

yyjson's read API parses a document into one arena (`yyjson_doc *`) and hands
back `yyjson_val *` pointers into that arena for every object member, array
element, and scalar you navigate to. Free the doc and every value pointer you
were still holding becomes instantly dangling — read one and you get garbage,
non-deterministically, depending on what the allocator does with the freed
memory next. This is a silent, classic C footgun and a real CVE class in
JSON-handling C/C++ code.

This edition compiles that footgun away. The parsed doc is a phantom
obligation (`Doc<open!>`): forget `close` and the build fails
(`tests/negative_forgotten_close.kz`). More importantly, **every value
reader** — `root`, `object.get`, `array.get`, `array.each`, `object.each`,
`as.string/int/double/bool` — requires `doc: *Doc<open>` as an argument: a
*borrow* of the still-live obligation, not documentation. Once `close` has
discharged it, presenting that same `doc` binding again is a compile error
(`tests/negative_use_after_close.kz`), even though nothing about the *value*
handle itself looks different. The type system, not a runtime check, is what
makes "read a value after freeing its document" unreachable.

## The happy path

```koru
~import koru/yyjson
~import std/io

~koru/yyjson:parse(text: "{\"service\": \"search-api\", \"port\": 8443}")
| ok doc |> koru/yyjson:root(doc): root_v |> koru/yyjson:object.get(doc, v: root_v, key: "service")
    | found service_v |> koru/yyjson:as.string(doc, v: service_v)
        | ok s |> std/io:print.ln("service: {{ s:s }}") |> koru/yyjson:close(doc)
        | wrong-type |> std/io:print.ln("service: wrong type") |> koru/yyjson:close(doc)
    | not-found |> std/io:print.ln("service: missing") |> koru/yyjson:close(doc)
| err e |> std/io:print.ln("bad json: {{ e.msg:s }}")
```

Eleven read entry points, every one requiring the doc's live obligation to
touch a value: `parse`, `close`, `root`, `object.get`, `array.get`,
`array.each`, `object.each`, `as.string`, `as.int`, `as.double`, `as.bool`.

## The write path

Building JSON is the mirror of reading it, and it is the half real code was
missing: `koru-examples/kopium/auth.kz` builds its OpenRouter request body
with buffer appends and a hand-written character-escape loop, and says in a
comment that it does so only "because yyjson is read-v0 — building JSON has
no koru surface yet".

```koru
~koru/yyjson:build(): doc
|> koru/yyjson:new.object(doc): root_n
|> koru/yyjson:new.string(doc, text: "search-api"): svc_n
|> koru/yyjson:object.set(doc, v: root_n, key: "service", value: svc_n)
|> koru/yyjson:new.int(doc, value: 8443): port_n
|> koru/yyjson:object.set(doc, v: root_n, key: "port", value: port_n)
|> koru/yyjson:root.set(doc, v: root_n)
|> koru/yyjson:render(doc)
| ok body |> std/io:print.ln("{{ body:s }}") |> koru/yyjson:render.free(text: body) |> koru/yyjson:build.close(doc)
| err e |> std/io:print.ln("render failed: {{ e.msg:s }}") |> koru/yyjson:build.close(doc)
```

Fifteen write entry points: `build`, `build.close`, `new.object`,
`new.array`, `new.string`, `new.int`, `new.double`, `new.bool`, `new.null`,
`object.set`, `array.push`, `root.set`, `render`, `render.pretty`,
`render.free`.

**Two obligations, because C has two frees.** `yyjson_mut_write` returns a
buffer from *libc's* allocator, not from the document's arena, so a C caller
owes both `yyjson_mut_doc_free` and `free` — and the rendered string is the
one people forget, because closing the doc feels like finishing the job. Here
`build` mints `*Builder<open!>` (discharged by `build.close`) and `render`
mints `string<rendered!>` (discharged by `render.free`), and dropping either
is a KORU030 build failure:
`tests/negative_forgotten_build_close.kz`,
`tests/negative_forgotten_render_free.kz`.

Keeping the rendered string off the arena is deliberate, not incidental: it
is what lets you render a request body, close the builder, and only then hand
the string to an HTTP tor. An arena-owned buffer would make that ordering a
use-after-free.

**Assembly does not branch, and that is on purpose.** `object.set` /
`array.push` are single-path. A `*Node`'s shape is fixed by the `new.*` that
minted it — nothing hands you a Node out of parsed data — so a wrong-shape
target is a programmer error, not a data condition, and this file's rule
(read off the read side) is that data conditions branch and programmer errors
abort. A `| not-an-object` arm would be unreachable by construction, written
by rote, filled with the same cleanup as the happy path, and would therefore
turn a node mixup into a *silently missing field* — while burying `render`'s
genuinely-reachable `err` under a ten-deep pyramid of arms that cannot fire.
See index.kz's "Assembly" section.

**Escaping is the whole point.** `tests/kopium_body_parity.kz` reproduces
kopium's exact body with the write tors and compares it byte-for-byte against
that file's escape loop, transcribed verbatim, on a prompt containing a
double quote, a backslash, a newline, a tab, and two non-ASCII characters:

```
hand-rolled: {"model":"anthropic/claude-haiku-4.5","stream":true,"messages":[{"role":"user","content":"she said \"go\\stop\"\n\tnål ✓"}]}
yyjson     : {"model":"anthropic/claude-haiku-4.5","stream":true,"messages":[{"role":"user","content":"she said \"go\\stop\"\n\tnål ✓"}]}
agree      : true
```

`render` passes `YYJSON_WRITE_NOFLAG` deliberately. `ESCAPE_UNICODE` would
turn `å` into `\u00e5` and `ESCAPE_SLASHES` would turn
`anthropic/claude-haiku-4.5` into `anthropic\/claude-haiku-4.5`. Both are
legal JSON; neither is what the hand-rolled body produces, and silently
differing from the obvious output is how a drop-in replacement stops being
one.

(One honest asymmetry: the hand-rolled loop *drops* control bytes below 0x20
other than `\n`/`\t`, silently corrupting the text. `render` escapes them as
`\uXXXX`, which is correct. The two therefore agree on every input the
hand-rolled version handles correctly, and differ exactly where it was
already wrong.)

## The quadrifecta self-audit

- **DX**: A newcomer never learns that yyjson has an arena, a `yyjson_val`
  tag byte, or a subtype encoding. Object/array navigation is
  `object.get`/`array.get` returning `found`/`not-found` and
  `found`/`out-of-range`; iteration is `array.each`/`object.each` with a
  `! item`/`! entry` body identical in shape to sqlite3's `! row` and pcre2's
  `! match`; scalar extraction is `as.string`/`as.int`/`as.double`/`as.bool`
  returning `ok`/`wrong-type` — never a silently-defaulted `0` or `""`
  (`tests/features.kz` case 2 exercises this: reading a number as a string
  gives a loud `wrong-type`, not `"0"`). The one obligation the caller must
  fulfill — `close` — is either written by hand (`tests/basic.kz`) or
  inserted by the compiler's auto-discharge pass at every branch exit
  (`examples/read_config.kz` carries an explicit `close` at each leaf; see
  `tests/negative_forgotten_close.kz` for the same call *without* one,
  compiling clean by default). The write side mirrors that vocabulary
  (`new.*` against `as.*`, `object.set` against `object.get`, `array.push`
  against `array.get`, `root.set` against `root`) and reads as one flat
  chain: `examples/build_request.kz` builds a two-message nested request in
  a single unbroken `|>` sequence with exactly one branch, the render.

- **Performance**: `Value` (index.kz:101) and `Node` (index.kz:383) are
  direct type aliases for `c.yyjson_val` / `c.yyjson_mut_val` — **no wrapper
  struct, no per-navigation or per-node heap allocation**.
  `root`/`object.get`/`array.get`/`array.each`/`object.each` all return or
  yield the raw yyjson arena pointer directly; reading a value through this
  lift costs exactly one call into yyjson's own inline accessor, identical to
  calling libyyjson from C by hand. `new.*` likewise returns yyjson's own
  `yyjson_mut_val *` straight out of the document arena. The lifting —
  doc-lifetime safety, wrong-type rejection — happens entirely in the
  phantom-obligation type system at compile time; there is no runtime tax, no
  shadow struct, no extra indirection. The one deliberate copy is
  `new.string`/`object.set` using `yyjson_mut_strncpy` rather than
  `yyjson_mut_strn`: a koru string is a borrowed, unterminated slice with no
  promise to outlive the document, so the document takes its own copy — that
  is a correctness requirement, not an oversight. UNMEASURED against a raw-C
  baseline (no formal benchmark run this session) — the claim is "no added
  runtime cost by construction," not a benchmarked number.

- **Correctness**: Wrong-type reads are a build-honest `wrong-type` branch,
  never a silently-coerced value — yyjson's own `yyjson_get_str`/`get_sint`/
  `get_num`/`get_bool` return `NULL`/`0`/`0.0`/`false` on a type mismatch,
  which this lift refuses to expose directly (index.kz `as.*` procs check
  `yyjson_is_*` or a `NULL` return before ever handing back a value).
  Malformed JSON is a loud `err` carrying yyjson's own error code, byte
  offset, and message (`tests/features.kz` case 5: `parse(text: "{bad}")` →
  `bad json at byte 1: unexpected character, expected a string key`), never a
  null document. **Use-after-close is a build error**:
  `tests/negative_use_after_close.kz` calls `root(doc)` after `close(doc)`
  and fails with `error[KORU030]: Use-after-discharge: binding 'doc' was
  already discharged and cannot be used`; the write-side mirror,
  `tests/negative_use_after_build_close.kz`, calls `new.object(doc)` after
  `build.close(doc)` and fails with the same diagnostic. On the write side
  correctness *is* escaping, and it is proven by comparison rather than
  asserted: `tests/kopium_body_parity.kz` prints kopium's hand-rolled body
  and this lift's side by side and reports `agree: true` (see "The write
  path"). The one divergence found is in the hand-rolled version's favour to
  discover and against it on the merits — given a prompt containing `\x07`
  and `\x01`, the hand-rolled loop emits `"bell: soh: done"`, silently
  deleting both bytes, while `render` emits `"bell:\u0007 soh:\u0001 done"`.
  The lift is not merely as correct as the code it replaces; it is more so.

- **Resource safety**: Two obligations, both enforced end-to-end.
  `tests/negative_forgotten_close.kz` run with `--auto-discharge=disable`
  fails with `error[KORU030]: Resource '_' carries obligation <open!> was not
  discharged. Call: koru.yyjson:close` — under default settings the same file
  compiles clean because auto-discharge inserts the missing `close` for you.
  Every value reader (index.kz: `root` at line 157, `object.get` at 172,
  `array.get` at 188, `array.each` at 211, `object.each` at 240, the four
  `as.*` tors at 268/281/291/301) takes `doc: *Doc<open>` — the compiler
  requires the caller to still hold the live obligation on that binding, so a
  value obtained before `close` cannot be read after it
  (`tests/negative_use_after_close.kz`, proven above). Per-iteration values
  handed to `array.each`'s `! item` and `object.each`'s `! entry` are borrows
  into the doc's arena, valid for the loop's duration — there is no
  additional obligation to track on `Value` itself because `Value` carries no
  allocation of its own (it is a raw pointer alias, see Performance above):
  its only lifetime constraint is the doc's, which the `doc: *Doc<open>`
  parameter on every reader already enforces.

  The write side adds the second obligation, and it is the one that carries
  its weight. `build` mints `*Builder<open!>` (index.kz:394, discharged at
  403) and every write tor borrows `doc: *Builder<open>` on the same rule.
  `render` (index.kz:555) mints `string<rendered!>`, discharged by
  `render.free` (593) — a *separate* obligation because yyjson allocates that
  buffer from libc, not the arena, so `build.close` does not and cannot free
  it. Both refusals are demonstrated, not asserted:
  `tests/negative_forgotten_build_close.kz` →
  `Resource 'doc' carries obligation <open!> was not discharged. Call:
  koru.yyjson:build.close`; `tests/negative_forgotten_render_free.kz` (which
  closes the builder correctly and only drops the string) →
  `Resource 'body' carries obligation <rendered!> was not discharged. Call:
  koru.yyjson:render.free`.

  Confirmed at runtime as well as at compile time. `leaks --atExit` on
  `examples/build_request.kz`'s binary — two renders, two frees, one close —
  reports `0 leaks for 0 total leaked bytes`. The instrument is not
  vacuous: the same C sequence with only the `free(buf)` removed reports
  `1 leak for 512 total leaked bytes`, stack
  `ROOT LEAK: <realloc in yyjson_mut_write_opts_impl>`. That leak is exactly
  what `rendered!` makes unwritable.

## What it explicitly doesn't do (yet)

- **No file I/O.** `yyjson_read_file` / `yyjson_mut_write_file` are not
  bound: koru already has `std/io:read-file`, and a second, JSON-flavoured
  file API earns nothing but a second way to get paths wrong.
- **No immutable/mutable bridge.** `yyjson_doc_mut_copy` and
  `yyjson_mut_doc_imut_copy` would let you parse a document, edit it, and
  write it back. Not bound, and the omission is load-bearing rather than
  lazy: it is what makes a `*Node`'s shape statically knowable, which is the
  premise the single-path `object.set` / `array.push` rest on. Binding the
  bridge later means revisiting that decision honestly, not bolting it on.
- **No JSON Pointer, Patch, or Merge-Patch** (`yyjson_ptr_*`,
  `yyjson_patch`, `yyjson_merge_patch`). Real surface, genuinely useful, and
  a separable pass — not started rather than half-done.
- **No unsigned 64-bit integers.** There is no `new.uint`, because there is
  no `as.uint` on the read side to mirror; values above `i64`'s range are
  unreachable in *both* directions. A symmetric hole, closed in one pass when
  someone needs it, not a silent truncation.
- **No write flags but `PRETTY`.** `render` is compact,
  `render.pretty` is 4-space indented, and that is the whole surface.
  `ESCAPE_UNICODE`, `ESCAPE_SLASHES`, `ALLOW_INF_AND_NAN`,
  `NEWLINE_AT_END` and friends are deliberately not exposed — see "Escaping
  is the whole point" above for why the default matters, and note that an
  `flg: i32` escape hatch would have made that guarantee unstatable.
- **No compile-time schema validation.** `ECOSYSTEM.md`'s "Koru advantage"
  note for JSON also names validating an expected document shape at the type
  boundary — that would need a comptime DSL in the shape of
  `koru_std/regex.kz`'s `analyze` + compile-error pattern. Out of scope for
  v0; the runtime `wrong-type`/`not-found` branches are the honest fit for
  "the shape isn't known until parse time" until that lands.
- **No asymmetric "must read before close" barrier.** Unlike gzip's `fed`
  gate (init → finish with nothing fed is a compile error), `parse → close`
  with zero reads in between is a **legitimate** use here — validating that a
  blob is well-formed JSON without reading any value is a real, honest use
  case, not a meaningless no-op the way an unfed compressor is. This was
  considered and deliberately not copied: the RAII-blind-spot pattern only
  belongs where doing no work in between really is meaningless, and JSON
  parsing doesn't have that property.
- **No JSON5/JSONC/comments, no in-situ zero-copy parsing
  (`YYJSON_READ_INSITU`), no custom allocators, no number-as-raw / bignum
  modes.** `parse` calls `yyjson_read_opts` with flag `0` — vanilla RFC 8259
  JSON only. All scoped-out v0 surface, not defects.
- **`object.get`/`array.get` are O(n) / O(1)-when-flat respectively** — this
  is yyjson's own documented complexity (`yyjson_obj_get`: "takes a linear
  search time"; `yyjson_arr_get`: O(1) for a flat array, linear otherwise),
  inherited as-is, not something this lift changes.

## Toolchain findings

Three findings surfaced building this lift: two in the Koru compiler, one in
Zig's `@cImport` translate-c layer consuming yyjson.h directly (confirmed with
a standalone `zig run`, no Koru involved at all). All are floated here, not
fixed — this is a library submission, not a compiler change — and the lift
ships cleanly around each with the gap stated.

### Finding 1 (Koru) — an effect-branch event's own parameter name is reused verbatim as the inlined local, with no hygiene

Building this lift's `array.each`/`object.each` (this catalog's second and
third users of an effect-branch (`!`) producer wrapping a C library end-to-end
through codegen, after pcre2's `find.all`) surfaced this **new** compiler
defect, distinct from the two pcre2 already found and floated in its own
README.

An effect-branch producer's proc body is inlined directly into the *caller's*
frame at the call site (this is by design — it's how `! item`/`! match`
zero-cost iteration works). When the call site passes an argument under a
**different** identifier than the callee's own declared parameter name, the
inliner emits `const <param_name> = (<arg_expr>);` using the callee's literal
declared parameter name — with no gensym, no mangling, no hygiene at all. If
the *caller* already has an unrelated local bound to that exact same
identifier anywhere earlier in the same flow function, Zig's no-shadowing
rule turns two individually-correct, unrelated pieces of code into a hard
compile error.

Concretely: this package's `array.each` declares a parameter named `v`
(`array.each { doc: *Doc<open>, v: *Value }`, index.kz:197). A caller who
separately bound a local named `v` earlier in the same flow (e.g. via
`root(doc): v`, an entirely unremarkable and unrelated binding) and then calls
`array.each(doc, v: some_other_name)` downstream hits:

```
output_emitted.zig:140:35: error: local constant 'v' shadows local constant from outer scope
output_emitted.zig:132:23: note: previous declaration here
```

This is **not** yyjson-specific and **not** a shape/type problem — it is a
pure core-language hygiene gap, confirmed by reproducing it with two trivial
events that have nothing to do with JSON or FFI (below). Note this is a
*different* defect from pcre2's Finding 1 (module `c`/type refs being out of
scope at the inlined site) — that one is about *module-level* declarations;
this one is about the inliner's *own parameter binding* colliding with an
arbitrary *caller-local* of the same name, several call-frames removed from
anything the library controls. Also note it does **not** reproduce for plain
(non-effect-branch) events — `object.get`'s `v` parameter never collided in
testing, because non-effect calls are threaded through a `.handler(.{...})`
struct call rather than inlined with fresh `const` rebindings of each
parameter name.

**Minimal repro**: `tests/TOOLCHAIN_REPRO_effect_param_shadow.kz` — two events
(`get-count -> i32` and an effect-branch `each-i32`, both taking/returning
plain `i32`, zero C imports) reproduce the identical
`local constant 'v' shadows local constant from outer scope` error. This is
excluded from `LIFT_IDIOMS.md` generation (it names a compiler defect that
rejects *correct* code, the opposite of a footgun demonstration).

**Ship-around**: chosen distinctive local variable names in this package's
own tests/examples (`root_v` rather than `v`) so no caller-side binding
collides with the library's own effect-branch parameter names. This is an
ordinary, unremarkable naming discipline (not an API change, not a scope
hack) — but it is fragile for *downstream* callers in general: any consumer
of `array.each`/`object.each` who happens to independently choose a local
named exactly `v` anywhere earlier in the same flow will hit this wall with
no koru-level diagnostic pointing at the cause, only a raw generated-Zig
shadow error. The real fix belongs in the compiler's effect-branch inliner
(gensym/mangle inlined parameter bindings so they can never collide with
caller scope) and is out of scope for this library submission.

### Finding 2 (Zig, not Koru) — `@cImport` mistranslates yyjson's bit-packed `unsafe_yyjson_get_bool`

Calling `c.yyjson_get_bool(v)` from `as.bool`'s first draft failed the *Zig*
build (not the koru frontend — `koruc --check` and shape-checking both passed
clean) with:

```
cimport.zig:6330:154: error: expected type 'bool', found 'c_int'
    return @as(bool, (@as(c_int, @bitCast(@as(c_uint, tag))) & ...) >> ...);
cimport.zig:1405:115: note: called inline here
    ... unsafe_yyjson_get_bool(@as(?*anyopaque, @ptrCast(val))) ...
```

`yyjson_get_bool` is a `static inline` C function whose body
(`unsafe_yyjson_get_bool`, yyjson.h ~4945) reads a bitfield-packed tag byte
(`(bool)((tag & YYJSON_SUBTYPE_MASK) >> YYJSON_TYPE_BIT)`) — Zig's
`translate-c` mis-translates this specific shift-and-cast idiom into an
expression typed `c_int` where a `bool` was expected, and the generated
`cimport.zig` itself fails to compile. **Confirmed independent of Koru**: a
standalone two-line `zig run` against `yyjson.h` (no koru, no library code)
reproduces the identical `cimport.zig` failure at the identical line, calling
nothing but `c.yyjson_get_bool` directly. This is a Zig `translate-c`
limitation consuming yyjson's header, not a Koru toolchain defect and not a
library bug in the ordinary sense — it lives entirely inside `zig build-exe`'s
own C-import machinery, upstream of anything this lift or the koru compiler
controls.

**Ship-around**: `yyjson_val`'s own public layout (`struct { tag: u64, uni:
yyjson_val_uni }`, yyjson.h ~4765) and its plain-arithmetic tag-bit macros
(`YYJSON_SUBTYPE_MASK`, `YYJSON_TYPE_BIT`) **do** survive translate-c cleanly
— only the one inline *function body* combining them breaks. `as.bool`
(index.kz) replicates that one broken accessor's documented logic directly
against `v.tag` instead of calling it:
`((v.tag & c.YYJSON_SUBTYPE_MASK) >> c.YYJSON_TYPE_BIT) != 0`. `yyjson_is_bool`
itself is unaffected (confirmed working in the same probe) — only
`yyjson_get_bool` is broken, so `as.bool` still uses the real
`yyjson_is_bool` for its type check and only hand-rolls the value extraction.

### Finding 3 (Koru) — an indented branch arm after a `|>` continuation line is silently swallowed

Surfaced writing `examples/build_request.kz`: a build chain is a long flat
sequence of `|>` steps and wants to wrap across lines. Bisecting the four
combinations gives a crisp rule:

| head | branch arms | result |
| --- | --- | --- |
| one line | indented | OK (`examples/read_config.kz`) |
| one line | column 0 | OK |
| leading-`\|>` continuation | column 0 | OK (`examples/build_request.kz`) |
| leading-`\|>` continuation | indented | **broken** |

In the broken case the FIRST indented arm is absorbed into the chain with no
diagnostic at all — it simply never fires — and every arm after it is
reported as:

```
error[KORU010]: stray continuation line without Koru construct
  --> ...:6:5
    |
  6 |     | not-found |> std/io:print.ln("nf")
    |     ^
```

The diagnostic points at the second arm and blames it for being stray, which
is exactly the wrong place: the first arm is where the association was lost,
and it is the one that says nothing. Repro with `std/io` only, no yyjson:
`tests/TOOLCHAIN_REPRO_indented_branch_after_continuation.kz`.

**Separately, in the same bisect**: a TRAILING-`|>` continuation (`foo() |>`
at end of line, next call on the following line) is *miscompiled* even with
no branches at all, emitting Zig that fails with `output_emitted.zig:N:M:
error: expected ',' after field`. Leading-`|>` is the form that works;
trailing-`|>` should be a parse error rather than bad codegen.

**Ship-around**: `examples/build_request.kz` wraps its head chain with
leading `|>` and puts the top-level arms at column 0. Nested arms under a
branch arm are unaffected and stay indented as usual.

### Observation (environment, not a defect) — occasional stale-cache flakiness under rapid back-to-back builds

While verifying this package, one `koruc run` of `tests/features.kz` failed
transiently with an unrelated `Use-after-discharge` diagnostic immediately
after many other `koruc` invocations had run in rapid succession against the
same `yyjson/tests/` directory (this package's own `LIFT_IDIOMS.md` generator
run, plus manual verification). Deleting every generated artifact
(`.zig-cache/`, `zig-out/`, `backend.zig`, `output_emitted.zig`, etc.) and
re-running the identical command immediately succeeded with fully correct
output, and every subsequent re-run has been consistent. This reads as
build-cache non-determinism (most plausibly Zig's shared `--global-cache-dir`
being reused across rapidly-successive builds targeting the same output
binary names from different source files), not a language/compiler
correctness defect — no source or generated diagnostic pointed at this
package's actual code. Noted here rather than silently ignored; not filed as
one of the two toolchain findings above because it was not reproducible in
isolation.

The same overload (this package was built on a shared machine running four+
concurrent contestant sessions, each spawning full metacircular `zig` builds —
observed load average **70**, 14 simultaneous `koruc`/`zig build-exe`
processes) also surfaced a genuine, if minor, **koruc robustness gap worth its
own line**: when the OS signal-kills koruc's child `zig build` subprocess
(OOM-killer under memory pressure), koruc panics with `thread N panic: access
of union field 'Exited' while field 'Signal' is active` instead of reporting
"the build subprocess was killed by signal N." That is a raw host-level panic
leaking to the user where a clean koru-level diagnostic belongs — koruc's
build-orchestration reads the child's `Term` union assuming `.Exited` without
handling the `.Signal` case. It only triggers under resource exhaustion (so it
is not a per-package defect and the same file builds+runs clean in isolation),
but the fix is a real one-liner in koruc's subprocess-wait handling: branch on
the `Term` tag and emit a proper "child killed by signal" diagnostic. Floated,
not chased — it is orthogonal to this lift.

## Proof of life

```
$ koruc --check yyjson/index.kz
✓ Shape checking passed

$ koruc run yyjson/tests/basic.kz
...
name: ada
age: 36
tag: math
tag: computing
done

$ koruc run yyjson/tests/features.kz
...
x = 1
y = 2
age as string: wrong-type
missing: not-found
second tag: computing
index out of range
pi = 3.5
active = true
bad json at byte 1: unexpected character, expected a string key
done

$ koruc run yyjson/examples/read_config.kz
...
service: search-api
port: 8443
tag: prod
tag: us-east

$ koruc run yyjson/tests/negative_use_after_close.kz
error[KORU030]: Use-after-discharge: binding 'doc' was already discharged and cannot be used

$ koruc yyjson/tests/negative_forgotten_close.kz --auto-discharge=disable
error[KORU030]: Resource '_' carries obligation <open!> was not discharged. Call: koru.yyjson:close

$ koruc yyjson/examples/build_request.kz && ./a.out
compact: {"model":"anthropic/claude-haiku-4.5","stream":true,"messages":[{"role":"user","content":"how do I escape a \" in JSON?"},{"role":"assistant","content":"you don't — the writer does\nit for you"}]}
pretty:
{
    "model": "anthropic/claude-haiku-4.5",
    "stream": true,
    "messages": [
        {
            "role": "user",
            "content": "how do I escape a \" in JSON?"
        },
        {
            "role": "assistant",
            "content": "you don't — the writer does\nit for you"
        }
    ]
}

$ koruc yyjson/tests/kopium_body_parity.kz && ./a.out
hand-rolled: {"model":"anthropic/claude-haiku-4.5","stream":true,"messages":[{"role":"user","content":"she said \"go\\stop\"\n\tnål ✓"}]}
yyjson     : {"model":"anthropic/claude-haiku-4.5","stream":true,"messages":[{"role":"user","content":"she said \"go\\stop\"\n\tnål ✓"}]}
agree      : true

$ leaks --atExit -- ./a.out            # examples/build_request.kz binary
Process: 0 leaks for 0 total leaked bytes.

$ koruc yyjson/tests/negative_forgotten_build_close.kz --auto-discharge=disable
error[KORU030]: Resource 'doc' carries obligation <open!> was not discharged. Call: koru.yyjson:build.close

$ koruc yyjson/tests/negative_forgotten_render_free.kz --auto-discharge=disable
error[KORU030]: Resource 'body' carries obligation <rendered!> was not discharged. Call: koru.yyjson:render.free

$ koruc yyjson/tests/negative_use_after_build_close.kz
error[KORU030]: Use-after-discharge: binding 'doc' was already discharged and cannot be used

$ koruc yyjson/tests/TOOLCHAIN_REPRO_effect_param_shadow.kz   # toolchain finding, expected to fail
output_emitted.zig:102:19: error: local constant 'v' shadows local constant from outer scope

$ koruc yyjson/tests/TOOLCHAIN_REPRO_indented_branch_after_continuation.kz   # toolchain finding, expected to fail
error[KORU010]: stray continuation line without Koru construct
```
