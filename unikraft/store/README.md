# `unikraft/store` — Unikraft's run-time object registry, lifted

```koru
~import unikraft/store

~unikraft/store:alloc(name: "demo", id: 1)
| ready obj |> unikraft/store:add(obj)
    | ok held |> unikraft/store:entry.static(library_id: print_id, entry_id: 1)
        | found lvl |> unikraft/store:get.u8(entry: lvl)
            | ok level |> …
```

`lib/ukstore` is a refcounted object/entry registry: any library can publish
named, typed "entries" — a getter + setter pair over one of ten scalar types —
either STATICALLY at C compile time (`UK_STORE_STATIC_ENTRY`, a linker-section
trick; `ukprint/store.c` ships a real one, `console_lvl`) or DYNAMICALLY at
run time, grouped into an `object` that other code looks up by
`(library id, object id)` and must acquire/release like a reference-counted
handle. 39 allowlist lines, **zero `static inline`s** — the whole surface
links, unlike every other lift in this catalog, none of which needed to prove
a mirror or work around an unreachable inline for this one. The shelf's own
words: "nothing shipped has this shape."

---

## The ratchet

One object handle, two live states:

```
alloc    mints  <built!>                          uk_store_obj_alloc
add      needs  <!built>   mints <held!>           _uk_store_obj_add
acquire  (lookup, no input obligation) mints <held!>  uk_store_obj_acquire
release  needs  <!held>                            uk_store_obj_release
```

### The asymmetry is not optional here — it is load-bearing against a real bug

`uk_store_obj_alloc` (`store.c:188-299`) never initializes `object->libid`.
`_uk_store_obj_add` (`store.c:301-322`) is the ONLY function that sets it:
`object->libid = library_id;`. `uk_store_obj_release` (`store.c:344-361`)
indexes `dynamic_heads[object->libid]` UNCONDITIONALLY, with no bounds check
and no assertion on `libid` at all. So `alloc(); release();` — skip `add` —
is not a benign no-op the way an unused `unikraft/alloc:take` block is: it is
a read through an uninitialized field used as an array index, in a build
where `UK_ASSERT` is compiled out either way. `release` therefore accepts
only `<!held>`, and the only two mints of `<held!>` are `add` and `acquire`.
`tests/negative_release_without_add.kz` is the refusal.

---

## THE MISMATCH — refcounting is a count; an obligation is a claim about one binding

Pillar 4's asymmetry and every ratchet shipped before this one model a
**single linear owner**: one handle, one obligation, one consumer. A refcount
is not that. `uk_store_obj_acquire`'s own doc comment says "Every call must
be paired with a call to uk_store_obj_release()", and the C is explicit that
MANY independent callers may hold the same underlying object at once.

Koru's phantom-obligation wall tracks obligations per **binding**, not per
address (`src/auto_discharge_inserter.zig`, confirmed independently by
`unikraft/alloc`'s README correction). That turns out to fit better than it
looks at first: every `acquire` mints a FRESH, independent `<held!>` binding,
and the wall demands each one be individually `release`d — which is exactly
the C's own contract, word for word. `tests/boot_store.kz` proves this is not
a claim: the SAME object is acquired twice through two independently-typed
bindings (`held` from `add`, `held2` from `acquire`), and the console shows
both being released.

**What the wall cannot give you, stated plainly rather than smoothed over:**

- **The count.** Nothing in the type system knows there are N live holders,
  only that each minted `<held!>` has a `release` somewhere in its future.
  Whether a given `release` is the one that actually frees the C object
  (refcount reaches 0) or merely decrements it is a runtime fact the C alone
  decides; Koru has no phantom state for "the last one."
- **Aliasing.** Two `*Object<held!>` bindings from two `acquire` calls on the
  same `object_id` are, to the type system, two unrelated proofs. Nothing
  stops a program from acquiring the same id twice and treating both handles
  as independent — which, semantically, IS what refcounting means, so this is
  not a gap, it is the accurate shape of "shared ownership": proven
  individually, never proven related.
- **A single-holder ratchet — `unikraft/lock`'s shape — would be actively
  WRONG here.** Refcounting exists so many holders are simultaneously legal;
  restraining that would be `unikraft/lock`'s own restraint rule applied to
  the one place it does not belong.

So: the fit is good for "every acquisition is paired," and structurally
unable to speak to "how many, and is this the last." That is the honest
ceiling of a per-binding obligation system applied to a resource whose
defining feature is that many bindings legitimately alias one address — not
a half-finished ratchet.

---

## The typed getter/setter matrix — why it is hand-written, not generated

Ten storage types (`s8, u8, s16, u16, s32, u32, s64, u64, uptr, charp`) each
get their own C function — `_uk_store_get_u8`, `_uk_store_get_s8`, … —
because the C itself has no generics either. `_UK_STORE_DYNAMIC_CREATE_TYPED`
(`store.c:74-111`) is a preprocessor `##`-token-pasting macro invoked ONCE
PER TYPE, ten times, at the C SOURCE level, to physically emit ten distinct
functions with ten distinct names.

Koru's own ruled doctrine
(`project_generics_are_a_comptime_codegen_library`, Lars, 2026-06-13) is that
Koru will never grow language-level generics: a "generic" surface is a
`[transform]` library that takes a type as an opaque `expr: Expression` **at
each call site** and monomorphizes there (`std/list:new(i64)`). That
mechanism does not fit this shape. The ten types here are not a caller
choosing a type per call site — they are a closed, fixed, already-named set
of ten C symbols the library shipped once, at ITS OWN source level, the same
way `koru_std`'s own transforms specialize a collection per instantiation
site rather than per program. There is no evidence in the shipped test suite
of a Koru-level construct that mints N sibling top-level `~tor`/`~proc`
declarations from a compile-time loop over a data table — that would be
declaration-generation, a stronger and different claim than `std/list:new`'s
per-call-site specialization — and I did not find one and am not inventing
one; ground every construct in a passing test or say it is a guess, and this
is a guess I chose not to make.

So the twenty tors (`get.u8` … `set.charp`) are **hand-written**, one per C
symbol — the same ratio the C itself has at its own source level (one macro
invocation per type, not one generic function). Ten pairs, each a call, an
error check, a wrap; duplicating that ten times is the honest cost of a
closed enumerable matrix in a language whose stance is "no language
generics."

---

## `UK_ASSERT` census

Counted with `grep -rn UK_ASSERT store.c include/uk/store.h` against
`unikraft` HEAD `3fdffba8`. **28 assertions**, matching the shelf row.

### Retired — 25 of 28, one rule

All 25 are the shape `UK_ASSERT(name)` / `UK_ASSERT(entries)` /
`UK_ASSERT(object)` / `UK_ASSERT(e)` — a non-null check on a parameter that,
in this lift, can only ever arrive from a validated, typed Koru source: a
`string` binding's `.ptr`, a fixed static array this lift itself constructs,
a phantom-typed `*Object` reachable only from a live obligation, or a
`*const StoreEntry` reachable only from `entry.get`/`entry.static`'s `found`
arms. None of these is independently fabricable at the Koru surface — the
same argument `unikraft/blk`, `unikraft/alloc` and `unikraft/lock` already
made for their own null-pointer families, applied here to every bound entry
point.

| where | function | tor |
|---|---|---|
| `store.c:195` | `uk_store_obj_alloc`, `UK_ASSERT(name)` | `alloc` |
| `store.c:196` | `uk_store_obj_alloc`, `UK_ASSERT(entries)` | `alloc` |
| `store.c:305` | `_uk_store_obj_add`, `UK_ASSERT(object)` | `add` |
| `store.c:348` | `uk_store_obj_release`, `UK_ASSERT(object)` | `release` |
| `store.c:381` | `uk_store_obj_entry_get`, `UK_ASSERT(object)` | `entry.get` |
| `store.c:472,510,548,585,623,661,699,737,775,814` | `_uk_store_set_{u8,s8,u16,s16,u32,s32,u64,s64,uptr,charp}`, `UK_ASSERT(e)` (×10) | `set.*` |
| `store.c:1048,1092,1136,1180,1224,1268,1312,1356,1400,1449` | `_uk_store_get_{u8,s8,u16,s16,u32,s32,u64,s64,uptr,charp}`, `UK_ASSERT(e)` (×10) | `get.*` |

2 + 1 + 1 + 1 + 10 + 10 = **25**.

### Not retired — 3 of 28, surfaces this module does not bind

| where | function | why not |
|---|---|---|
| `store.c:85` | `_UK_STORE_DYNAMIC_CREATE_TYPED` macro body (`_uk_store_create_dynamic_entry_*`, ×10 symbols) | not declared in `store.h` at all; not a sanctioned direct-call surface. Binding it would mean re-implementing the part of `uk_store_obj_alloc` that already calls it correctly. |
| `store.c:1650` | `_uk_store_get_ncharp`, `UK_ASSERT(e)` | scope-cut: one more symbol on the same closed matrix, no new shape. |
| `store.c:1651` | `_uk_store_get_ncharp`, `UK_ASSERT(out)` | same. |

### Net

| | count |
|---|---:|
| retired — non-null on a structurally-validated parameter | **25** |
| not retired — surfaces not bound | **3** |
| **total** | **28** |

**25 of 28 retired, 3 not.** A larger number is not available here the way it
was for `unikraft/alloc`'s group C — this library's bound surface really is
almost all of its ordering-relevant assertions, because almost every
assertion in `ukstore` is the SAME null-pointer rule repeated per type rather
than a distinct ordering rule per function.

And the qualifier every entry in this catalog states: `UK_ASSERT` compiles to
`do {} while(0)` when `CONFIG_LIBUKDEBUG_ENABLE_ASSERT` is off, which it is in
every image measured here. What changes is that the guarantee these 25
describe now holds in the shipped image too, where before it held only in a
debug build.

---

## Gate 1 — `--check`

```
$ koruc --check unikraft/store/index.kz
✓ Shape checking passed
```

## Gate 2 — it boots

Full recipe, run clean in an empty directory (traps and their evidence:
`/Users/larsde/src/koru/examples/unikraft/BUILD.md`):

```sh
mkdir /tmp/store && cp -R unikraft /tmp/store/
cd /tmp/store/unikraft/store/tests

koruc boot_store.kz unikraft gen        # -> Makefile.uk + Kraftfile
koruc boot_store.kz                     # -> output_emitted.zig
                                        #    (the host link then fails on the
                                        #     Unikraft symbols; that is expected)
zig build-lib wrapper.zig \
    -target x86_64-freestanding -O ReleaseSmall \
    -fno-stack-protector -femit-bin=libkoruapp.a
UK_CFLAGS="-std=gnu17" kraft build --arch x86_64 --plat qemu --no-prompt

qemu-system-x86_64 -kernel .unikraft/build/koru_qemu-x86_64 \
  -cpu 'qemu64,+pdpe1gb,+rdrand,+rdseed,-vmx,-svm' \
  -m 64M -nographic -no-reboot -display none -parallel none
```

Real console output, `\r` stripped, nothing else edited:

```
SeaBIOS (version rel-1.17.0-0-gb52ca86e094d-prebuilt.qemu.org)

iPXE (http://ipxe.org) 00:03.0 CA00 PCI2.10 PnP PMM+02FD1D60+02F31D60 CA00
Press Ctrl-B to configure iPXE (PCI 00:03.0)...

Booting from ROM..libid appkoru = 0
libid ukprint = 25
console_lvl before = 2
console_lvl after roundtrip = 2 (matrix proven against a real ukprint value, not a fixture)
alloc -> add: object published, first <held!> obligation live
acquire: SECOND independent <held!> obligation on the SAME object id
entry.get returned FOUND on a zero-entry object: real ukstore defect (uk_list_for_each_entry container_of on an empty sentinel, see index.kz) -- not dereferencing it further
released the acquired handle
released the published handle: object ratchet complete
```

Six things that output proves, beyond "it runs":

1. **`uk_libid("appkoru")` resolved to a real id (0)**, not `UKLIBID_NONE` —
   the general-purpose runtime lookup this lift substitutes for
   `uk_libid_self()` (which this compilation unit cannot call at all; see
   "THE APP-HAS-NO-LIBRARY-IDENTITY GAP" in `index.kz`) genuinely works.
2. **`uk_libid("libukprint")` resolved to id 25** — note the name: every
   `lib/`-sourced library registers under a `lib`-PREFIXED name
   (`ukprint/Makefile.uk`: `$(eval $(call addlib_s,libukprint,…))`), while
   this application registers under the bare name its OWN generated
   `Makefile.uk` gives it (`addlib,appkoru`, no prefix). Found by booting,
   not by reading a header — a first attempt using `"ukprint"` compiled and
   ran fine and printed `missing`, silently wrong in a way `--check` cannot
   catch.
3. **`get.u8`/`set.u8`/`get.u8` round-tripped against `ukprint`'s REAL
   `console_lvl` static entry** — not a fixture this lift made up. The value
   read back after the write matches, and both reads used the exact same
   entry pointer obtained from `entry.static`, a linker-section lookup this
   lift never allocates memory for.
4. **Two independent `<held!>` obligations on the SAME object id, both
   discharged.** `held` (from `add`) and `held2` (from `acquire`) are
   separate Koru bindings over what is, at the C level, the identical
   pointer — proving THE MISMATCH section's central claim is not asserted,
   it compiles and runs.
5. **A genuine `ukstore` defect fired and was handled without touching wild
   memory** — `entry.get` on a zero-entry object returned `found`, not
   `missing` (see "A second genuine library defect" in `index.kz`), and the
   program prints exactly that and continues, never dereferencing the
   returned entry pointer.
6. **The ratchet completed**: `alloc -> add -> acquire -> entry.get ->
   release -> release`, six real C calls (plus the two lookups and the three
   matrix calls), nothing added, nothing skipped.

### Measured

| | |
|---|---:|
| `boot_store.kz` freestanding archive | 16,096 B |
| `boot_store.kz` bootable unikernel | 185,216 B |
| baseline (`examples/unikraft/hello.kz`, no ukstore) | 164,544 B |
| build, from clean | ~35 s |

No boot-time number, and none may be created — QEMU TCG on arm64 host, no
KVM. No "faster than C" claim either: the per-call `UK_ASSERT` already
compiles out in release, and the three-way benchmark that would support a
dissolution claim with numbers does not exist and was not built here.

---

## Gate 3 — negative tests

Phantom validation fires in the **emit** pass, not in `--check`. Both pass
`koruc --check` and are refused by `koruc <file>`. Diagnostics verbatim.

**`tests/negative_release_without_add.kz`** — the asymmetry. Allocate, skip
`add`, release straight away.

```
$ koruc --check negative_release_without_add.kz
✓ Shape checking passed

$ koruc negative_release_without_add.kz
error[KORU030]: Phantom state mismatch: expected 'unikraft.store:held' but got 'unikraft.store:built!' for argument 'obj'
```

The C cannot object to this program — `uk_store_obj_release` would run,
indexing `dynamic_heads[]` with whatever garbage sits in the never-initialized
`object->libid`. There is no C-side check to lift here; the assertion this
refusal stands in for does not exist in `lib/ukstore` at all, which is the
strongest form of "the ordering was written down nowhere and enforced
nowhere" this catalog has seen.

**`tests/negative_release_twice.kz`** — double release, the refcount ratchet's
version of a double-free.

```
error[KORU030]: Use-after-discharge: binding 'held' was already discharged and cannot be used
```

**`tests/autodischarge_covers_held.kz`** — a POSITIVE control, and a
correction recorded in the file itself the same way `unikraft/alloc`'s README
records its own: my first draft claimed dropping a live `<held!>` binding
without an explicit `release` must not compile. It compiles — `<held!>` has
exactly one unattended terminal disposer, so auto-discharge silently INSERTS
the `release` call, verified by grepping the emitted Zig for exactly one
`release_event.handler` call in a source with zero literal ones. So,
precisely: **"forgetting to release a held object" is a compile-time
insertion, not a catch** — the same honest distinction `unikraft/alloc` draws
for its own `<live!>` state.

---

## What the toolchain got wrong — a compiler defect, pinned

Reported, not routed around. A tor whose parameter requires a single
non-union phantom state `<!S>`, and whose OWN failure arm re-mints that exact
same state `<S!>` (while a DIFFERENT arm mints a genuinely new state), makes
Koru's discharge/consumer-search pass fail to recognize the tor as a valid
consumer of `<!S>` at all — even down the arm that legitimately transitions
to the new state, and even when the program never takes the failure arm.

Minimal repro, two versions, one line different:

```koru
~pub tor pub2 { obj: *Obj<!built> }
| ok *Obj<held!>
| refused { obj: *Obj<built!>, reason: string }   // <- breaks discharge tracking
```

```
$ koruc repro.kz
error[KORU030]: Resource 'obj' obligation <built!> was not discharged. No tor accepts <!built>.
```

pointing at the CALL SITE of `pub2`, not at `pub2`'s own declaration, even
though `pub2`'s `ok` arm plainly consumes `<!built>` and mints `<held!>`.
Changing ONLY the refused arm's state name to something distinct (`<stuck!>`)
makes the byte-identical program compile. Verified NOT to be about cross-
module qualification, arrow-vs-arm binding syntax, or a tor-name collision —
each ruled out with its own isolated control before landing on the real
differentiator (self-referential in/out state naming on a single, non-union
input, with an asymmetric second arm).

This lift's `add` tor originally hit this directly (`obj: *Object<!built>`
in, refusal minting `<built!>` again for "nothing happened, retry"). Fixed by
minting `<stuck!>` instead and adding `abandon` as the consumer — which turns
out to be the more honest design anyway, argued on its own terms in
`index.kz`, since the one cause of this refusal (`uk_libid` missing
`"appkoru"`) is a fixed build fact retrying cannot change.

## What `lib/ukstore` itself gets wrong — two library defects, pinned

Neither is a Koru toolchain issue, and neither is worked around inside
`index.kz`. Both are documented at the binding site in `index.kz` with full
detail; summarized here.

1. **`_uk_store_get_charp` (`store.c:1442-1454`) reads
   `struct uk_alloc *a = OBJECT(e)->a;` UNCONDITIONALLY**, before checking
   whether `e` is a static entry. For a static entry (one registered via
   `UK_STORE_STATIC_ENTRY`, not embedded in a `struct uk_store_object_entry`),
   `OBJECT(e)` computes a `container_of` on the WRONG struct and dereferences
   garbage. Every other typed getter/setter in the file correctly guards the
   equivalent expression with `if (!UK_STORE_ENTRY_ISSTATIC(e))`. This lift's
   boot demo does not call `get.charp` against a static entry, precisely
   because of this.
2. **`uk_store_obj_entry_get` (`store.c:376-391`) returns a wild, non-NULL
   pointer for ANY object with zero entries**, for any `entry_id`. Its
   `uk_list_for_each_entry` (`uk/list.h:158-161`) macro sets the cursor via
   `container_of((head)->next, …)` in its INIT clause, before the loop
   condition is tested — so on an empty list (`head->next == head`), the
   cursor is left holding `container_of(&entry_head, struct
   uk_store_object_entry, list_head)`, a backward pointer computed from a
   field that lives inside the UNRELATED `struct uk_store_object`. The loop
   body (which does the actual `entry_id` comparison) never runs, but
   `if (res) return &res->entry;` returns this garbage address anyway.
   **Found by booting this lift's own demo** — `tests/boot_store.kz` creates
   a genuinely empty object (see "What this lift does not model") and calls
   `entry.get(obj, entry_id: 999)`, which returns `found`, not `missing`, on
   real console output. Not dereferenced further; see the boot-demo evidence
   above.

---

## What this lift does not model — stated, not hidden

- **Dynamic entry creation.** `uk_store_obj_alloc`'s `entries[]` parameter is
  a NULL-terminated array of `const struct uk_store_entry *`; every object
  this lift creates passes an array holding a single NULL, i.e. every object
  `alloc` mints has ZERO entries. Populating a real one needs a `struct
  uk_store_entry` you construct yourself, with `get`/`set` fields holding raw
  C function pointers of the exact `int(*)(void*, T*)` shape the header
  declares — reachable from a `.kz` file (plain top-level `fn … callconv(.c)`
  declarations are legal, the idiom `unikraft/blk` already uses for its
  private helpers), but wiring it into a general-purpose,
  caller-parameterized "define your own store entry" surface is a design in
  its own right, not a byproduct of this lift. What IS proven is everything
  downstream of an entry existing: lookup and the full typed read/write
  matrix, exercised for real against a static entry another Unikraft library
  already ships.
- **`_uk_store_get_ncharp`** — the bounded-copy charp getter — is not bound.
  One more symbol on the same closed matrix, no new shape.
- **`_uk_store_create_dynamic_entry_*`** (ten symbols) are not bound. Not
  declared in `store.h`; not a sanctioned direct-call surface.
- **The two event symbols** (`UKSTORE_EVENT_CREATE_OBJECT`/
  `_RELEASE_OBJECT`) are not bound. Subscribing to them needs Unikraft's
  separate `uk/event.h` listener-registration API, untouched here.
- **`get.charp`'s free-side.** The header's own doc comment says the caller
  must free a returned charp string, and WHICH allocator to free it with
  depends on whether the entry is static (libc-family `free`) or dynamic (the
  object's own allocator) — information an opaque `*const StoreEntry` does
  not expose to Koru. Not solved here.

## Claims I do not make

- **Not "faster than C."** Forbidden by the brief, and there is no benchmark.
- **No boot-time number.** QEMU TCG, no KVM.
- **Not "forgetting to release is a compile error."** True only for `<built!>`
  and `<stuck!>` states reached the wrong way (genuine type mismatches); for
  a correctly-typed `<held!>` it is a compile-time INSERTION, proven in
  `tests/autodischarge_covers_held.kz`.
- **Not "this proves the refcount is safe under concurrency."** Nothing in
  Koru's obligation model reasons about threads; the C's own spinlock
  (`dynamic_heads_lock`) is what actually serializes `acquire`/`add`/
  `release`, unmodeled here exactly as it is unmodeled in `unikraft/lock`'s
  own "not this makes locking safe" disclaimer.
- **Not "this covers `lib/ukstore`."** The `_ifmalloc`/stats-style surfaces,
  the event-listener API, and dynamic entry construction are all unbound; see
  "What this lift does not model."

---

## Files

| | |
|---|---|
| `index.kz` | the lift |
| `tests/boot_store.kz` | gate 2 — full ratchet + typed matrix against a real static entry, in a unikernel |
| `tests/negative_release_without_add.kz` | gate 3 — the asymmetry |
| `tests/negative_release_twice.kz` | gate 3 — use-after-discharge, the double-free shape |
| `tests/autodischarge_covers_held.kz` | positive control — `<held!>` auto-discharges; a correction, recorded |
| `tests/wrapper.zig`, `tests/main.c` | the C-ABI seam, from `koru/examples/unikraft` |

Measured against `unikraft` HEAD `3fdffba8`, kraftkit 0.12.15, Unikraft
0.21.0 "Ijiraq", zig 0.15.2, on macOS/arm64.
