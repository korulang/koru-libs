# `unikraft/allocpool` — Unikraft's `ukallocpool`, lifted

```koru
~import unikraft/allocpool

~unikraft/allocpool:create(objects: 16, bytes: 128, alignment: 8)
| pool p |> unikraft/allocpool:take(pool: p)
    | obj o |> unikraft/allocpool:write(pool: p, obj: o, bytes: "…")
        | ok filled |> unikraft/allocpool:give(pool: p, obj: filled)
            |> unikraft/allocpool:keep(pool: p)
```

**This is not a naive wrap.** Reachability was never the open question:
`lib/ukallocpool` has 12 allowlist lines, 12 real definitions and **zero**
`static inline`s. Everything links. The open question was **provenance** — two
constructors, one destructor, and picking the wrong pairing is undefined at
`-DNDEBUG` — and that is what this module is about.

Eleven tors, four phantom states, no struct mirror, one named escape, and
**7 of 23 `UK_ASSERT`s retired outright, 2 converted into live refusals, 14 not
retired**, each attributed per site below.

---

## The tors

| tor | takes | mints | C call |
|---|---|---|---|
| `create` | — | `*Pool<owned!>` | `uk_allocpool_alloc` |
| `host` | — | `*Pool<hosted!>` | `uk_allocpool_init` (static arena) |
| `census` | `*Pool` (bare) | — | `availcount` + `maxcount` + `objlen` |
| `take` | `*Pool` (bare) | `*Obj<fresh!>` | `uk_allocpool_take` |
| `write` | `*Obj<!fresh\|!used>` | `*Obj<used!>` | `objlen`, then a copy |
| `read` | `*Obj<!used>` | `*Obj<used!>` | `objlen`, then a borrow |
| `untouched` | `*Obj<!fresh>` | `*Obj<used!>` | **none — the escape** |
| `give` | `*Obj<!used>` | — | `uk_allocpool_return` |
| `free` | `*Pool<!owned>` | — | `uk_allocpool_free` — **crashes, see below** |
| `keep` | `*Pool<!owned\|!hosted>` | — | **none — and it is what works** |

Four states on two axes that never mix. `owned`/`hosted` is where a pool's slab
came from, and it is consulted in exactly one place. `fresh`/`used` is whether
an object's contents were put there by this program.

---

## THE HEADLINE: `uk_allocpool_free` cannot run, in any build

The library's only destructor is dead code, and this was measured on a booted
image rather than read off a comment.

```c
void uk_allocpool_free(struct uk_allocpool *p)
{
        UK_ASSERT(p->parent);                             /* pool.c:383 */
        UK_ASSERT(p->free_obj_count == p->obj_count);     /* pool.c:386 */
        /* FIXME: Unregister `ukalloc` interface from `lib/ukalloc` */
        UK_CRASH("Unregistering from `lib/ukalloc` not implemented.\n");
        uk_free(p->parent, p->base);                      /* never reached */
}
```

`UK_CRASH` is **not** gated on `CONFIG_LIBUKDEBUG_ENABLE_ASSERT`. Read
`lib/ukdebug/include/uk/crash.h:18-22` beside `assert.h:49-74`: `UK_ASSERT`
becomes `do {} while(0)` when asserts are off, `UK_CRASH` is `uk_pr_crit`
followed by `uk_crash_trigger()` unconditionally. So the two assertions above it
are unreachable in practice — **you die before you can violate either.**

`tests/boot_free_crashes.kz` is a program the compiler accepts (`create` mints
`<owned!>`, `free` accepts `<owned!>`, nothing is outstanding) and the machine
refuses:

```
Booting from ROM..owned pool: 4/4 free — now calling uk_allocpool_free
[    0.101923] CRIT: [libukallocpool] <pool.c @  390>  Unregistering from `lib/ukalloc` not implemented.
 [    0.102918] CRIT:  Unikraft Crash - Ijiraq (0.21.0)
 [    0.103665] CRIT:      _
 [    0.103748] CRIT:    cx xo
 [    0.103822] CRIT:    (|O|)/V
 [    0.103969] CRIT:  Registers:
 [    0.104082] CRIT:   rip: 0008:0000000000113413
```

**Why the author did that is legible and it matters for the lift.** Every pool
constructor ends in `uk_alloc_init_malloc` (`ukalloc alloc_impl.h:206-228`),
whose last statement is `uk_alloc_register(a)` — so **a pool adds itself to
`_uk_alloc_head`'s chain, and `lib/ukalloc` has no unregister** (pool.c:388's
own FIXME says exactly this). Freeing the slab would leave a live list node
pointing into freed memory, and `uk_alloc_availmem_total` walks that chain.
Crashing is the honest option available in C.

**`free` is bound anyway, and that is the point.** The provenance rule is a rule
*about this function*; a lift that declined to bind it would be claiming to have
lifted an assertion guarding a call it never makes. It is bound, gated, and its
doc comment and this section say what it does. `keep` is what a working program
uses, and `tests/boot_allocpool.kz` ends both of its pools with it.

---

## The instrument: phantom states, not two handle types

The brief leaves this choice to the contestant. **One handle type, two phantom
states, and every operational tor takes the pool through a bare `pool: *Pool`
parameter.**

The argument is mechanical. `take`, `give`, `write`, `read` and `census` are
**provenance-blind** — where a pool came from has no bearing on whether you may
take an object out of it. A bare parameter neither reads nor spends the phantom
state, so one set of operational tors serves both provenances. Two handle types
would have forced those five verbs to exist twice — **ten tors where five do** —
to encode a distinction none of the ten consults.

**Put the distinction where it is consulted.** It is consulted in exactly one
place, `free`, and a phantom state is precisely a fact carried to the site that
consults it.

The honest counter-argument, because it is the better half of the case for
types: a phantom state normally *transitions*, and provenance never does — a
pool's origin is fixed at birth, which is what a type is for. That is true, and
it is why these two states are terminal: nothing transitions `owned` to `hosted`
or back. What decided it is that the alternative was not "a type instead of a
state" but "a type instead of a state, **plus a duplicate of every verb**", and
pillar 1 is developer experience.

**This was measured before it was chosen, not argued after.** Four probes, in
`/tmp`, against a four-tor throwaway module, before a line of the lift existed:

| probe | result |
|---|---|
| bare `*Pool` param against a `<owned!>` binding | compiles; obligation still live |
| drop the pool at the end | `KORU030 … was not discharged` / multiple options |
| object never returned | `KORU030: Resource 'o' obligation <held!> was not discharged` |
| `give` after `free` | `KORU030: Use-after-discharge: binding 'p'` |

`tests/pool_threads_through_operations.kz` is the same probe as a shipped test:
the pool threads through two `take`/`give` round trips and a `census`, and the
final `keep` is what discharges it. `tests/negative_pool_dropped.kz` is its
negative twin.

---

## The three rules the compiler now enforces

### 1. The pairing — `pool.c:379-383`

```c
/* If we do not have a parent, this pool was created with
 * uk_allocpool_init(). Such a pool cannot be free'd with
 * this function since we are not the owner of the allocation */
UK_ASSERT(p->parent);
```

`p->parent` is private and set only by `uk_allocpool_alloc` (pool.c:373), so in
a shipped image this rule is not merely unchecked — **it is uncheckable from the
outside.** Hand a `uk_allocpool_init` pool to `uk_allocpool_free` and it reaches
`uk_free` on an address the byte allocator never issued.

Here `free` accepts `*Pool<!owned>`, and only `create` mints `<owned!>`:

```
$ koruc tests/negative_free_hosted_pool.kz
error[KORU030]: Phantom state mismatch: expected 'unikraft.allocpool:owned'
                but got 'unikraft.allocpool:hosted!' for argument 'pool'
  --> negative_free_hosted_pool.kz:33:0
```

**The rule is one-directional in the C and one-directional here.** There is no
rule saying an `uk_allocpool_alloc` pool *must* be freed, so there is no mirror
negative, and inventing one would be inventing a rule the library does not have.

### 2. Drain before free — `pool.c:385-386`

```c
/* Make sure we got all objects back */
UK_ASSERT(p->free_obj_count == p->obj_count);
```

A counter comparison, compiled out. Here there is **no counter**, and the rule
falls out of two independent facts:

- `give` is a **two-argument disposer**, so auto-discharge can never elect it.
  An object that is not explicitly returned is always reported.
- `free` and `keep` **consume** the pool, so any `give` after either is a
  use-after-discharge on the pool binding.

Together: every object taken must be returned, and it must be returned before
the pool ends.

```
$ koruc tests/negative_object_outstanding.kz
error[KORU030]: Resource 'filled' obligation <used!> was not discharged. Call: give
  --> negative_object_outstanding.kz:31:0
```

The run-time half is in the boot console: each pool's census brackets its whole
use and the two free counts are equal.

### 3. The asymmetry (pillar 4), placed on the object

`give` accepts only `<!used>`, reachable only through `write`, `read` or the
named escape. An object taken and handed straight back does not compile:

```
$ koruc tests/negative_give_without_use.kz
error[KORU030]: Phantom state mismatch: expected 'unikraft.allocpool:used'
                but got 'unikraft.allocpool:fresh!' for argument 'obj'
```

And a double return — which in the C links the object into the free list twice
and drives `free_obj_count` past `obj_count` — is the same shape:

```
$ koruc tests/negative_use_after_give.kz
error[KORU030]: Use-after-discharge: binding 'u' was already discharged and cannot be used
```

`<fresh>` is not ceremony. The pool is LIFO and clears nothing, so a taken
object's first `sizeof(struct uk_list_head)` bytes are the freelist links
`_prepend_free_obj` wrote when it was last returned (pool.c:117-118). Reading a
fresh object reads the allocator's own pointers.

---

## Where pillar 4 is REFUSED, and why

**The pool gets no use-before-finalize gate.** `create(…) |> keep(…)` — a pool
nothing was ever taken from — compiles, on purpose.

The pool has two orthogonal facts and one state axis: where its slab came from
(permanent; penalty for getting it wrong is `uk_free` on an address the
allocator never issued) and whether it was ever used (monotone; penalty is a few
KiB reserved and not used). One axis, two candidates, and it goes to the one
whose violation corrupts the heap. Ratcheting the pool would additionally have
required `take` to spend and re-mint the pool state, which is the duplication
argued away above.

`unikraft/vmem` made the same shape of call — pillar 4 on the committed half,
refused on the reservation half.

---

## Why `keep` is not a convenience

`keep` runs no C call and mints nothing. In Unikraft today it is the **only** way
a pool can end: `uk_allocpool_free` crashes, and the registration every
constructor performs cannot be undone. A long-lived pool is also the normal
shape — pools are built at boot, sized once, and used until the machine stops.

It is also what gives `<owned>` a **second disposal**, and that is load-bearing:

```
$ koruc tests/negative_pool_dropped.kz
error[KORU030]: Resource 'op' <owned!> has multiple discharge options: free, keep.
                Discharge explicitly.
```

With one disposal the compiler would have inserted it silently. This is the
dividend `unikraft/alloc` recorded after the fact — *a named escape buys a
diagnostic, not just a grep* — applied here on purpose rather than discovered.

```
grep -r "allocpool:keep"        -> "which pools live for the life of the machine"
grep -r "allocpool:untouched"   -> "where do we take objects we never fill"
```

**The asymmetry in that guarantee, stated:** `<hosted>` has only `keep`, so a
dropped **hosted** pool is auto-inserted rather than reported. There is no honest
second disposal for a hosted pool, and inventing one to buy a diagnostic would
mean inventing a C call that does not exist.

---

## The `UK_ASSERT` census — 23 sites, per site

`grep -n UK_ASSERT pool.c` against `unikraft` HEAD `3fdffba8`. All 23 are in
`pool.c`; the public header has none. **`lib/ukallocpool` is byte-identical
between the fork and stable 0.21.0 "Ijiraq"** (`pool.c` and `exportsyms.uk` both
diffed clean), so this census answers for the tree the `version: stable`
Kraftfile actually builds.

### A. Retired — 7 sites made unspellable

| line | expression | function | how |
|---|---|---|---|
| `112` | `UK_ASSERT(p)` | `_prepend_free_obj` | reached by `give`. `*Pool` is a non-optional pointer minted only inside a `\| pool` arm; both constructors take a refusal arm on NULL before minting. |
| `113` | `UK_ASSERT(obj)` | `_prepend_free_obj` | reached by `give`. **The take/return hazard the C leaves open**: `uk_allocpool_take` returns NULL on an empty pool (pool.c:132-134) and `uk_allocpool_return(p, NULL)` then links a list entry at address 0. Here NULL takes `\| empty` and no `*Obj` is minted. |
| `126` | `UK_ASSERT(p)` | `_try_take_free_obj` | reached by `take`; same argument as :112. |
| `194` | `UK_ASSERT(p)` | `uk_allocpool_take` | same. |
| `223` | `UK_ASSERT(p)` | `uk_allocpool_return` | same. |
| `383` | `UK_ASSERT(p->parent)` | `uk_allocpool_free` | **the provenance gate.** `free` accepts `<!owned>`; only `create` mints it. |
| `386` | `UK_ASSERT(free_obj_count == obj_count)` | `uk_allocpool_free` | **the drain rule.** Every `*Obj` carries an obligation `give` alone discharges, and `give` needs a pool this tor has consumed. |

### B. Converted — 2 sites kept as a live refusal rather than dissolved

| line | expression | function |
|---|---|---|
| `264` | `UK_ASSERT(POWER_OF_2(obj_align))` | `uk_allocpool_reqmem` |
| `298` | `UK_ASSERT(POWER_OF_2(obj_align))` | `uk_allocpool_init` |

Both `create` and `host` refuse a non-power-of-two alignment **before** the call,
so the guarantee holds in the shipped image where the assertion does not. But it
is a check that still runs, not a program shape that cannot exist, and filing it
under "retired" would overstate what a phantom state did. It is counted
separately for that reason. (A phantom state cannot carry it: the value is a
run-time `u64`, and no state can constrain an integer.)

### C. NOT retired — 14 sites

| line | expression | function | why not |
|---|---|---|---|
| `95` | `UK_ASSERT(a)` | `ukalloc2pool` | only reachable through the `uk_alloc` vtable path, which this lift refuses to bind (see below). |
| `104` | `UK_ASSERT(p)` | `uk_allocpool2ukalloc` | function not bound. |
| `114` | `UK_ASSERT(free_obj_count < obj_count)` | `_prepend_free_obj` | retired for a double return of the *same* object (use-after-discharge) but **not** for an object crossed between two pools — see *the honest limit* below. Counted as not retired. |
| `115` | `UK_ASSERT(IS_ALIGNED(obj, obj_align))` | `_prepend_free_obj` | same cross-pool hole. |
| `139` | `UK_ASSERT(obj <= POOL_END(p) - obj_len)` | `_try_take_free_obj` | internal bump-allocator arithmetic. No caller supplies the values, so there is no caller mistake for a lift to take away. |
| `147` | `UK_ASSERT(free_obj_count > 0)` | `_try_take_free_obj` | internal; the branch above it already handles zero. |
| `150` | `UK_ASSERT(IS_ALIGNED(obj, obj_align))` | `_try_take_free_obj` | internal invariant on what the pool itself laid out. |
| `169` | `UK_ASSERT(size <= p->obj_len)` | `pool_malloc` | vtable path, not bound. |
| `182` | `UK_ASSERT(size <= p->obj_len)` | `pool_posix_memalign` | vtable path, not bound. |
| `183` | `UK_ASSERT(p->obj_align % align == 0)` | `pool_posix_memalign` | vtable path, not bound. |
| `207`, `208` | `UK_ASSERT(p)`, `UK_ASSERT(obj)` | `uk_allocpool_take_batch` | batch API not bound. |
| `235`, `236` | `UK_ASSERT(p)`, `UK_ASSERT(obj)` | `uk_allocpool_return_batch` | batch API not bound. |

*(The last two rows carry two sites each; the total is 14.)*

### Net

| | count |
|---|---:|
| retired — made unspellable | **7** |
| converted — a live refusal where the assertion was compiled out | **2** |
| not retired — surfaces not bound (`95`, `104`, `169`, `182`, `183`, `207`, `208`, `235`, `236`) | 9 |
| not retired — internal invariants no caller can violate (`139`, `147`, `150`) | 3 |
| not retired — the cross-pool hole (`114`, `115`) | 2 |
| **total** | **23** |

Four of the nine "not bound" sites are `pool_malloc`/`pool_posix_memalign`'s
size and alignment rules, and it would be easy to count them as retired on the
grounds that `write` is bounded by `uk_allocpool_objlen` and therefore cannot
overrun. That would be the easiest inflation available in this file and it is not
taken: **not offering a surface is not retiring its check.**

And the qualifier the brief asks for: `UK_ASSERT` is `do {} while(0)` in every
image on this shelf, so none of the 23 was *costing* anything. What changes is
that the guarantees the seven describe now hold in the shipped image, where
before they held only in a debug build — and, for `:383` and `:386` specifically,
where before they held **in no build at all**, because `UK_CRASH` on line 390
ends the program either way.

---

## Dedup against `unikraft/alloc` and `unikraft/pages`

Both neighbours are allocators; so is this. The overlap is real and is confined
to one axis, which this module deliberately does **not** re-argue: `fresh`/`used`
is the same instrument as `alloc`'s `raw`/`live` and `pages`' `blank`/`filled`,
for the same reason, and `untouched` keeps the same spelling because a third word
for one idea is worse than a repeated one. **That axis is not this lift's
contribution and is not claimed as one.**

What is in neither neighbour:

- **Two constructors and one destructor.** `ukalloc` has one of each;
  `uk_palloc`/`uk_pfree` likewise. Neither has a provenance rule, so neither has
  anything resembling `free`'s `<!owned>` gate.
- **Drain-before-destroy.** A `*Block` and a `*Pages` region have no
  sub-resources. A pool's objects are sub-resources of the pool.
- **No handle header, and that is a deliberate divergence.** `alloc` and `pages`
  both put a header struct in front of the caller's region. **A pool's contract
  is exact sizes** — N objects of exactly L bytes is the whole reason to use one
  — so spending `alignUp(16, align)` bytes of every object on a lift's
  bookkeeping would be the lift lying about the machine. Instead `write`, `read`
  and `give` take the pool as an argument and read the length back with
  `uk_allocpool_objlen`: ceremony at the call site, **zero bytes in the image**.
- **Nothing is mirrored.** `Pool` and `Obj` are `opaque`. `pages`, `sched` and
  `lock` each had to pay a mirror proof; this lift has nothing to prove because
  every fact it needs has an exported accessor.

`unikraft/alloc` is also the catalog's reference for restraint, and its lesson
was taken: this module refuses to ratchet the pool (above), refuses three of the
twelve exported symbols (below), and reports an assert census of 7 rather than a
reachable-looking 16.

---

## What is deliberately NOT bound — 3 of the 12 exported symbols

- **`uk_allocpool2ukalloc`.** It hands out a `struct uk_alloc *` so the pool can
  be driven through `uk_malloc`/`uk_free`. That converts every object into an
  untracked `void *` with no obligation and no state — **the exact hole this
  module exists to close** — and it re-opens `pool_malloc`'s
  `UK_ASSERT(size <= p->obj_len)` (pool.c:169), a caller rule the typed surface
  does not have because `write` is bounded by `objlen`.
- **`uk_allocpool_take_batch` / `uk_allocpool_return_batch`.** One call yielding
  N independently-owed objects into a C array is not a shape a phantom obligation
  can carry: the compiler would have to track an array of obligations whose
  length is a run-time value. A `batch` handing back one handle for N objects
  would be a different resource with a different rule, honestly modelled and not
  equivalent to the C. Not attempted, and none of their four assertions is
  counted as retired.
- **`uk_allocpool_reqmem` as a public tor.** A sizing helper whose only consumer
  is a constructor; both constructors call it internally. Exposing it would
  invite a caller to compute a length and then pass a different one.

---

## The hosted slab, and the hang it refuses

`uk_allocpool_init` places a pool in memory the **caller** owns, which is the
whole reason it exists beside `uk_allocpool_alloc`. In a unikernel that memory is
characteristically not heap memory — it is a statically reserved region, sized at
build time, present before the allocator is. This module provides exactly that,
in its own `.bss`: **8192 bytes, declared as `ARENA_LEN`.** `host` refuses any
request `uk_allocpool_reqmem` sizes above it, naming both numbers. There is no
growth path and no fallback to the heap; that would make `host` and `create` the
same tor wearing two names and the provenance rule fiction.

**The arena may be hosted once per boot, and the flag is not hygiene — it
prevents a hang.** `uk_allocpool_init` ends in `uk_alloc_init_malloc`
(`alloc_impl.h:227`), whose last statement is `uk_alloc_register(a)`.
`uk_alloc_register` (`ukalloc alloc.c:57-71`) walks to the tail of the chain and
appends. Re-initialising a pool **at the same address** therefore walks to a tail
that *is* the node being appended and writes `this->next = a` with `this == a` —
a self-loop — and `uk_alloc_availmem_total` walks that chain and never returns.

**Derived by reading `uk_alloc_register` and `uk_alloc_init_malloc`, not measured
on an image**, and labelled as such: demonstrating a hang is not a console line.
`host`'s `| busy` arm names the mechanism it is avoiding.

---

## The honest limit

**`give(pool, obj)` does not prove the object came from that pool.** With two
pools in scope, crossing them is spellable — and it is exactly what pool.c:114
and pool.c:115 exist to catch. Proving it needs an object type parameterised by
its pool, which Koru does not have for phantom handles. Both sites are counted
as **not retired** for this reason.

A second, smaller one: `read` is bounded by the pool's object length and not by
how much was written, because there is nowhere to keep a `used` counter without
the header this module refuses to charge for. So `read` can return slack the
caller did not write. The state gate is what keeps that honest — the object was
written by *something* in this program before it could be read at all — but it is
weaker than `unikraft/alloc:read`, which is bounded by `used`.

---

## Gate 1 — `--check`

```
$ koruc --check unikraft/allocpool/index.kz
✓ Shape checking passed
```

## Gate 2 — it boots

Run clean in an empty directory. Traps and their evidence:
`/Users/larsde/src/koru/examples/unikraft/BUILD.md`.

```sh
# copy the WHOLE unikraft/ tree, not three files into a flat dir: the entry file
# declares `unikraft: {{ ENTRY }}/../..` in its own source, so it has to keep
# its depth.
mkdir /tmp/ukallocpool && cp -R unikraft /tmp/ukallocpool/
cd /tmp/ukallocpool/unikraft/allocpool/tests

koruc boot_allocpool.kz unikraft gen    # -> Makefile.uk + Kraftfile
koruc boot_allocpool.kz                 # -> output_emitted.zig
                                        #    (the host link then fails on the
                                        #     Unikraft symbols; that is expected)
zig build-lib wrapper.zig \
    -target x86_64-freestanding -O ReleaseSmall \
    -fno-stack-protector -femit-bin=libkoruapp.a
UK_CFLAGS="-std=gnu17" kraft build --arch x86_64 --plat qemu --no-prompt
```

**The exact qemu invocation** — the `-cpu` line is not optional, a sibling lift
lost a boot without it:

```sh
qemu-system-x86_64 -kernel .unikraft/build/koru_qemu-x86_64 \
  -cpu 'qemu64,+pdpe1gb,+rdrand,+rdseed,-vmx,-svm' \
  -m 64M -nographic -no-reboot -display none -parallel none
```

No disk, no network, no device model — `ukallocpool` needs none.

Real console output, `\r` stripped, nothing else edited:

```
SeaBIOS (version rel-1.17.0-0-gb52ca86e094d-prebuilt.qemu.org)

iPXE (http://ipxe.org) 00:03.0 CA00 PCI2.10 PnP PMM+02FD1D60+02F31D60 CA00
Press Ctrl-B to configure iPXE (PCI 00:03.0)...

Booting from ROM..hosted  open:  8/8 free, objlen 64 B
hosted  take:  an object out of a uk_allocpool_init pool
hosted  close: 8/8 free
owned   open:  16/16 free, objlen 128 B
owned   probe: one object taken and returned unwritten, on purpose
owned   take:  an object out of a uk_allocpool_alloc pool
owned   close: 16/16 free
```

Four things that output proves beyond "it runs":

1. **Both constructors run in one image.** `uk_allocpool_init` over this
   module's static arena and `uk_allocpool_alloc` on the binary-buddy allocator,
   side by side. They are the two halves of the provenance rule, and after
   construction the only thing separating their pools is a phantom state.
2. **Both census brackets close** — 8/8 to 8/8, 16/16 to 16/16. An object that
   failed to return is a smaller second number. That is pool.c:386 measured at
   run time, beside the compile-time refusal that makes it unreachable.
3. **`objlen` is the aligned length, not the request.** The hosted pool asked for
   64 bytes at 8-byte alignment and the C laid out 64; the owned pool asked for
   128 and got 128. The number is read back with `uk_allocpool_objlen`, so a
   geometry the C rounded would show. A lift that echoed the request would be
   reporting its own input.
4. **The named escape ran.** `owned probe` is an object taken, `untouched`, and
   given straight back — the program `negative_give_without_use.kz` refuses,
   spelled honestly. It emits no C call, so the only evidence is that this
   program compiles and the bracket still closes.

### The destructor, booted

`tests/boot_free_crashes.kz`, same recipe, its console is in **the headline
section above.** Both images carry the same Kconfig deltas, so their sizes are
comparable.

### Measured

| | |
|---|---:|
| `boot_allocpool.kz` freestanding archive | 17,872 B |
| `boot_allocpool.kz` bootable unikernel | 172,800 B |
| `boot_free_crashes.kz` archive | 6,664 B |
| `boot_free_crashes.kz` unikernel | 168,704 B |
| baseline: `hello.kz` (reproduces `BUILD.md`) | 164,544 B |
| build, from clean | ~30 s |

**No boot-time number, and none may be created** — QEMU TCG, no KVM. **No
"faster than C"**: the three-way benchmark that would support one does not exist
and this lift did not build it. What is above is image bytes.

**One measurement caveat, recorded because it nearly became a claim.** The first
crash image measured 201,664 B against the boot image's 172,800 B, which reads
like "binding `free` costs 29 KB of crash machinery". It does not: the crash test
was missing `CONFIG_OPTIMIZE_DEADELIM`, which `BUILD.md` measures at 24,832 B.
With the configs matched the crash image is *smaller*, because it does less.
There is no image-size claim here about binding `free`.

## Gate 3 — five misuses that fail to compile

Phantom validation fires in the **emit** pass, not in `--check`. All five pass
`koruc --check` and are refused by `koruc <file>`. Diagnostics verbatim, and the
code is `KORU030` in every case — checked, because a `KORU002` from a namespace
that resolved to the main checkout would look identical from a distance.

| test | diagnostic |
|---|---|
| `negative_free_hosted_pool.kz` | `KORU030: Phantom state mismatch: expected 'unikraft.allocpool:owned' but got 'unikraft.allocpool:hosted!' for argument 'pool'` |
| `negative_object_outstanding.kz` | `KORU030: Resource 'filled' obligation <used!> was not discharged. Call: give` |
| `negative_give_without_use.kz` | `KORU030: Phantom state mismatch: expected 'unikraft.allocpool:used' but got 'unikraft.allocpool:fresh!' for argument 'obj'` |
| `negative_use_after_give.kz` | `KORU030: Use-after-discharge: binding 'u' was already discharged and cannot be used` |
| `negative_pool_dropped.kz` | `KORU030: Resource 'op' <owned!> has multiple discharge options: free, keep. Discharge explicitly.` |

The controls are `boot_allocpool.kz`, which is `negative_free_hosted_pool.kz`
with `keep` in place of `free` and which boots, and
`pool_threads_through_operations.kz`, which is `negative_pool_dropped.kz` with
the `keep` restored and which compiles clean through the emit pass.

## Gate 4 — no silent fallbacks

- `create` splits "ukboot registered no allocator" (`| unavailable`) from "the
  allocator could not supply the slab" (`| refused`). `uk_allocpool_alloc`
  reports both as one NULL.
- `take` reports an exhausted pool as `| empty` and mints no object, rather than
  handing back a NULL the next `give` would link into the free list.
- `host` refuses a request larger than the arena and names both numbers. It does
  not quietly fall back to the heap — that would be reporting the wrong
  provenance.
- `free` is the real `uk_allocpool_free` and nothing is substituted for it. It
  crashes; this file says so in its first section and the tor's own doc comment
  says so at the call site.

---

## What the toolchain got wrong

**A tor parameter named `align` passes `--check` and emits invalid Zig.**
`align` is a Zig keyword; the emitter writes it through unescaped. Minimal repro,
four lines:

```koru
~pub tor sized { align: u64 } -> u64

~proc sized|zig {
    return align + 1;
}
```

```
$ koruc p.kz
✓ Shape checking passed          # --check is clean
…
Error: output_emitted.zig:63:24: error: expected ';' after statement
                return align + 1;
```

The class is wider than one word — every Zig keyword is a Koru parameter name a
library author has no way to know is taken, which is the same shape as the
`Allocator` collision `unikraft/alloc` pinned. The fix is `@"align"` at the
emission site, not a naming convention. **Not routed around:** this module's
parameter is now spelled `alignment`, which is also what `unikraft/alloc` calls
it, and the defect is reported here rather than absorbed silently.

Nothing else. The four states, the bare handle parameter, the two-argument
disposer and the multiple-disposal diagnostic all behaved as the probes said they
would.

---

## Claims I do not make

- **Not "the emitted code is faster than C".** Forbidden by the brief, and there
  is no benchmark. The honest claim is that Koru dissolves the
  asserts-on/asserts-off tradeoff for the seven assertions in group A.
- **No boot-time number.** QEMU TCG, no KVM.
- **Not "the pool cannot be freed twice."** It cannot, but the reason is not this
  lift — `free` consumes the pool, and the machine has already stopped.
- **Not "returning an object to the wrong pool is impossible."** It is spellable.
  See *the honest limit*; pool.c:114 and :115 are counted as not retired.
- **Not "reading uninitialised memory is impossible."** `<used>` is per-OBJECT
  and `read` is bounded by `objlen`, not by how much was written. What the gate
  catches is the object nothing in this program ever wrote.
- **Not "this covers `ukallocpool`."** Nine of twelve exported symbols are
  bound; the other three are refused above with reasons.
- **Not "the arena hang is measured."** It is derived from
  `uk_alloc_register`'s loop and `uk_alloc_init_malloc`'s tail call, and it is
  refused rather than reproduced.
- **Not "binding `free` costs image bytes."** See the measurement caveat.
- **No claim about pools on a non-default allocator.** `create` builds on
  `_uk_alloc_head` only. `uk_allocpool_alloc` takes any parent; selecting one
  needs a `*Heap` this module does not mint, and `unikraft/alloc` already owns
  that surface.

## Files

| | |
|---|---|
| `index.kz` | the lift |
| `tests/boot_allocpool.kz` | gate 2 — both constructors, take/write/read/give, the escape, bracketed censuses |
| `tests/boot_free_crashes.kz` | the destructor, booted; success criterion is that the machine stops |
| `tests/pool_threads_through_operations.kz` | the bare-parameter probe as a shipped control |
| `tests/negative_free_hosted_pool.kz` | **the pairing** — pool.c:383 |
| `tests/negative_object_outstanding.kz` | drain before free — pool.c:386 |
| `tests/negative_give_without_use.kz` | pillar 4 on the object |
| `tests/negative_use_after_give.kz` | double return — pool.c:114 for the same object |
| `tests/negative_pool_dropped.kz` | what the second disposal buys |
| `tests/wrapper.zig` | C-ABI seam; derives the flow list at comptime |
| `tests/main.c` | Unikraft's `main` calls `koru_main` |
