# `unikraft/alloc` — Unikraft's `ukalloc`, lifted

```koru
~import unikraft/alloc

~unikraft/alloc:default
| ready heap |> unikraft/alloc:take(heap, bytes: 64)
    | block scratch |> unikraft/alloc:write(block: scratch, bytes: "…")
        | ok filled |> unikraft/alloc:read(block: filled, at: 0, len: 47)
            | view small |> …
```

Ten tors, two phantom states, no struct mirror, and one named escape hatch.

This module is a **merge of three independent lifts**, not a pick of one. Three
contestants were handed `ukalloc` on 2026-08-06; all three booted, all three
refused their negatives, and each was right about something the other two were
wrong about. What is here is the ruled combination, with each piece attributed to
where it came from.

| piece | from | why |
|---|---|---|
| `default \| ready heap \| unavailable why`, `take` taking the heap | **02c** | in C, "no allocator registered" and "out of memory" are the same NULL — a silent fallback |
| read-before-write refused | **02c**, **02b** | 02a permitted it; that is the one place 02a was overruled |
| `take.zeroed` minting `<live!>` | **02c** | `uk_calloc` is a different C function that really writes the bytes |
| strict `free` + a named escape | **02a**, **02b** | overrules 02c's deliberate permissive `free` — see below |
| `take.aligned` | **02a** | 02c judged it impossible; 02a booted a 4096-aligned DMA buffer and disproved that |
| `available` as one number | **02c** | over 02b's three `avail.*` readings |
| `autodischarge_covers_later_arms.kz` | **02b**, corrected | a later-arm handle IS auto-discharged; the file records the mis-attribution |
| `uk_palloc`/`uk_pfree` | **02b** | moved OUT, to `unikraft/pages` — a different C API, a different unit |

---

## The tors

| tor | takes | mints | C call |
|---|---|---|---|
| `default` | — | — (branch, not state) | reads `_uk_alloc_head` |
| `available` | — | — | `uk_alloc_availmem_total` |
| `take` | `*Heap` | `<raw!>` | `uk_malloc_ifpages` |
| `take.zeroed` | `*Heap` | `<live!>` | `uk_malloc_ifpages` + memset |
| `take.aligned` | `*Heap` | `<raw!>` | `uk_posix_memalign_ifpages` |
| `write` | `<!raw\|!live>` | `<live!>` | none |
| `read` | `<!live>` | `<live!>` | none |
| `resize` | `<!live>` | `<live!>` | `uk_realloc_ifpages` (or memalign+copy+free, aligned) |
| `untouched` | `<!raw>` | `<live!>` | **none — the escape** |
| `free` | `<!live>` | — | `uk_free_ifpages` |

Two states, and they are about the CONTENTS, not a lifecycle. `raw` is memory you
own whose contents are garbage. `live` is memory you own whose contents you put
there.

`unikraft/blk` needed an eight-state ratchet because `ukblkdev` has a state
machine. `ukalloc` does not — no configure, no start, no stop — and inventing one
would be feature-maximalism wearing a safety badge. All three contestants
refused to ratchet a symmetric pair, independently, which is the strongest
evidence the brief's restraint rule reads clearly.

---

## The `UK_ASSERT` census

Counted with `grep -rn UK_ASSERT alloc.c stats.c include/uk/alloc.h` against
`unikraft` HEAD `3fdffba8`. **38 assertions.**

**29 of the 38 are the single expression `UK_ASSERT(a)`** — *the allocator handle
is not NULL*. That is one rule with 29 sites, an existence rule and not an
ordering rule, and `default` is what dissolves it: downstream, a `*Heap` can only
be **named** inside the `| ready` arm, so there is no program in which an
allocation is attempted against an allocator that was never registered.

**The proof rides on the BRANCH, not on a state.** No phantom state was spent on
the allocator, and none was needed. State is not the only thing that can carry a
proof, and reaching for it when a branch already does is how state counts get to
fourteen.

But the 29 must not be banked as one number, because this module does not bind
all 29 entry points, and *not offering a feature is not retiring its check.* Each
site was attributed to its enclosing function and sorted.

#### A. Retired — 8 sites this lift's emitted calls actually traverse

| where | function | reached |
|---|---|---|
| `alloc.c:154` | `uk_malloc_ifpages` | `take`, `take.zeroed`, and inside `uk_realloc_ifpages` |
| `alloc.c:187` | `uk_free_ifpages` | `free`, `resize` |
| `alloc.c:212` | `uk_realloc_ifpages` | `resize` |
| `alloc.c:244` | `uk_posix_memalign_ifpages` | `take.aligned`, and `resize` on an aligned block |
| `alloc.c:348` | `uk_alloc_availmem_ifpages` | `available`, via `uk_alloc_availmem_total` |
| `alloc.h:311` | `uk_do_palloc` | transitively — `uk_malloc_ifpages` calls `uk_palloc` |
| `alloc.h:335` | `uk_do_pfree` | transitively — `uk_free_ifpages` calls `uk_pfree` |
| `alloc.h:389` | `uk_alloc_availmem` | `available`, via `uk_alloc_availmem_total` |

#### B. Retired — 6 sites on the ergonomic entry points this lift REPLACES

`alloc.h:145` `uk_do_malloc`, `:171` `uk_do_calloc`, `:202` `uk_do_realloc`,
`:234` `uk_do_posix_memalign`, `:265` `uk_do_memalign`, `:290` `uk_do_free`.

These are the wrappers a C caller is meant to use, and their `UK_ASSERT(a)`
exists precisely because a caller might hand over a null allocator. A Koru
program cannot: it does not name the allocator, and it cannot reach one outside
`| ready`. This is the core of the claim, and it is the group where "retired"
means the most.

#### C. NOT retired — 15 sites on surfaces this module does not bind

| where | functions |
|---|---|
| `alloc.h` :362 :372 :380 :397 | `uk_alloc_addmem`, `uk_alloc_maxalloc`, `uk_alloc_pmaxalloc`, `uk_alloc_pavailmem` |
| `alloc.c` :327 | `uk_alloc_maxalloc_ifpages` |
| `alloc.c` :385 :400 :423 :451 | the four `*_ifmalloc` implementations — an IFMALLOC image this lift refuses to run in |
| `alloc.c` :503 :548 :570 | `uk_realloc_compat`, `uk_calloc_compat`, `uk_memalign_compat` — the vtable-dispatching fallbacks; this lift calls the `_ifpages` implementations directly |
| `alloc.c` :581 :594 | `uk_alloc_pmaxalloc_compat`, `uk_alloc_pavailmem_compat` |
| `stats.c` :45 | `uk_alloc_stats_get` |

A Koru program cannot fire any of these either — but only because it cannot call
them at all, which is a different and much weaker thing. Counting them would be
the easiest inflation available in this file. `unikraft/pages` retires three of
them (`alloc.h:311`, `:335`, `:397`) on its own terms, in its own README.

### The 5 this lift makes unnecessary structurally

| where | expression | how it is retired |
|---|---|---|
| `alloc.c:109` | `UK_ASSERT(ptr >= __PAGE_SIZE + METADATA_IFPAGES_SIZE_POW2)` | a plausibility test on an integer, and `do {} while(0)` in every shipped image. `free` accepts a `*Block<!live>` and nothing else; the only sources of a `*Block` are the three `take`s. A stack address, a string literal, an interior pointer or an integer cast to a pointer are not programs that exist. |
| `alloc.c:198` | `UK_ASSERT(metadata->base != __NULL)` | reads metadata on a page the allocator may have already recycled. Unreachable here: `free` consumes the block, so double-free is a `Use-after-discharge` compile error. |
| `alloc.c:199` | `UK_ASSERT(metadata->num_pages != 0)` | same |
| `alloc.c:386` | `UK_ASSERT(a->free_backend)` | IFMALLOC-only path this lift does not enter — it calls `uk_free_ifpages` directly. |
| `alloc.c:401` | `UK_ASSERT(a->malloc_backend)` | same |

### The 4 this lift CANNOT make unnecessary — stated plainly

| where | expression | why not |
|---|---|---|
| `alloc.c:310` | `UK_ASSERT(intptr <= (__uptr) metadata)` | an underflow check inside `uk_posix_memalign_ifpages`, on the allocator's own arithmetic. This lift *does* call that function, and still cannot retire this: no caller supplies the values, so there is no caller-side mistake to prevent and nothing for a lift to take away. |
| `alloc.c:488` | `UK_ASSERT(intptr <= (__uptr) metadata)` | the same check inside `uk_posix_memalign_ifmalloc` — same reason, and additionally on an IFMALLOC path this lift never enters. |
| `stats.c:46` | `UK_ASSERT(dst)` | the statistics interface, not lifted (see *Claims I do not make*). A lift that does not bind a surface retires none of its assertions, and pretending otherwise would be the easiest and least honest sentence in this file. |
| `stats.c:64` | `UK_ASSERT(dst)` | same |

### Net

| | count |
|---|---:|
| retired — handle rule, groups A and B | **14** |
| retired — structurally, the five above | **5** |
| not retired — group C, surfaces not bound | 15 |
| not retired — internal arithmetic and stats | 4 |
| **total** | **38** |

**19 of 38 retired, 19 not.** A larger number is available by counting group C,
and it would be dishonest.

And the qualifier the brief demands: `UK_ASSERT` compiles to `do {} while(0)`
when `CONFIG_LIBUKDEBUG_ENABLE_ASSERT` is off, which it is in every image
measured here. So the 19 were not *costing* anything in a shipped image — what
this lift changes is that the guarantee they describe now holds in the shipped
image too, where before it held only in a debug build. That is the
asserts-on/asserts-off tradeoff dissolving, and it is the honest form of the
claim.

### And three things the C states and never checks at all

These are not assertions, so they are not in the census — but they are the rules
that actually bite, and each one is structural here:

- **`alloc.h:298`** — `uk_free`'s pointer "must … have been obtained from an
  object allocation function … of the same allocator `a`". Checked nowhere. Here
  the allocator rides on the block, so `free` has no allocator parameter to get
  wrong.
- **`alloc.h:211`** — `uk_realloc`'s "value of `ptr` should no longer be used
  after this call completes successfully". Prose only, no assert, no branch, no
  debug build. Here `resize` consumes the handle:
  `tests/negative_use_after_resize.kz`.
- **`uk_realloc_ifpages(a, ptr, 0)` frees `ptr` and returns NULL**
  (`alloc.c:216-219`), which is byte-identical to "the resize failed and your
  pointer is still live". One return value, two opposite ownership outcomes.
  `resize` refuses size 0 before the call, naming `free`.

---

## Why the escape is NAMED and not the default

This is the ruling that overturned 02c, which deliberately let `take` → `free`
compile. Its three arguments were good ones: a heap allocation's use IS the
reservation; the early-exit shape (`take` → the input turns out to be empty →
`free`) is ubiquitous and correct; and ukalloc contains no assertion objecting to
it, so there is nothing to lift.

The counter-argument is containment, and it is asymmetric:

> **A strict `free` plus a named escape already CONTAINS the permissive design.**
> Every program a permissive `free` accepts, this module accepts with one extra
> word in it. The permissive design cannot contain the strict one at any price.

And the extra word buys a question the permissive design cannot answer:

```
grep -r "alloc:untouched"      ->   "where do we reserve memory we never write to"
```

A unikernel with a 2 MB RAM floor genuinely asks that. Under a permissive `free`
the deliberate reservation and the silent no-op are spelled identically, so the
grep returns nothing and there is nothing else to search for.

`tests/negative_free_without_use.kz` is the refusal.
`tests/untouched_reservation.kz` is the same program spelled honestly — it
compiles clean and it boots, which is what proves the gate costs the honest
program nothing.

### Why `untouched` and not `unused`

02a spelled it `untouched`, 02b spelled it `unused`. The ruling required one name
and a reason.

**`unused` reads as *finished with*.** That is the state a block is in
immediately *before* `free`, and it is precisely the wrong suggestion at a call
site whose whole meaning is "I never wrote here". `untouched` names the fact
being asserted: no byte of this region was written by this program. The grep is
the interface, so it should read as the claim.

### The unexpected dividend, measured

Making `free` strict changed something nobody predicted, and it is worth more
than the grep. Under 02c's permissive `free`, a `<raw!>` block the program forgot
about was **auto-discharged**: the emitter inserted the `free`, silently, because
exactly one disposal existed. Under the strict gate, `<raw>` has **no disposal at
all**, so forgetting it is a hard error:

```
$ koruc probe_raw_dropped.kz
❌ Compiler coordination error: Auto-discharge failed (multiple disposal options or no disposal event)

──── diagnostics (1) ────
error[KORU030]: Resource 'b' obligation <raw!> was not discharged. Call: untouched
──────────────────────────
```

A `<live!>` block that is dropped is still auto-discharged — one unambiguous
disposal, so the emitter inserts `free` (verified: a source with one literal
`alloc:free` emitted two `free_event.handler` calls). So the two claims, stated
separately because they are different claims:

- **Forgetting a block you never wrote is a COMPILE ERROR.**
- **Forgetting a block you did write is a compile-time INSERTION**, not a catch.
  "Forgetting to free is a compile error" would be a claim this lift cannot
  support for the `live` case, so it is not made.

---

## `take.aligned` — the piece 02c judged impossible

02c left aligned allocation out, and said why: "the `Block` header sits at the
front of the allocation, and a header cannot sit in front of an
alignment-constrained region without either over-allocating by `align` bytes or
making a second allocation."

The first horn of that dilemma is simply the answer. Ask for
`alignUp(HEADER, alignment)` bytes of header instead of `HEADER`. The base comes
back `alignment`-aligned from `uk_posix_memalign_ifpages`, the header size is a
multiple of `alignment`, so `base + off` is `alignment`-aligned too. **One C
call, no side table, no second allocation.** 02a shipped exactly this and booted
it; the merged module ports it, with `off` and `alignment` stored as `u32` so the
header still fits in 32 bytes and the plain path pays nothing.

**The cost, stated rather than hidden:** for `alignment > 32` the header *is* a
full `alignment` bytes, so a 4096-aligned request wastes 4096 bytes. That is
real. It is the price of a stable handle across `resize`, and the alternatives —
a side table, or a header behind the region — trade it for a second allocation or
a second pointer chase on every access.

`free` needs no special case: `uk_free_ifpages` finds its metadata by
page-aligning the pointer down (`alloc.c:99-121`), which handles both the
`+ 32` malloc layout and the previous-page layout `uk_posix_memalign_ifpages`
uses for page-scale alignments. The boot bracket is what proves this — a wrong
base would free the wrong metadata and the closing reading would not match.

An **aligned block is grown by allocate-copy-free**, not by realloc: realloc does
not preserve alignment and POSIX has no `aligned_realloc`. That is the sequence a
careful C author writes by hand.

---

## Gate 1 — `--check`

```
$ koruc --check unikraft/alloc/index.kz
✓ Shape checking passed
```

## Gate 2 — it boots

Full recipe, run clean in an empty directory. Traps and their evidence:
`/Users/larsde/src/koru/examples/unikraft/BUILD.md`.

```sh
mkdir /tmp/ukalloc && cp tests/{boot_alloc.kz,wrapper.zig,main.c} /tmp/ukalloc
cd /tmp/ukalloc

# while developing in a worktree — see "toolchain defect 3" below
cat > koru.json <<'EOF'
{ "paths": { "unikraft": "/abs/path/to/worktree/unikraft" } }
EOF

koruc boot_alloc.kz unikraft gen        # -> Makefile.uk + Kraftfile
koruc boot_alloc.kz                     # -> output_emitted.zig
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

No disk, no network, no device model — `ukalloc` needs none.

Real console output, `\r` stripped, nothing else edited:

```
SeaBIOS (version rel-1.17.0-0-gb52ca86e094d-prebuilt.qemu.org)

iPXE (http://ipxe.org) 00:03.0 CA00 PCI2.10 PnP PMM+02FD1D60+02F31D60 CA00
Press Ctrl-B to configure iPXE (PCI 00:03.0)...

Booting from ROM..heap at start: 65466368 bytes free
take(64):        koru put these 48 bytes into a ukalloc block ok
resize(4096):    koru put these 48 bytes into a ukalloc block ok
take.zeroed(32): read 32 bytes with no write first — calloc mints live
take.aligned:    a 4096-aligned DMA buffer, header in front of it
heap at end:   65466368 bytes free
```

Four things that output proves, beyond "it runs":

1. **`resize` preserved the contents.** Line 2 is read back *after*
   `uk_realloc_ifpages` moved a 64-byte block to 4096 bytes. That is why `resize`
   takes and mints `live` rather than downgrading to `raw`.
2. **`take.zeroed` reads with no `write` in front of it.** Change it to `take` and
   the program stops compiling (`negative_read_before_write.kz`).
3. **`take.aligned` runs**, through a header sitting in front of the aligned
   payload, and its `free` recovers the right base. The *address* is not printed,
   so its alignment is not claimed here — what is claimed is that the call
   sequence works end to end and returns its memory.
4. **The heap brackets exactly** — 65,466,368 bytes before and after. Every
   `free` returned its pages. A leak of any kind — an omitted `free`, an aligned
   block released from the wrong base — is a smaller second number.

### The escape, booted

`tests/untouched_reservation.kz` — the same program `negative_free_without_use.kz`
rejects, plus `alloc:untouched`, plus a second block that really is written, so
both routes to `free` appear in one program.

```
Booting from ROM..heap at start: 65470464 bytes free
4 KiB reserved and released without a write, on purpose
4 KiB written and released the ordinary way
heap at end:   65470464 bytes free
```

The escape runs no C call, and the emitted Zig says so:

```zig
pub const untouched_event = struct {
    pub const Input = struct { block: *Block };
    pub const Output = *Block;
    pub fn handler(__koru_event_input: Input) Output {
        const block = __koru_event_input.block;
        return block;
    }
};
```

### Measured

| | |
|---|---:|
| `boot_alloc.kz` freestanding archive | 16,024 B |
| `boot_alloc.kz` bootable unikernel | 172,800 B |
| `untouched_reservation.kz` archive | 9,688 B |
| `untouched_reservation.kz` unikernel | 168,704 B |
| baseline: `hello.kz` with its own Kconfig (reproduces `BUILD.md`) | 164,544 B |
| build, from clean | ~28 s |

**No boot-time number, and none may be created.** Everything here is QEMU TCG on
arm64 with no KVM. And no "faster than C" claim: the three-way benchmark
(asserts-on C, asserts-off C, proven Koru) that would support one does not exist
and this lift did not build it. What is measured above is image bytes.

## Gate 3 — four misuses that fail to compile

Phantom validation fires in the **emit** pass, not in `--check`. All four pass
`koruc --check` and are refused by `koruc <file>`. Diagnostics verbatim.

**`tests/negative_read_before_write.kz`** — read a malloc'd block nobody wrote.

```
error[KORU030]: Phantom state mismatch: expected 'unikraft.alloc:live' but got 'unikraft.alloc:raw!' for argument 'block'
  --> negative_read_before_write.kz:44:0
    |
 44 | | ready heap |> unikraft/alloc:take(heap, bytes: 64)
    | ^
```

**`tests/negative_free_without_use.kz`** — the strict gate: allocate, hand it
straight back.

```
error[KORU030]: Phantom state mismatch: expected 'unikraft.alloc:live' but got 'unikraft.alloc:raw!' for argument 'block'
  --> negative_free_without_use.kz:42:0
    |
 42 | | ready heap |> unikraft/alloc:take(heap, bytes: 64)
    | ^
```

**`tests/negative_use_after_resize.kz`** — keep the pointer you handed to realloc.
Lifts the prose rule at `alloc.h:211`.

```
error[KORU030]: Use-after-discharge: binding 'filled' was already discharged and cannot be used
  --> negative_use_after_resize.kz:31:0
    |
 31 | | ready heap |> unikraft/alloc:take.zeroed(heap, bytes: 64)
    | ^
```

**`tests/negative_use_after_free.kz`** — write to a block after freeing it.
Double-free is the same unspellable shape.

```
error[KORU030]: Use-after-discharge: binding 'written' was already discharged and cannot be used
  --> negative_use_after_free.kz:29:0
    |
 29 | | ready heap |> unikraft/alloc:take(heap, bytes: 64)
    | ^
```

The controls are `boot_alloc.kz` and `untouched_reservation.kz`, both of which
compile clean through the emit pass and boot.

---

## CORRECTED 2026-08-06: later arms ARE guarded. The claim below was wrong.

This section previously asserted, in bold, that **only a tor's first declared
branch has its payload obligations tracked for discharge**, and listed three of
this module's guarantees as unenforced. That was carried from the 02b replay,
repeated in this README, reported up twice, and a bugfix was commissioned against
it. **It is false.** Disproved by reading the emitted program.

### What actually happens

Obligations are keyed by BINDING NAME, not by AST-node identity
(`src/auto_discharge_inserter.zig:97-98`, `addBinding:158` — `StringHashMap`
keyed on the binding's name). Arm position therefore cannot matter, and does not.

What varies is whether AUTO-DISCHARGE can elect a disposer:

- **Exactly one unattended disposer for the state** → the compiler INSERTS the
  disposal at the terminator, silently and by design. Nothing leaks and nothing
  is reported, because nothing is wrong.
- **Zero or several** → `KORU030`, naming the binding.

So a dropped handle on a later arm is not unguarded; it is *handled*. Compile
`tests/autodischarge_covers_later_arms.kz` and read the emitted Zig: the source
frees on `| ok grown` and on `| rejected r` only, and the artifact carries a
THIRD call — `free_event.handler(.{ .block = e.block })` inside the
`| refused e |>` branch, the exact arm the old claim said leaked.

The two-disposer control settles it from the other side. Give a state a second
unattended disposer and drop the LATER arm's handle:

```
error[KORU030]: Resource 'later' <live!> has multiple discharge options:
                close, scrap. Discharge explicitly.
```

It names `later` — the second arm's binding. The checker sees later arms fine.

### Why 02b's observation looked like arm position

Its controls against shipped `unikraft/blk` were real: `KORU030` fired for a
`<configured!>` handle on arm 1 and stayed silent for a `<stuck!>` handle on arm
2, in one compile. But the discriminator was the DISPOSER, not the arm.
`<stuck!>`'s only consumer is `blk:abandon` — one unattended disposer, so it was
auto-inserted. `<configured!>`'s path could not be elected, so it was reported.
Two arms, two disposer shapes, one correct compiler.

**The lesson is the one this repo already writes down**: a reproducible failure
localises the symptom, not the defect, and an asymmetry is not a mechanism. Four
labelled controls were run and the conclusion still went the wrong way, because
every control varied arm position and none varied the disposer set.

### What this means for this module's guarantees

Every arm in the table below IS enforced — as an auto-inserted disposal rather
than as a diagnostic, which is the stronger outcome:

| guarantee | arm | enforced today? |
|---|---|---|
| `resize \| refused` hands back the original in `<live!>`, still owed | 2nd | **yes** — `free` auto-inserted; verified in the emitted Zig |
| `write \| rejected` hands back `<raw!>` | 2nd | **yes** |
| `read \| rejected` hands back `<live!>` | 2nd | **yes** |
| `take \| block`, `take.zeroed \| block`, `take.aligned \| block` | 1st | yes |
| `write \| ok`, `read \| view`, `resize \| ok` | 1st | yes |

So the headline claim stands **without** the caveat this section used to attach to
it: the failed-realloc leak cannot be written by accident, the arm must be
handled, the handle is named, it cannot be misused — and if it is merely dropped,
the compiler frees it for you. The one thing to keep in mind is the flip side,
which is real: because auto-discharge is silent, *removing* a state's only
disposer is what makes the leak checker able to speak. That is why the named
escape `untouched` earns its keep, and it is recorded in
`koru/concepts/frag-a-named-escape-buys-a-diagnostic-not-just-a-grep.md`.

---

## Claims I do not make

- **Not "the emitted code is faster than C".** Forbidden by the brief, and there
  is no benchmark. The honest claim is that Koru dissolves the
  asserts-on/asserts-off tradeoff for the 34 assertions above.
- **No boot-time number.** QEMU TCG, no KVM.
- **Not "forgetting to free is a compile error."** True for a `<raw!>` block,
  false for a `<live!>` one — that is an *insertion*. Both are stated above with
  their evidence.
- **Not "reading uninitialised memory is impossible."** `<live>` is per-BLOCK,
  not per-byte; no phantom state can be per-byte. `read` is bounded by `used`
  rather than `cap`, which narrows it further, but a program that writes 1 byte
  and reads that 1 byte back is doing what the state says. What the gate catches
  is the block that was never written at all.
- **Not "this covers ukalloc."** It binds THE DEFAULT ALLOCATOR ONLY.
  `uk_alloc_register` and `uk_alloc_foreach` — the multi-allocator surface — are
  not lifted. A `Heap` per registered allocator would make "free with the wrong
  allocator" expressible again, which is exactly what carrying the allocator on
  the block prevents; doing it safely needs a per-allocator type parameter and
  blocks parameterised by it.
- **The statistics interface is not lifted.** `uk_alloc_stats_get` /
  `_uk_alloc_stats_global` fill a caller-provided `struct uk_alloc_stats` — an
  ABI mirror for a read-only diagnostic — and `CONFIG_LIBUKALLOC_IFSTATS` is off
  by default, so the symbols are in `exportsyms.uk` but not in a stock image. A
  lift that links only sometimes is worse than one that says no. This is why 2 of
  the 38 assertions are in the "cannot" column.
- **`addmem` is not lifted.** Handing a memory region to an allocator is a
  platform act, not an application one.
- **`uk_memalign` is not lifted** separately. It is `uk_memalign_compat` calling
  `posix_memalign` and discarding the errno (`alloc.c:451`); `take.aligned` is
  the same call with the errno kept.
- **Pages are not here.** See `unikraft/pages`.

## What the toolchain got wrong

Three, all surfaced by the three replays and none worked around inside
`index.kz`. The first two are 02c's findings, re-hit here; the third is 02b's.

1. **A module-local type named `Allocator` is rewritten to
   `__koru_std.mem.Allocator`.** The emitter substitutes the compiler's own
   allocator type for any parameter typed `Allocator`, ignoring the module's own
   `const Allocator` two lines above. `--check` passes; the failure is
   `use of undeclared identifier '__koru_std'` in the emitted Zig. This module
   names its handle `Heap`, which is enough to dodge it — but a library author
   has no way to know the identifier is taken.
2. **A zero-argument tor with a result binding needs `()`, and `--check` accepts
   it without.** `~lib:count: n` swallows the binding into the tor *name* and
   fails in the backend as `KORU040: unknown tor 'lib:count: n'`, pointing at a
   line the source does not have. `~lib:count(): n` works. Both boot tests here
   write `~unikraft/alloc:available(): at_start` for this reason.
3. ~~The phantom-obligation DISCHARGE wall guards only a tor's first declared
   branch.~~ **WITHDRAWN 2026-08-06 — this was not a compiler defect.** Later arms
   are guarded; auto-discharge inserts the disposal when a state has exactly one
   unattended disposer. See the correction section above and
   `tests/autodischarge_covers_later_arms.kz`.

And one that is not a compiler defect but will cost the next agent an hour
(02c's finding, confirmed here): **`unikraft` is a built-in alias pinned to the
main checkout.** `src/config.zig:242-247` seeds it to
`{{ KORU_HOME }}/../koru-libs/unikraft`, which is the main checkout regardless of
which git worktree you are standing in. A lift developed in a worktree is
invisible to `~import unikraft/<name>` until it merges, and the failure is
`KORU002: module not found` for the new directory while the already-merged
siblings resolve fine. Override with `koru.json`:

```json
{ "paths": { "unikraft": "/abs/path/to/worktree/unikraft" } }
```

## Files

| | |
|---|---|
| `index.kz` | the lift |
| `tests/boot_alloc.kz` | gate 2 — take/write/read/resize/free, `take.zeroed`, 4096-aligned, bracketed availability |
| `tests/untouched_reservation.kz` | the named escape, booted; the control for `negative_free_without_use.kz` |
| `tests/negative_read_before_write.kz` | reading memory nothing wrote |
| `tests/negative_free_without_use.kz` | the strict gate |
| `tests/negative_use_after_resize.kz` | `alloc.h:211`, enforced |
| `tests/negative_use_after_free.kz` | use-after-discharge; double-free is the same shape |
| `tests/autodischarge_covers_later_arms.kz` | PROOF — a later-arm handle is auto-discharged; compiles and boots by design. |
| `tests/wrapper.zig` | C-ABI seam; derives the flow list at comptime |
| `tests/main.c` | Unikraft's `main` calls `koru_main` |
