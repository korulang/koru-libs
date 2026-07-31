# yyjson — the definitive Koru yyjson edition

**One-line pitch**: The fastest conformant JSON library, wrapped so a value
read from a freed document is a compile error instead of a dangling pointer.

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

Eleven entry points, every one requiring the doc's live obligation to touch a
value: `parse`, `close`, `root`, `object.get`, `array.get`, `array.each`,
`object.each`, `as.string`, `as.int`, `as.double`, `as.bool`.

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
  compiling clean by default).

- **Performance**: `Value` (index.kz:87) is a direct type alias for
  `c.yyjson_val` — **no wrapper struct, no per-navigation heap allocation**.
  `root`/`object.get`/`array.get`/`array.each`/`object.each` all return or
  yield the raw yyjson arena pointer directly; reading a value through this
  lift costs exactly one call into yyjson's own inline accessor, identical to
  calling libyyjson from C by hand. The lifting — doc-lifetime safety,
  wrong-type rejection — happens entirely in the phantom-obligation type
  system at compile time; there is no runtime tax, no shadow struct, no extra
  indirection. UNMEASURED against a raw-C baseline (no formal benchmark run
  this session) — the claim is "no added runtime cost by construction," not a
  benchmarked number.

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
  already discharged and cannot be used`.

- **Resource safety**: The `open` obligation on `Doc` is enforced end-to-end.
  `tests/negative_forgotten_close.kz` run with `--auto-discharge=disable`
  fails with `error[KORU030]: Resource '_' carries obligation <open!> was not
  discharged. Call: libs.yyjson:close` — under default settings the same file
  compiles clean because auto-discharge inserts the missing `close` for you.
  Every value reader (index.kz: `root` at line 143, `object.get` at 158,
  `array.get` at 174, `array.each` at 197, `object.each` at 226, the four
  `as.*` procs after that) takes `doc: *Doc<open>` — the compiler requires
  the caller to still hold the live obligation on that binding, so a value
  obtained before `close` cannot be read after it
  (`tests/negative_use_after_close.kz`, proven above). Per-iteration values
  handed to `array.each`'s `! item` and `object.each`'s `! entry` are borrows
  into the doc's arena, valid for the loop's duration — there is no
  additional obligation to track on `Value` itself because `Value` carries no
  allocation of its own (it is a raw pointer alias, see Performance above):
  its only lifetime constraint is the doc's, which the `doc: *Doc<open>`
  parameter on every reader already enforces.

## What it explicitly doesn't do (yet)

- **No serialization / write path.** This is a read-only v0 (`yyjson_read_*`
  only) — no `yyjson_mut_doc`, no building a tree, no `yyjson_write`. A
  webserver still needs this for response bodies; it is the natural next
  depth pass and was cut to keep this v0 narrow (parse-and-query is the
  single biggest named gap in `ECOSYSTEM.md`; write is a second, separable
  one).
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

Two findings surfaced building this lift: one in the Koru compiler, one in
Zig's `@cImport` translate-c layer consuming yyjson.h directly (confirmed with
a standalone `zig run`, no Koru involved at all). Both are floated here, not
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

$ koruc run yyjson/tests/negative_forgotten_close.kz --auto-discharge=disable
error[KORU030]: Resource '_' carries obligation <open!> was not discharged. Call: libs.yyjson:close

$ koruc run yyjson/tests/TOOLCHAIN_REPRO_effect_param_shadow.kz   # toolchain finding, expected to fail
output_emitted.zig:102:19: error: local constant 'v' shadows local constant from outer scope
```
