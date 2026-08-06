# `unikraft/vmem` — Unikraft's virtual address space manager, lifted

```koru
~import unikraft/vmem

~unikraft/vmem:active
| ready vm |> unikraft/vmem:reserve(vm.space, bytes: 100)
    | area rsv |> unikraft/vmem:commit(rsv.area)
        | ok mapped |> unikraft/vmem:write(area: mapped, at: 0, bytes: "…")
            | ok written |> unikraft/vmem:read(area: written, at: 0, len: 59)
                | view seen |> …
```

Twelve tors, five phantom states, a two-field ABI mirror **proven by round-trip
before it is used**, and two kernel constants **derived by behavioural probe**
because no symbol exports them.

`ukvmem` is address mappings — a different organ from a device queue
(`unikraft/blk`) or an allocator (`unikraft/alloc`, `unikraft/pages`), and the
variance shows up in what there was to lift.

---

## The finding: two rules whose penalty is a dead machine

`unikraft/blk` transcribed 105 `UK_ASSERT`s. `unikraft/alloc` and
`unikraft/pages` found rules with *no* assertion. ukvmem has both kinds, and its
two headline rules are of the second kind — but they are worse than a missing
assertion, because the C's response to breaking them is not a wrong answer, it is
an unresolvable page fault:

**1. A reservation may not be touched.**

```c
__vaddr_t va = __VADDR_ANY;
uk_vma_reserve(uk_vas_get_active(), &va, 4096);
*(char *)va = 'x';                      /* triple fault */
```

`uk_vma_rsvd_ops` sets `.fault = __NULL` (`vma_rsvd.c:13`). `vmem_pagefault`
reaches `if (unlikely(!ctx.vma->ops->fault)) return -EFAULT;`
(`vmem.c:1093-1094`) and nothing resolves it.

**2. A read-only mapping may not be written.**

```c
uk_vma_set_attr(vas, va, 4096, PAGE_ATTR_PROT_READ, 0);
*(char *)va = 'x';                      /* unhandled page fault */
```

`vmem_access_allowed` (`vmem.c:991`) returns false; `vmem_pagefault` turns that
into the same -EFAULT (`vmem.c:1089-1090`).

**Neither has an assertion and neither could.** An assertion fires inside a
function; both of these mistakes are a store through a pointer that calls
nothing. `CONFIG_LIBUKDEBUG_ENABLE_ASSERT` makes no difference in either
direction — the debug build and the release build die identically, with no
diagnostic. Both are lifted here into phantom states, and both have a negative
test that proves the compiler refuses them.

---

## The ratchet

| tor | takes | mints | C call |
|---|---|---|---|
| `active` | — | — (branch, not state) | `uk_vas_get_active`, plus the three probes |
| `reserve` | `*Space` | `<reserved!>` | `uk_vma_map` (`uk_vma_rsvd_ops`) |
| `commit` | `<!reserved>` | `<mapped!>` | `uk_vma_map` (`uk_vma_anon_ops`, `REPLACE`) |
| `write` | `<!mapped\|!used>` | `<used!>` | none — a store through the mapping |
| `read` | `<!mapped\|!used>` | `<used!>` | none — a load through the mapping |
| `untouched` | `<!mapped>` | `<used!>` | **none — the escape** |
| `freeze` | `<!used>` | `<frozen!>` | `uk_vma_set_attr` (`PROT_READ`) |
| `read.frozen` | `<!frozen>` | `<frozen!>` | none |
| `lookup` | `*Space` | — | `uk_vma_find` |
| `release` | `<!used\|!frozen>` | — | `uk_vma_unmap` (strict) |
| `withdraw` | `<!reserved>` | — | `uk_vma_unmap` (strict) |
| `abandon` | `<!stuck>` | — | none |

### Where the asymmetry applies, and where it deliberately does not

**`release` accepts only `<!used>` or `<!frozen>`.** Both are reachable only
through a real access or through the named escape, so `commit(); release();` —
take backing memory for an address range and hand it back without ever touching
it — is not a program you can write. Same shape as `gzip/index.kz:258`'s `fed`
gate and `2104_14`'s `close` taking `<!active>` and not `<!connected>`. Proven by
`tests/negative_commit_without_use.kz`.

**`withdraw` accepts `<!reserved>` and demands nothing, on purpose.** A
reservation is address space and nothing else — no physical memory, no
page-table entries (`vma_types.h:20-35`). Reserving a gigabyte and giving it back
untouched costs the machine one `struct uk_vma`. Ratcheting the free half of a
genuinely free operation is the feature-maximalism the brief warns about, so this
lift says plainly that the reservation half is symmetric. The asymmetry sits on
the committed half, which is where the C spends memory. `tests/boot_vmem.kz`'s
second flow exercises reserve-then-withdraw deliberately and it compiles.

`withdraw` rather than an overload of `release` so the two stay separable:

```
grep -r "vmem:withdraw"   ->  address space given back, never backed
grep -r "vmem:release"    ->  a mapping torn down
grep -r "vmem:untouched"  ->  memory committed and never touched
```

### `read` and `read.frozen` are two tors, and that is forced

A single `read` accepting `<!mapped|!used|!frozen>` would have to mint one state.
Minting `<used!>` for a frozen range would hand the caller exactly the token
`write` accepts, and the next store would be rule 2 above. So the frozen read
preserves the frozen state and the writable read preserves the writable one.

### A rejected access strands the area until you say `untouched`

`write | rejected` and `read | rejected` hand the handle back in `<mapped!>`, not
`<used!>` — an access the lift refused before touching a byte must not satisfy
the gate. `release` does not accept `<mapped!>`, so the only way out is
`untouched`. That is the correct outcome, not a wrinkle: a program whose every
access was refused genuinely never touched the memory, and it has to say so in a
greppable word before it can tear the mapping down.

---

## Three parameters that no longer exist

Each one is a caller mistake ukvmem cannot detect.

**1. The address.** C's reserve-then-use dance is `uk_vma_reserve(vas, &vaddr,
len)` followed by `uk_vma_map_anon(vas, &vaddr, len, attr, UK_VMA_MAP_REPLACE,
name)` with **the same `vaddr`** (`README` example 5). Pass `__VADDR_ANY` the
second time by mistake and you get a fresh unrelated mapping somewhere else,
`rc == 0`, no assertion, and the reservation becomes a permanent hole in the
address space. Here the address lives in the handle and `commit` takes no address
at all.

**2. The `UK_VMA_MAP_REPLACE` flag.** Forgetting it returns -EEXIST
(`vmem.c:660`) — the loud version of the same mistake. `commit` sets it
unconditionally, because reaching a reservation is the only thing `commit` does.
This is what retires `vma_types.h:60`.

**3. The page alignment.** `uk_vma_map` returns -EINVAL for any length that is
not a whole number of pages (`vmem.c:634`), and the page size is a compile-time
constant of the *kernel*. `reserve` takes bytes and rounds up. The boot console
asks for 100 bytes and reports 4096.

---

## Three constants no symbol exports, and three different honest answers

A separately linked freestanding archive cannot see a `#define`. ukvmem's API
needs three of them.

### `UK_PAGING_VADDR_ANY` — **derived**

`UK_PAGING_VADDR_ANY` is `UK_PAGING_VADDR_INV` (`paging.h:199`), which is
`0xBAADBAADBAADBAAD` aligned down to a page level the archive cannot see
(x86_64 `addr.h:24-28`, arm64 `addr.h:37-42`). `active` aligns the seed down by
2^12 through 2^47 in turn and hands each candidate to `uk_vma_map` as the
requested address. Three outcomes, all distinguishable:

* the call fails — `uk_paging_vaddr_range_isvalid` refused a non-canonical
  address (`vmem.c:686`);
* the call succeeds and writes **the same** address back — the candidate was an
  ordinary free address, so it is unmapped and the search continues
  (`vmem.c:772`);
* the call succeeds and writes a **different** address back — first-fit ran
  (`vmem.c:638-648`), which happens for exactly one input value.

**That is not a guess with a plausibility check bolted on; the success condition
is a behaviour only the right value produces.** The boot console prints what it
found: `0xbaadbaad80000000`, which is the seed aligned down to 1 GiB — the x86_64
huge-page size, never named anywhere in this module.

### The page size — **derived**

`uk_vma_map` returns -EINVAL when `len` is not a whole number of pages and every
other refusal has a different code, so the smallest power of two it accepts *is*
the page size. Probe 1 uses a 65,536-byte length precisely so it does not need
this answer first (65,536 is a whole number of pages at 4 KiB, 16 KiB and 64 KiB
alike). The console prints 4096.

This is a different derivation technique from `unikraft/pages`', which divides
two exported availability totals. Both refuse rather than assume.

### The protection bits — **hardcoded, and not proven**

`PROT_READ` = 0x01 and `PROT_WRITE` = 0x02 are identical in both in-tree
architectures (x86_64 `page.h:56-59`, arm64 `page.h:47-50`) and belong to the
platform PAL's interface rather than to a private header. **This lift does not
prove them**, and a platform that renumbered them would be caught by a fatal page
fault rather than by a refusal. Listed under claims I do not make.

---

## The ABI mirror is two fields long, and it is proven by round-trip

`uk_vma_find` hands back a `const struct uk_vma *` and ukvmem exports no accessor
for it — `uk_vma_len` is `static inline` (`vmem.h:134`). So `lookup` needs a
mirror. It is:

```zig
const VmaHead = extern struct { start: usize, end: usize };
```

`struct uk_vma`'s first two fields are `__vaddr_t start; __vaddr_t end;`
(`include/uk/vmem.h:109-110`), and that declaration carries **no `#ifdef` at
all** — unlike `struct uk_vas` two structs above it, which gains and loses `pt`
and `vma_base` with `CONFIG_LIBUKPAGING`. Nothing here reads past `end`, so
`attr`, `flags` and `name` — which *would* depend on `struct uk_list_head` being
two pointers — are not claimed.

**Probe 3 proves it before any caller can reach it.** `active` reserves one page,
asks `uk_vma_find` for it, and requires the returned `start` and `end` to equal
the address ukvmem just chose and that address plus the page size. Three values
this archive knows independently, compared against two fields whose offsets it is
claiming. A wrong offset cannot pass by coincidence.

`unikraft/pages` proved its mirror by comparing slots against six exported symbol
**addresses**; this one proves it by round-tripping **values it controls**.
Different mechanism, same discipline: **if the proof fails there is no `*Space`,
and `reserve` is the only source of an `*Area`, so nothing in the module is
reachable.** No degraded path, no assumed page size, no "the usual layout".

---

## One VMA per area, bought with a unique name pointer

`vmem_vma_can_merge` (`vmem.c:254-266`) merges two adjacent VMAs when their ops,
attributes, flags, page level **and `name` pointer** all match — pointer
identity, not string equality. Two adjacent areas from this module sharing a name
literal would therefore collapse into one `struct uk_vma`, and a handle's range
would stop describing a VMA.

So each `Area` carries its own name bytes and hands `uk_vma_map` a pointer **into
itself**. Distinct allocations, distinct pointers, no merge ever. `lookup`'s
round-trip and `freeze`'s no-split argument both depend on it.

**The consequence, stated rather than hidden: `abandon` deliberately leaks.**
`uk_vma_map` *stores* the name pointer, it does not copy the string
(`vmem.c:734-735`). `abandon` exists for the case where an unmap refused — i.e.
where the VMA is still installed — so freeing the handle would leave the kernel a
dangling `const char *` that any VMA listing would print. An abandoned area costs
one `struct Area`. That is the honest price of an address range nobody could
unmap.

---

## Linkability verdict

**Case 1.** `lib/ukvmem/exportsyms.uk` exists and lists 20 symbols. Every symbol
this module names is on it: `uk_vas_get_active`, `uk_vma_map`, `uk_vma_unmap`,
`uk_vma_set_attr`, `uk_vma_find`, `uk_vma_rsvd_ops`, `uk_vma_anon_ops`.

**The `static inline` half is reachable by reconstruction, and that is the
non-obvious part.** The functions a C author actually calls — `uk_vma_reserve`,
`uk_vma_reserve_ex`, `uk_vma_map_anon`, `uk_vma_map_dma` — are all `static
inline` in `vma_types.h`, which is case 3. That is what cost `uknetdev` its hot
path. It costs this lift nothing, because **these inlines add no logic**: each is
`return uk_vma_map(…, &uk_vma_<kind>_ops, …)`, an exported function and an
exported data symbol. Reconstructing them is the identical call with the
identical arguments — no shim, no extra call frame, no ABI guess.

**The one exception is `uk_vma_map_stack`** (`vma_types.h:131-163`), which also
does guard-page arithmetic over `CONFIG_LIBUKVMEM_STACK_GUARD_PAGES_TOP` and
`…_BOTTOM`. Those are Kconfig constants that no symbol exports and that this lift
cannot derive from behaviour. Stack VMAs are **not lifted**; see claims I do not
make.

---

## The `UK_ASSERT` census

`grep -rn UK_ASSERT lib/ukvmem` at HEAD `3fdffba8` returns **128** hits; 126 in
the x86_64 build (one is arm64-only, one is in ukvmem's own unit tests). Most are
internal invariants of the VMA machinery for which no caller supplies a value.
What follows is every site a **caller of the surface this lift binds** could
violate.

### Retired — 20 sites

| where | function | the rule | how it is retired |
|---|---|---|---|
| `vmem.c:115` | `vmem_vma_find` | `vas` is non-NULL | a `*Space` can only be **named** inside `active`'s `\| ready` arm, and reaching that arm means `uk_vas_get_active` returned non-NULL |
| `vmem.c:140` | `vmem_vma_find_range` | `vas` is non-NULL | same |
| `vmem.c:382` | `vmem_vma_split_vmas` | `vas` is non-NULL | same |
| `vmem.c:617` | `uk_vma_map` | `vas` is non-NULL | same |
| `vmem.c:618` | `uk_vma_map` | the `__vaddr_t` out-pointer is non-NULL | the lift owns that cell; a caller never supplies a pointer, so passing NULL is unspellable |
| `vmem.c:619` | `uk_vma_map` | `ops` is non-NULL | which ops table is used is decided by **which tor you call** — `reserve` → `rsvd_ops`, `commit` → `anon_ops`. A caller never names one. |
| `vmem.c:620` | `uk_vma_map` | `len > 0` | `reserve` refuses `bytes == 0` before the call, with a named reason; `commit` reuses the length `reserve` computed, which is at least one page |
| `vmem.c:470` | `vmem_vma_unmap` | `len > 0` | same |
| `vmem.c:150` | `vmem_vma_find_range` | the range does not overflow the address space | the range comes from the handle, and `reserve` refuses a page-rounding that would overflow before it allocates anything |
| `vmem.c:466` | `vmem_vma_unmap` | same | same |
| `vmem.c:176` | `vmem_vma_find_range` | the range START is page-aligned | the start is whatever `uk_vma_map` chose, which is page-aligned by construction (`vmem.c:677`) |
| `vmem.c:214` | `vmem_vma_find_range` | the range END is page-aligned | `reserve` rounds the length up to whole pages |
| `vmem.c:451` | `uk_vma_op_unmap` | `len` is page-aligned | same |
| `vmem.c:464` | `vmem_vma_unmap` | the address is page-aligned | same as `:176` |
| `vmem.c:468` | `vmem_vma_unmap` | `len` is page-aligned | same as `:214` |
| `vmem.c:449` | `uk_vma_op_unmap` | `vaddr >= vma->start` | the handle's range **is** its VMA — see the unique-name invariant above |
| `vmem.c:450` | `uk_vma_op_unmap` | `vaddr + len <= vma->end` | same |
| `vmem.c:463` | `vmem_vma_unmap` | the address is inside the VMA | same |
| `vmem.c:467` | `vmem_vma_unmap` | the range end is inside the VMA | same |
| `vma_types.h:60` | `uk_vma_reserve_ex` | `flags == 0 \|\| flags & UK_VMA_MAP_REPLACE` | **the one caller-facing flags assertion in the library.** `reserve` passes 0 and `commit` passes `REPLACE`; a caller never names a flag. |

**Those 20 sites encode 8 distinct rules**, and the table is per-site on purpose
rather than banked into a headline number:

| rule | sites |
|---|---:|
| the VAS pointer exists | 4 |
| the out-pointer for the address exists | 1 |
| an ops table was supplied | 1 |
| the length is non-zero | 2 |
| the range does not overflow | 2 |
| the range is page-aligned at both ends | 5 |
| the range lies inside its VMA | 4 |
| `reserve_ex`'s flags are 0 or `REPLACE` | 1 |

### Could NOT be retired — 16 sites

| where | function | why not |
|---|---|---|
| `vmem.c:623` | `uk_vma_map` | `order >= 12` when a page size is requested. **Not lifted** — this module never sets `UK_VMA_MAP_SIZE()`, so the branch is unreachable from here. Unreachable-by-not-lifting is not retirement, and it is not counted as one. |
| `vmem.c:628` | `uk_vma_map` | the requested page level exists on this architecture. Same. |
| `vmem.c:54` | `uk_vas_init` | `vas` is non-NULL. **Not lifted** — this module uses the address space `ukboot` installed and never creates one. |
| `vmem.c:55` | `uk_vas_init` | `pt` is non-NULL. Same. |
| `vmem.c:56` | `uk_vas_init` | the allocator is non-NULL. Same. |
| `vmem.c:64` | `uk_vas_init` | the VMA base is a valid virtual address. Same. |
| `vmem.c:83` | `uk_vas_destroy` | the VMA list is empty when the VAS goes away. **Not lifted** — a lift that tore down the kernel's own address space would take the kernel with it. |
| `vmem.c:928` | `vmem_vma_advise` | `vma` is non-NULL. **Not lifted** — `uk_vma_advise` is not bound; see claims I do not make. |
| `vmem.c:929` | `vmem_vma_advise` | the advised range does not overflow. Same. |
| `vmem.c:930` | `vmem_vma_advise` | the advised range is inside the VMA. Same. |
| `vmem.c:931` | `vmem_vma_advise` | the advised address is aligned. Same. |
| `vmem.c:933` | `vmem_vma_advise` | the advised length is aligned. Same. |
| `vma_types.h:138` | `uk_vma_map_stack` | `premapped_len` is page-aligned. **Not lifted** — stack VMAs need the Kconfig guard-page constants, which no symbol exports and which this lift cannot derive. |
| `vma_types.h:139` | `uk_vma_map_stack` | no page-size order was requested. Same. |
| `vma_types.h:151` | `uk_vma_map_stack` | `len` is page-aligned. Same. |
| `vma_types.h:202` | `uk_vma_map_dma` | the physical address is page-aligned. **Not lifted** — a DMA VMA takes a `__paddr_t` the caller got from the frame allocator, which is `ukfalloc`'s surface, not ukvmem's. |

### One that is neither, and is worth naming

`vmem.c:116` — `UK_ASSERT(vaddr <= __VADDR_MAX - len)` in `vmem_vma_find`. On the
`uk_vma_find` path `len` is 0 (`vmem.c:128`), so the condition is true for every
input. It is not retired by this lift; it was already unreachable in the C.
Counted in neither column.

### And the rules with no assertion at all, which are the contribution

The two fatal ones at the top of this file, and one more: **`uk_vma_unmap` and
`uk_vma_set_attr` cannot fail partway — they crash the machine.**
`vmem_vma_unmap` calls `UK_CRASH` if the unmap handler refuses (`vmem.c:477`) and
`vmem_vma_set_attr` does the same (`vmem.c:802`). So the `| failed` arms of
`release`, `withdraw` and `freeze` cover only what `vmem_vma_split_vmas` can
report (-ENOENT, -ENOMEM), and they say so. A lift that offered a rich error
taxonomy there would be inventing one.

---

## Gate 1 — `--check`

```
$ koruc --check unikraft/vmem/index.kz
✓ Shape checking passed
```

## Gate 2 — it boots

```sh
# From a tree where `{{ ENTRY }}/../..` still names this `unikraft/` directory,
# because the namespace is declared in the test's own source. Copying just the
# .kz file somewhere flat breaks the alias.
cp -R unikraft /tmp/ukvmem/unikraft
cd /tmp/ukvmem/unikraft/vmem/tests

koruc boot_vmem.kz unikraft gen     # -> Makefile.uk + Kraftfile
koruc boot_vmem.kz                  # -> output_emitted.zig; the HOST link then
                                    #    fails on the Unikraft symbols, expected
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

Booting from ROM..vas ready:  page size 4096 B, VADDR_ANY 0xbaadbaad80000000 (both DERIVED, neither assumed)
reserve:    asked 100 B, got 4096 B at 0x000000100006f000 -- address space only, touching it would fault
commit+rw:  anonymous memory, demand-paged, at an address ukvmem picked
frozen:     anonymous memory, demand-paged, at an address ukvmem picked
before rel: uk_vma_find reports 4096 B at 0x000000100006f000
after rel:  nothing at 0x000000100006f000 -- the bracket closes
reserve:    8192 B of address space at 0x000000100006f000, never committed
before wd:  uk_vma_find reports 8192 B at 0x000000100006f000
after wd:   nothing at 0x000000100006f000 -- address space given back untouched
```

Six things that output proves:

1. **The three probes passed on a real kernel.** Reaching `| ready` at all means
   `VADDR_ANY` was derived, the page size was derived, and the `struct uk_vma`
   mirror round-tripped. Both derived numbers are on the line.
2. **`0xbaadbaad80000000` is the seed aligned to 1 GiB** — x86_64's huge-page
   size, which this module never names. The probe found the alignment, not a
   table.
3. **The rounding is the lift's.** The program asks for 100 bytes and the console
   reports 4096. `uk_vma_map` would have returned -EINVAL for 100.
4. **The memory is real.** The bytes come back out of a demand-paged anonymous
   mapping at an address ukvmem chose; nothing was mapped there until the store
   faulted a page in through `vma_op_anon_fault`.
5. **The range is still readable after `freeze`** — and the compiler refused the
   write that would follow it. Read-only means read-only, not gone.
6. **The bracket closes twice.** `uk_vma_find` reports the right span at the right
   address before each teardown and reports nothing after it. Without
   `UK_VMA_FLAG_STRICT_VMA_CHECK` `uk_vma_unmap` returns 0 over a range that was
   never there (`vmem.c:520-521`), which is why this lift always sets it.

   The second reservation lands at **the same address** the first one occupied.
   That is first-fit reusing the range `release` gave back, and it is a second,
   independent reading of the same fact.

### Measured

| | |
|---|---:|
| `boot_vmem.kz` freestanding archive | 25,168 B |
| `boot_vmem.kz` bootable unikernel | 193,568 B |
| baseline: `hello.kz` with its own Kconfig (`BUILD.md`) | 164,544 B |
| build, from a clean tree (`.unikraft/` sources already fetched) | 31 s |

The 29 KB over baseline is `LIBUKVMEM` + `LIBUKPAGING` + `LIBUKFALLOC` +
`LIBUKLCPU` and this module's own code; `hello.kz` links none of them.

**No boot-time number and no "faster than C" claim** — both forbidden by the
brief, and neither benchmark exists.

## Pillar 2, read out of the emitted program rather than asserted

`koruc boot_vmem.kz` writes `output_emitted.zig`, and the phantom machinery is
not in it. `commit`'s handler is the proc body and nothing else:

```zig
pub fn handler(__koru_event_input: Input) Output {
    const area = __koru_event_input.area;
    var va = area.start;
    const rc = uk_vma_map(area.vas, &va, area.len, PROT_RW, MAP_REPLACE,
                          areaName(area), &uk_vma_anon_ops, null);
    if (rc != 0) { return .{ .refused = … }; }
    return .{ .ok = area };
}
```

And the emitted `Area` carries no state field:

```zig
const Area = extern struct {
    vas: *Vas, start: usize, len: usize, name: [10]u8, hex: [18]u8,
};
```

`vas`, `start` and `len` are what any C author would keep; `name` is the
merge-prevention described above, which a C author wanting the same invariant
would also keep; `hex` is 18 bytes of console formatting and is the one thing
here a C version would not have. **Five states, twelve tors, zero run-time state
words.** `reserved` and `frozen` appear in the emitted file only inside comments,
binding names and printed strings.

---

## Gate 3 — three misuses that fail to compile

Phantom validation fires in the **emit** pass, not in `--check`. All three pass
`koruc --check` and are refused by `koruc <file>`. Diagnostics verbatim, and each
produces exactly one — the one it is about.

**`tests/negative_write_before_commit.kz`** — the headline. Reserve address space
and store into it.

```
error[KORU030]: Phantom state mismatch: expected '!unikraft.vmem:mapped|!unikraft.vmem:used' but got 'unikraft.vmem:reserved!' for argument 'area'
  --> negative_write_before_commit.kz:48:0
    |
 48 | | ready vm |> unikraft/vmem:reserve(vm.space, bytes: 4096)
    | ^
```

**`tests/negative_write_after_freeze.kz`** — store into a range made read-only.

```
error[KORU030]: Phantom state mismatch: expected '!unikraft.vmem:mapped|!unikraft.vmem:used' but got 'unikraft.vmem:frozen!' for argument 'area'
  --> negative_write_after_freeze.kz:46:0
    |
 46 | | ready vm |> unikraft/vmem:reserve(vm.space, bytes: 4096)
    | ^
```

**`tests/negative_commit_without_use.kz`** — the asymmetry gate. Put memory
behind a reservation and tear it down untouched.

```
error[KORU030]: Phantom state mismatch: expected '!unikraft.vmem:used|!unikraft.vmem:frozen' but got 'unikraft.vmem:mapped!' for argument 'area'
  --> negative_commit_without_use.kz:49:0
    |
 49 | | ready vm |> unikraft/vmem:reserve(vm.space, bytes: 4096)
    | ^
```

The control is `boot_vmem.kz`, which reaches `✓ Generated output_emitted.zig` in
the same emit pass and boots. **The diagnostic is `KORU030` and not `KORU002` in
all three**, which is what proves the namespace declaration is doing its job:
main's checkout has no `unikraft/vmem` at all, so a fall-through to the built-in
alias would have failed as a missing module and read exactly like a broken
obligation wall.

---

## Claims I do not make

- **Not "the protection bits are proven."** `PROT_READ` = 0x01 and `PROT_WRITE` =
  0x02 are hardcoded from two headers that agree. Every *other* kernel constant
  this module needs is derived; these two are not, and a platform that renumbered
  them would be caught by a fatal page fault rather than by a refusal. This is
  the one place the module makes an unverified ABI claim, and it is here rather
  than buried.
- **Stack VMAs are NOT lifted.** `uk_vma_map_stack` needs
  `CONFIG_LIBUKVMEM_STACK_GUARD_PAGES_TOP` and `…_BOTTOM` to compute where the
  usable stack starts inside the VMA. Those are Kconfig integers with no exported
  symbol and no behavioural probe that recovers them. A lift that guessed them
  would hand back a stack pointer inside a guard page.
- **DMA VMAs are NOT lifted.** `uk_vma_map_dma` maps a physical range the caller
  already owns. Producing that `__paddr_t` is `ukfalloc`'s job, and a lift that
  bound the mapping without binding the frame allocation would be handing out
  half a resource.
- **`uk_vma_advise` is NOT lifted.** `UK_VMA_ADV_DONTNEED` frees the physical
  memory behind a range while leaving the VMA readable — a real transition, and
  one whose honest model is a state this module does not have. Naming it here
  rather than adding a half-modelled tor.
- **Huge pages are NOT lifted.** `UK_VMA_MAP_SIZE_2MB` / `_1GB` bring alignment
  rules on both the address and the length that would have to be surfaced to the
  caller, which is the opposite of what `reserve` is for.
- **`freeze` is one-way in this lift, and that is a restriction this module adds
  rather than a claim about ukvmem.** `uk_vma_set_attr` will happily restore
  `PROT_WRITE`. A `thaw` is buildable and it would make `<frozen>` a suggestion
  rather than a guarantee for the rest of the program, which is the whole value of
  the state. A program that needs to write again should not freeze.
- **Not "one address space."** `uk_vas_init` and `uk_vas_set_active` are exported
  and this module binds neither. It works in the address space `ukboot`
  installed, which is the only one a stock unikernel has, and it says so by
  refusing when there is none.
- **Not "the mirror is guaranteed."** It is *checked*, once, at run time, against
  three values this archive knows independently. That is stronger than `@offsetOf`
  self-consistency and weaker than a compile-time guarantee; it is what is
  available.
- **`abandon` leaks by design** — one `struct Area` per abandoned range, because
  the kernel holds a pointer into it. Stated above, not buried.
- **No boot-time number, no "faster than C".** Both forbidden by the brief, and
  neither benchmark exists.

## Files

| | |
|---|---|
| `index.kz` | the lift |
| `tests/boot_vmem.kz` | gate 2 — the ratchet and the symmetric half, two flows, two brackets |
| `tests/negative_write_before_commit.kz` | touching a reservation |
| `tests/negative_write_after_freeze.kz` | writing through a read-only mapping |
| `tests/negative_commit_without_use.kz` | the asymmetry gate |
| `tests/wrapper.zig` | C-ABI seam; derives the flow list at comptime |
| `tests/main.c` | Unikraft's `main` calls `koru_main` |
