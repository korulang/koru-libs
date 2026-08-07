# `unikraft/paging` — Unikraft's page tables, lifted, and switched to live

`lib/ukpaging` is the layer beneath `unikraft/vmem`: raw page tables, not
address-space areas. `uk_vma_map` calls down into `uk_paging_page_mapx` to
actually write PTEs. Fifteen exported functions, 140 `UK_ASSERT`s — the
second-highest count of any library on the shelf — and eleven public-header
`static inline`s (eight pure arithmetic, three inline assembly reading or
writing a control register).

```koru
~import unikraft/paging

~unikraft/paging:active
| ready pt0 |> unikraft/paging:pt-clone(source: pt0)
    | ok clone |> unikraft/paging:page-map(pt: clone, at: 0x700000000000, pages: 1)
        | ok mapped |> unikraft/paging:pt-set-active(pt: mapped)
            | ok live |> …            // *** this line runs on a DIFFERENT page table
                                       //     than the one that called `pt-set-active` ***
```

This module boots a real `mov %cr3` from inside a running Koru unikernel,
proves the switch was survived, and proves the mapping it made before the
switch is the same physical memory afterward.

---

## The headline finding: a rule with no assertion, worse than a missing one

`uk_paging_pt_set_active` switches the CPU's live address space — the
machinery the program is running on. Its own doc comment states the rule in
English: *"The code of the function must be mapped into the new address
space at the same virtual address."* **No `UK_ASSERT` anywhere in
`paging.c` checks this. Nothing checks it at all.** Get it wrong and the very
next instruction fetch after the `mov %cr3` is unmapped — not a wrong answer,
not an errno, an immediate triple fault, in debug and release builds alike.

Proof the rule is real, from the C's own bootstrap: `uk_paging_init()`
(`paging.c:1478-1545`) — the **only** caller of `uk_paging_pt_init` anywhere
in the tree, grepped, zero others — does not call `pt_set_active` right
after `pt_init`. It calls `uk_paging_page_map` once per boot memory region
**first** (mapping the kernel's own code, data and boot structures into the
fresh table) and activates the table **last**. A `pt_init`'d table is a
brand-new, zeroed top-level page (`pg_pt_alloc`, `paging.c:255-259`) that
maps nothing but the directmap window until something explicitly maps into
it. Activating it directly is exactly the fatal, unasserted program the
header comment warns about — demonstrated by the one caller in the whole
tree carefully avoiding it.

This lift's types make that avoidance the ONLY option. `pt-init` mints
`<init!>`; `pt-set-active` accepts only `<!active-safe>`, reachable **only**
through `pt-clone` — a deep copy of the table this program is already
running on (`uk_paging_pt_clone` without `UK_PAGING_PAGE_FLAG_CLONE_NEW`),
which by construction maps everything the currently-executing code needs.
`tests/negative_activate_bare_init.kz` is the proof: the program that skips
straight from `pt-init` to `pt-set-active` does not compile.

**A second fatal, unasserted rule, found by reading `pt_free`, not by
grepping `UK_ASSERT`.** `uk_paging_pt_free` (`paging.c:321-341`) never checks
whether the table it is about to unmap and free is `pg_active_pt` — the
table the CPU is currently running on. Freeing the live table would free the
very page-table pages mapping the code that called `pt_free`. There is no
`UK_ASSERT(pt != pg_active_pt)` anywhere in the function. `pt-free` here
accepts `<!init|!active-safe|!detached>` and **never** `<!active>` — the
state `pt-set-active` mints is not one `pt-free` will ever take back.
`tests/negative_free_active_table.kz` is the proof.

**A third finding, a mismatch rather than a missing check — the same shape
`unikraft/store` found for refcounts, named here because it is genuinely the
same shape and the catalog's own rule says later entries should say so
plainly.** "The active page table" is a machine-wide *singleton* — one CR3
register — but this lift's obligations are per-*handle*. Calling
`pt-set-active` on a second, independent `<active-safe!>` handle mints
`<active!>` on it without doing anything to the first handle's type, which
stays `<active!>` even though at most one table is truly live at a time.
Resolved the same direction `store` resolved a refcount-vs-binding mismatch:
never smoothed over, conservative rather than wrong. A handle that *was*
activated and has since been superseded by a later `pt-set-active` on a
*different* handle can never be freed again through this lift — its type
still claims `<active!>`, and `pt-free` still refuses it. That is a real cost
(a safe program this lift will not compile) paid for a real guarantee (this
lift will never let you free the table you are currently running on).

---

## The ratchet

| tor | takes | mints | C call |
|---|---|---|---|
| `active` | — | bare `*PageTable` (no state — read-only, reusable) | `uk_paging_pt_get_active` |
| `pt-clone` | bare `*PageTable` | `<active-safe!>` | `uk_paging_pt_clone` (flags 0 — deep copy) |
| `pt-clone.empty` | bare `*PageTable` | `<detached!>` | `uk_paging_pt_clone` (`CLONE_NEW`) |
| `pt-init` | `start, len` | `<init!>` | `uk_paging_pt_init` |
| `pt-walk` | `<!active-safe>` | `<active-safe!>` (unchanged) + paddr or absent | `uk_paging_pt_walk` |
| `page-map` | `<!active-safe>` | `<active-safe!>` (unchanged) | `uk_paging_page_mapx` |
| `page-unmap` | `<!active-safe>` | `<active-safe!>` (unchanged) | `uk_paging_page_unmap` |
| `page-kmap` | `<!active-safe>` | `<active-safe!>` (unchanged) + a temp VA | `uk_paging_page_kmap` |
| `page-kunmap` | `<!active-safe>` | `<active-safe!>` (unchanged) | `uk_paging_page_kunmap` |
| `pt-set-active` | `<!active-safe>` | `<active!>` | `uk_paging_pt_set_active` — **the switch** |
| `run-forever` | `<!active>` | — (terminal) | none — the disposer `<active!>` forces |
| `virt-to-phys` | bare `at: u64` | bare `paddr: u64` | `uk_paging_virt_to_phys` (always the LIVE table) |
| `pt-free` | `<!init\|!active-safe\|!detached>` | — (terminal) | `uk_paging_pt_free` |
| `abandon` | `<!stuck>` | — (terminal, leaks) | none |
| `poke` / `peek` | bare `at`/`bytes`/`len` | — | none — raw memory access, NOT part of `ukpaging`'s surface |

`page-map`/`page-unmap`/`pt-walk`/`page-kmap`/`page-kunmap` are deliberately
narrower than the C: they only accept `<!active-safe>` (a cloned, not-yet-
switched-to table), never `<!init>` and never `<!active>`. The C permits
mapping into a bare `<init!>` table too — that is exactly what
`uk_paging_init`'s own bootstrap does — but this lift has no honest way to
source a genuinely free physical range for `pt-init` (see *What this lift
does not attempt*), so it never needed that path, and narrowing avoided a
real design question (how to preserve a union input's exact branch through a
non-consuming tor) that this module's actual boot demo never had to answer.

### Why `page-map`/`page-unmap` mint the SAME state name they take

`unikraft/vmem:read.frozen` takes `<!frozen>` and returns `<frozen!>` —
identical name, because reading a frozen area does not change whether it is
frozen. The same non-consuming shape applies here: mapping or unmapping a
page does not change whether the *table* is the one `pt-set-active` will
accept. This is what makes the boot demo's ordering possible — map,
`pt-walk`, `page-kmap`/`page-kunmap` all happen while the clone is still
`<active-safe!>`, i.e. still eligible for the switch afterward.

### The disposer `<active!>` forces a program to name

`pt-free` never accepts `<!active>` (the second headline finding). That
means a program which activates a table and means to keep running on it has
**no path back to a terminal, freed state through this lift, by design** —
there genuinely is none, on the C's own terms, short of activating a
*different* table first. `run-forever` names that acknowledgement in one
grep-able word, the same convention as `unikraft/vmem:abandon` and
`unikraft/blk:io.skipped`. It runs no C call; there is nothing to call.

**Corrected in the writing, the same way `unikraft/mpi`'s README describes
correcting one:** the first draft of this README (and of
`tests/auto_discharge_applies_run_forever.kz`) claimed that walking away from
an activated table without calling `run-forever` would be refused as a leak.
It is not — `run-forever` is the *unique* single-parameter, void,
`<!active>`-accepting tor in this module, so Koru's auto-discharge pass
silently splices it in at scope exit under default settings, exactly the
mechanism `unikraft/mpi` names for its own `abandon`. Verified with
`koruc --auto-discharge=disable`, which reproduces the originally-expected
`KORU030: Resource 'live' carries obligation <active!> was not discharged`.
The file is kept as a control, not deleted — the corrected claim is the
useful fact.

### `page-kmap`/`page-kunmap` — the clean symmetric pair, and honestly why

On x86_64 native these compile to `pgarch_directmap_paddr_to_vaddr(paddr)`
(arithmetic — `arch/x86_64/include/uk/paging/arch.h:71-77`) and a no-op
respectively: the temporary mapping is "free" on this platform because all
of physical memory is already directmapped. Stated plainly rather than
implied: this lift does not claim the pair is expensive to earn here. The
*contract* is real and general — the doc says explicitly "the number of
concurrently k'mapped pages may be limited," a genuine constraint on
platforms whose kmap is a small fixed window, not native's. No ordering
constraint beyond pairing: `unikraft/vmem`'s "not everything deserves a
ratchet" note about `ukalloc` applies here too.

---

## What this lift does not attempt

- **`pt-init` is lifted and phantom-typed, but never exercised in the live
  boot demo.** `uk_paging_pt_init(pt, start, len)` needs a physical range
  that is genuinely free — not backing this program's code, stack, heap, or
  any other live mapping. Discovering that honestly needs
  `ukplat_memregion_foreach` or the frame allocator `uk_paging_init` already
  owns, and **neither is on `ukpaging`'s own 15-symbol surface**. Handing
  `pt-init` a physical range this lift merely guessed was free — e.g. the
  backing of one of its own static buffers — would violate the C's own
  stated contract ("the range must not be assigned to other page tables") in
  a way nothing would catch until two allocators handed out the same frame
  twice. Reaching into `uk_falloc`/`ukplat_memregion` to solve it would cross
  the brief's "bind at the native altitude" rule. So `pt-init` ships honestly
  typed and honestly unexercised. `tests/negative_activate_bare_init.kz`
  still proves its fatal-if-activated-directly state is refused — that proof
  needs the compiler's phantom check, not a running frame allocator.
- **`uk_paging_pt_add_mem`, `uk_paging_page_set_attr`,
  `uk_paging_page_mapx`'s custom `mapx` callback, and `uk_paging_init`
  itself are not bound.** `pt_add_mem` extends a pool this lift never
  legitimately creates (see above). `page_set_attr` is a real, lift-able
  surface (the `unikraft/vmem`-shaped freeze/thaw story) that this lift
  chose not to take on top of everything else — a genuine gap, not a
  judgement that it doesn't matter. The `mapx` callback is an escape hatch
  for callers who want to intercept every PTE write; nothing here needs it.
  `uk_paging_init` is Unikraft's own one-shot platform bootstrap
  (`plat/common/memory.c` calls it unconditionally whenever
  `CONFIG_LIBUKPAGING` is on, before `koru_main` ever runs) — calling it a
  second time would re-run `uk_paging_pt_add_mem` over memory the frame
  allocator already tracks, which is at best redundant and at worst
  corrupting; nothing enforces call-once on it, so this lift simply never
  calls it.
- **No struct mirror, and this is a genuine "zero ABI transcription" case
  like `unikraft/mpi`'s.** `struct uk_pagetable` is a real, public,
  non-`#ifdef`-guarded-by-default struct — but this module never reads or
  writes one of its fields; every accessor is a real exported C call
  (`pt-get-active`, `pt-walk`, …). So no offset claim is needed, only an
  upper bound on the struct's *size*, to allocate storage for a caller-owned
  instance the way `pt_init`/`pt_clone` require. `PT_STORAGE_BYTES` is one
  page — three orders of magnitude more than the struct needs even with
  `CONFIG_LIBUKPAGING_STATS` on (3 scalars + 3 `unsigned long[5]` arrays, at
  most ~144 bytes) — so this lift makes no precise-sizeof claim the way
  `unikraft/lock` had to correct one, because it does not need one.
- **Alignment of the virtual address in `page-map`/`page-unmap` is NOT
  validated by this lift.** `uk_pal_paddr_isvalid`/canonical-form checks are
  retired (see the census), but `UK_PAL_PAGE_Lx_ALIGNED(vaddr, level)`
  (`paging.c:537` and its recursive-walk siblings) is not — a caller passing
  a non-4096-aligned `at` reaches the C with the check compiled out. The
  boot demo never exercises this because its scratch addresses are
  round-number-aligned by construction, not because the gap was closed.
  Stated here rather than left to be discovered.
- **Page attributes and the PTE format are hardcoded, not derived** — the
  same judgement call `unikraft/vmem` made for `PROT_READ`/`PROT_WRITE`.
  `page.h:57-58`'s protection bits and `x86_64.h:186`'s PTE-present bit are
  ISA facts on x86_64 (not Kconfig-chosen), so there is nothing to probe
  for. A platform that renumbered them would be caught by a page fault, not
  a refusal.
- **`UK_PAL_PADDR_INV` is reused by citation from `unikraft/vmem`'s already-
  proven value, not independently re-derived** — see *toolchain and design
  defects found* below for why re-deriving it on this platform is not even
  possible.

---

## Linkability verdict

**Case 1.** `lib/ukpaging/exportsyms.uk` exists and lists all 15 symbols this
module names — `uk_paging_pt_get_active`, `_pt_set_active`, `_pt_init`,
`_pt_clone`, `_pt_free`, `_pt_walk`, `_page_mapx`, `_page_unmap`,
`_virt_to_phys`, `_page_kmap`, `_page_kunmap`. 0 phantom, 0 inert — every
listed symbol has a real definition and none is `static inline`.

**Case 3, split three ways, exactly as `unikraft/vmem` corrected the rule.**
Eleven public-header `static inline`s in `include/uk/paging.h`:

- **FREE (8):** `uk_paging_paddr_isvalid`, `_paddr_range_isvalid`,
  `_vaddr_isvalid`, `_vaddr_range_isvalid` — pure arithmetic over an
  exported data symbol (`uk_plat_native_x86_64_pg_maxphysaddr`) or pure sign-
  extension, reconstructed in this lift's `vaddrCanonical`. `uk_paging_pte_read`
  and `_pte_write` are array-index loads/stores through a pointer this lift
  already has (`pt_vaddr`, from `pt-walk`) — no symbol needed either. Neither
  is called directly by this module (they are internal to the C's own
  `pt_walk`/`page_mapx`), but they are FREE by the same reasoning `vmem`
  applied to `uk_vma_map_anon`.
- **ASM, case 3 NO (3):** `uk_paging_pt_read_base`/`_pt_write_base` (`movq`
  to/from `%cr3`) and `_tlb_flush_entry`/`_tlb_flush` (`invlpg`, and a CR3
  reload built from the same two ASM primitives). Nothing to call, only
  something to re-emit — and this lift does not re-emit them: it calls the
  exported `uk_paging_pt_set_active`/`pt_get_active` wrappers instead, which
  already do this arithmetic in C.

**One count that does not match the shelf table, corrected here.** The
shelf's measured row says "8F/3A" (11 total). This lift's own read of
`include/uk/paging.h` finds **10** `static inline`s, not 11, split 6 FREE
(the four validity checks plus `pte_read`/`pte_write`) / 4 ASM
(`pt_read_base`, `pt_write_base`, `tlb_flush_entry`, `tlb_flush` — the last
of which is itself built from the first two, not a fifth primitive). The
discrepancy is one function, and this README states its own count rather
than force-fitting the shelf's — the shelf's script and this lift's manual
read may be counting the same header at a different point in the include
chain; re-measuring the shelf script's exact methodology was out of scope
here.

---

## The `UK_ASSERT` census

`grep -rn UK_ASSERT lib/ukpaging` at HEAD `3fdffba8` returns **140** —
128 in `paging.c`, 12 across `arch/x86_64/` and `arch/arm64/` (6 each). This
lift targets x86_64/qemu only, so the 6 arm64 sites are a different
platform's code path and are not counted further.

### Retired — 16 sites, 6 distinct rules

| `paging.c` | assertion | rule | how it is retired |
|---|---|---|---|
| 316 | `pt_clone`: `pt != pt_src` | can't clone into yourself | `pt-clone`/`pt-clone.empty` always `malloc` a fresh destination; the source is a bare `*PageTable` that is never the same value as the freshly-allocated one |
| 97, 98 | `pt_clone`: source `pt_vbase`/`pt_pbase` != INV | source must be initialized | the source is always `active`'s handle, which the C itself only ever populates |
| 325, 326 | `pt_free`: `pt_vbase`/`pt_pbase` != INV | target must be initialized | `pt-free` only accepts `<!init\|!active-safe\|!detached>`, every value of which was minted by `pt-init`/`pt-clone`/`pt-clone.empty` |
| 387, 388 | `pt_walk`: `pt_vbase`/`pt_pbase` != INV | same | `pt-walk` only accepts `<!active-safe>` |
| 390 | `pt_walk`: `uk_pal_vaddr_isvalid(vaddr)` | canonical address | `pt-walk` calls the FREE reconstruction `vaddrCanonical` first and returns `absent` rather than forwarding a non-canonical address |
| 847, 848 | `page_mapx` wrapper: `pt_vbase`/`pt_pbase` != INV | init check | `page-map` only accepts `<!active-safe>` |
| 538 | `pg_page_mapx`: `uk_pal_vaddr_range_isvalid(vaddr, len)` | canonical range | `page-map` calls the same `vaddrCanonical` check first |
| 535 | `pg_page_mapx`: `len > 0` | non-zero length | `page-map` refuses `pages == 0` with a named reason before the call |
| 1223, 1224 | `page_unmap` wrapper: `pt_vbase`/`pt_pbase` != INV | init check | `page-unmap` only accepts `<!active-safe>` |
| 1438 | `page_kmap`: `pages > 0` | non-zero | `page-kmap` refuses `pages == 0` |
| 1454 | `page_kunmap`: `pages > 0` | non-zero | `page-kunmap` skips the C call entirely when `pages == 0` |

### The two rules with NO assertion at all — the contribution

Named above at length: `uk_paging_pt_set_active` on a table that does not
map the running code (fatal, unasserted — the whole reason this slot was
open), and `uk_paging_pt_free` on the table the CPU is currently running on
(fatal, unasserted, found by reading `pt_free`, not by grepping). Neither
appears in the 140 — that is the point. Counted here, not in the table
above, the same way `unikraft/vmem` counted its two fatal rules separately
from its 20-site retirement table.

### Not lifted, and why — 124 sites

- **Virtual-address alignment (page-map/page-unmap/pt-walk), roughly a dozen
  direct sites plus their recursive-walk siblings.** `UK_PAL_PAGE_Lx_ALIGNED`
  checks at `paging.c:537, 692-693, 970, 1045, 1254, 1321` and others are not
  retired — this lift validates canonical form, not page alignment. Stated
  under *What this lift does not attempt*.
- **`virt_to_phys`'s three (`paging.c:1422, 1424, 1425`).** Cannot be
  retired: `uk_paging_virt_to_phys` has `__paddr_t` as its return type with
  no error sentinel, so there is no signature this lift could refuse through
  even if it wanted to. Named plainly rather than banked as retired.
- **`pt_init`'s own two (`paging.c:243, 244`).** `pt-init` checks
  `len == 0` itself but does not validate `start`/`len` against
  `uk_pal_paddr_range_isvalid` or overflow — and `pt-init` is not exercised
  live, so this gap has never been tested against a real value.
- **`page_set_attr`'s whole family (~15 sites, `paging.c:1230-1410`) and
  `pt_add_mem`'s (2 sites plus arch's `addmem`-non-null check).** Neither
  function is bound at all.
- **The bulk — roughly 90 sites — is internal recursive-walk machinery in
  `pg_page_mapx`, `pg_page_split`, `pg_page_unmap`, `pg_pt_clone`'s own
  descent.** These guard invariants about page-table *levels* mid-walk
  (`lvl > PAGE_LEVEL`, `pte_idx < PTES_PER_LEVEL`, split bookkeeping) that no
  caller of this lift's 15-symbol surface can directly parameterize: this
  module only ever requests base-level (4 KiB) pages, never sets
  `UK_PAGING_PAGE_FLAG_FORCE_SIZE`, and never supplies a custom `mapx`
  callback. The same bucket blk's null-pointer family and vmem's `uk_vas_init`
  family fell into — hygiene the C's own recursion keeps for itself, not an
  ordering rule a caller of this surface can violate. Given this library's
  count is the highest reason to take the slot, this bucket is named as a
  bucket rather than padded into 90 individual rows that would all say the
  same thing.

---

## Gate 1 — `--check`

```
$ koruc --check unikraft/paging/index.kz
✓ Shape checking passed
```

## Gate 2 — it boots, and the switch is survived

Recipe, run clean from a copy of the whole `unikraft/` tree (every entry
file declares `unikraft: {{ ENTRY }}/../..` in its own source, so a flat
directory breaks the import — see `koru/examples/unikraft/BUILD.md`):

```sh
mkdir /tmp/paging && cp -R unikraft /tmp/paging/
cd /tmp/paging/unikraft/paging/tests

koruc boot_paging.kz unikraft gen        # -> Makefile.uk + Kraftfile
koruc boot_paging.kz                     # -> output_emitted.zig
                                          #    (host link fails on Unikraft
                                          #     symbols; that is expected)
zig build-lib wrapper.zig \
    -target x86_64-freestanding -O ReleaseSmall \
    -fno-stack-protector -femit-bin=libkoruapp.a
UK_CFLAGS="-std=gnu17" kraft build --arch x86_64 --plat qemu --no-prompt

qemu-system-x86_64 -kernel .unikraft/build/koru_qemu-x86_64 \
  -cpu 'qemu64,+pdpe1gb,+rdrand,+rdseed,-vmx,-svm' \
  -m 256M -nographic -no-reboot -display none -parallel none
```

**`-m 256M`, not the usual `64M`.** Measured directly: at 64M this boots,
prints through the switch, and then the FINAL cleanup flow's `page-map`
fails with `errno -12` (`-ENOMEM`) — `pt-clone` deep-copies the *entire*
page-table hierarchy it is cloning, so cloning a table that is itself
already a clone (this test clones three times across its three flows)
triples the page-table-page cost paid from the same shared frame pool.
64M genuinely runs out; 256M does not. This is a real, measured cost of
`pt-clone`, not a demo artifact — recorded under *toolchain and design
defects found* below since it was found the same way, by booting and
reading the console rather than by inspection.

Real console output, verbatim, from the exact tree state committed here:

```
SeaBIOS (version rel-1.17.0-0-gb52ca86e094d-prebuilt.qemu.org)

iPXE (http://ipxe.org) 00:03.0 CA00 PCI2.10 PnP PMM+0EFD1D60+0EF31D60 CA00
Press Ctrl-B to configure iPXE (PCI 00:03.0)...

Booting from ROM..empty clone: built from the SAME uk_paging_pt_clone call, CLONE_NEW set -- freed untouched
before map: scratch address NOT present in the clone -- confirmed free
after map: PRESENT at paddr 266924032 -- page-map wrote a real PTE, still in a table nobody is running on
wrote via kmap alias, kunmapped -- about to switch. if nothing prints after this line, the switch was NOT survivable
still alive after mov %cr3 -- this code stayed mapped across the switch
read back via the SCRATCH mapping, post-switch: KORU WROTE THIS THROUGH THE DIRECTMAP KMAP ALIAS, BEFORE THE SWITCHvirt-to-phys cross-check: 266924032 -- matches page-map's own paddr above
lifecycle complete
```

What that proves, line by line:

1. **`pt-clone.empty` produces a real, distinct, freeable table** — the
   `CLONE_NEW` flag's whole contribution, freed before the deep-copy flow
   even starts.
2. **`pt-walk` reports absent before the map** — the scratch address
   `0x700000000000` was confirmed free structurally, not assumed.
3. **`page-map` wrote a real PTE at a sane physical address** (266,924,032 —
   inside the 256 MB the VM actually has), in a table that at this point is
   *not* the CPU's active one. Page-table mutation and activation are
   independent, the same fact `uk_paging_init`'s own bootstrap depends on.
4. **The switch was survived.** `pt-set-active` ran a real `mov %cr3`, and
   the very next line of Koru executed — the only proof a CR3 switch admits.
5. **The mapping was real, not a coincidence.** The bytes read back through
   the scratch VA (only reachable through the clone, and only after the
   switch) match the bytes written earlier through the kmap VA (only
   reachable through the directmap, before the switch) — two different
   virtual addresses, on two different sides of the switch, proven to name
   the same physical frame.
6. **`virt-to-phys`'s answer (266,924,032) matches `pt-walk`'s own PTE
   extraction exactly** — two independent reads of the physical address,
   one via the raw PTE this lift decoded itself, one via the C's own
   translation function, agreeing.
7. **`lifecycle complete`** — the final flow's `pt-clone` →`page-map` →
   `page-unmap` → `pt-free` chain ran end to end on a table that was never
   the CPU's active one.

### Measured

| | |
|---|---:|
| Koru freestanding static archive | 18,760 B |
| bootable unikernel image | 180,992 B |
| baseline (`examples/unikraft/hello.kz`, no ukpaging) | 164,544 B |

The 16,448 B over baseline is `LIBUKPAGING` (which pulls in `LIBUKPAL`,
`LIBUKFALLOC`, `LIBUKFALLOCBUDDY`) and this module's own code.

No boot-time number. Everything here is QEMU TCG on arm64 host with no KVM,
and this project does not have a boot-time claim to make.

---

## Gate 3 — three misuses that fail to compile, through the FULL pipeline

Phantom validation fires in the **emit** pass, not `--check`. All three pass
`koruc --check` and are refused by `koruc <file>`. Diagnostics verbatim.

**`tests/negative_activate_bare_init.kz`** — the headline rule. Skip
straight from `pt-init` to `pt-set-active`.

```
$ koruc --check negative_activate_bare_init.kz
✓ Shape checking passed

$ koruc negative_activate_bare_init.kz
error[KORU030]: Phantom state mismatch: expected 'unikraft.paging:active-safe' but got 'unikraft.paging:init!' for argument 'pt'
  --> negative_activate_bare_init.kz:33:0
```

**`tests/negative_free_active_table.kz`** — the second headline rule. Clone,
switch, then try to free the table you are running on.

```
error[KORU030]: Phantom state mismatch: expected '!unikraft.paging:init|!unikraft.paging:active-safe|!unikraft.paging:detached' but got 'unikraft.paging:active!' for argument 'pt'
```

**`tests/negative_double_free.kz`** — use-after-discharge. Free a cloned
table, then free the same handle again.

```
error[KORU030]: Use-after-discharge: binding 'clone_a' was already discharged and cannot be used
```

**`tests/auto_discharge_applies_run_forever.kz`** is a control, not a
negative — see *the disposer `<active!>` forces a program to name*, above,
for what it actually demonstrates and why the first draft's claim about it
was wrong.

---

## Toolchain and design defects found

Two real defects, neither worked around inside `index.kz` or `boot_paging.kz`
by silently avoiding the *program shape* — one is a Koru parser bug the test
file routes around explicitly (and names why), the other was this lift's own
bug, fixed in the source.

### 1. A mid-chain tor call with named union arms, indented, is misparsed

Committed as a minimal, `unikraft`-independent repro:
`toolchain-repros/A_mid_chain_indented_union_call.kz` (broken) and
`toolchain-repros/B_mid_chain_indented_union_call_control.kz` (the one-line
fix — remove the indentation).

```
$ koruc --check toolchain-repros/A_mid_chain_indented_union_call.kz
error[KORU010]: stray continuation line without Koru construct
  --> A_mid_chain_indented_union_call.kz:48:9
    |
 48 |         | ready v |> std/io:print.ln("got {{ v:d }}")
    |         ^
error[KORU010]: stray continuation line without Koru construct
  --> A_mid_chain_indented_union_call.kz:49:9

$ koruc toolchain-repros/B_mid_chain_indented_union_call_control.kz
✓ Compiled … ✓ Generated output_emitted.zig … ✓ Built executable: a.out
```

Found while writing `boot_paging.kz`: every mid-chain call to
`unikraft/paging:active` (a zero-arg tor with two named arms — `ready`/
`unavailable`) hit this as soon as the surrounding chain was indented to
track the program's nesting, the way `unikraft/vmem/tests/boot_vmem.kz`'s
own deeply-nested chains are written. Isolated by bisection over roughly a
dozen variants: removing the tor's parameter list, giving the empty arm a
payload, reordering the arms, renaming the tor — none of it changed the
outcome. Only the **indentation** of the call and its arms, relative to the
line that reaches it, does. `boot_paging.kz` works around it by never
calling `unikraft/paging:active` mid-chain at all — every use is a fresh
top-level flow statement, matching `unikraft/vmem`'s own two-flow
convention, which happens to never have exercised this shape (both of
`vmem`'s `active` calls are the head of their flow, never mid-chain). The
workaround is a **program-shape** choice stated in `boot_paging.kz`'s own
comments, not a silent rewrite of what the file was trying to say.

### 2. `UK_PAL_PADDR_INV` is not `~0`, and passing the wrong sentinel boots a garbage mapping

This lift's own bug, caught by booting, not by inspection. An earlier draft
of `page-map`'s Zig body called `uk_paging_page_mapx(pt, at, ~@as(usize, 0),
…)` — using all-ones as the "allocate a fresh physical frame for me" sentinel.
The real sentinel, `UK_PAL_PADDR_INV`, is
`UK_PLAT_NATIVE_PAGE_HUGE_ALIGN_DOWN(0xBAADBAADBAADBAAD)` — the *identical*
formula `unikraft/vmem` used for `UK_PAGING_VADDR_ANY`, because `addr.h`
defines the virtual and physical invalid-address sentinels with the same
macro over the same seed. `vmem`'s own behavioural probe already proved the
value is `0xbaadbaad80000000` on this platform.

With `~0` instead, `uk_paging_page_mapx` read `paddr != UK_PAL_PADDR_INV`
as true and treated the call as "map this virtual address to the *literal*
physical address `0xFFFFFFFFFFFFFFFF`" rather than "allocate a frame."
`uk_pal_paddr_range_isvalid` would have refused that — but that check is a
`UK_ASSERT` (`paging.c:543`) and compiles out. **The program built and
booted.** The first live QEMU run printed `after map: PRESENT at paddr
4503599627366400` (`0xffffffffff000` — plainly not a physical address
inside a 64 MB machine) and then crashed with a Unikraft `CRIT` register
dump on the very next real access. Fixed by defining `PADDR_INV =
0xbaadbaad80000000` in `index.kz`, citing `vmem`'s derivation rather than
re-deriving it (see *claims not made*, below, for why this lift could not
independently re-derive it: `page-kmap` never fails on this platform, so
there is no observable failure to compare a guess against, unlike `vmem`'s
`uk_vma_map` which does fail informatively on a bad address).

---

## Claims this lift does not make

- **Not "faster than C."** The per-call state checks this lift retires are
  `UK_ASSERT`s already compiled out in release. The honest claim is that
  Koru *dissolves* the asserts-on/asserts-off tradeoff for the ordering
  rules it lifts; demonstrating it with numbers needs a three-way benchmark
  (asserts-on C, asserts-off C, proven Koru) that does not exist here.
- **No boot-time number.** QEMU TCG, no KVM, arm64 host. Forbidden by the
  brief and not measured.
- **Not "every alignment rule is checked."** Virtual-address *canonical
  form* is retired; virtual-address *page alignment* is not (see *what this
  lift does not attempt*).
- **Not "`pt-init` was proven live."** It was proven refused when misused
  (the negative test), never proven to succeed against a real physical
  range, because this lift has no honest way to source one.
- **Not "the active-table singleton is tracked."** Two independent
  `<active-safe!>` handles can each become `<active!>` through this lift's
  types even though only one table is truly live at a time. Stated at
  length above, not buried.
- **Not "`UK_PAL_PADDR_INV` was independently re-derived here."** It is
  reused by citation from `unikraft/vmem`'s own behavioural probe, because
  `page-kmap` never fails on this platform and this lift has no observable
  failure to test a guess against — see toolchain defect 2.
- **`poke`/`peek` are not part of `ukpaging`'s C surface** and carry no
  phantom gating tying them to a specific mapped address — a raw memory
  access this lift's own boot demo uses, with the caller (here, this lift's
  own test) responsible for having proven mappedness via `pt-walk` first.
- **The shelf's "8F/3A" inline count is not reproduced here** — this lift's
  own read of `include/uk/paging.h` finds 10 static inlines (6F/4A), not 11,
  and says so rather than forcing agreement (see *Linkability verdict*).

---

## Files

| | |
|---|---|
| `index.kz` | the lift |
| `tests/boot_paging.kz` | gate 2 — the full chain, in a unikernel, ending in a real `mov %cr3` |
| `tests/negative_activate_bare_init.kz` | gate 3 — the headline rule |
| `tests/negative_free_active_table.kz` | gate 3 — the second headline rule |
| `tests/negative_double_free.kz` | gate 3 — use-after-discharge |
| `tests/auto_discharge_applies_run_forever.kz` | control — what `<active!>`'s disposal actually does under default settings |
| `tests/wrapper.zig`, `tests/main.c` | the C-ABI seam, from `koru/examples/unikraft` |
| `toolchain-repros/A_mid_chain_indented_union_call.kz` | the parser defect, minimal, no `unikraft` dependency |
| `toolchain-repros/B_mid_chain_indented_union_call_control.kz` | the one-line fix |

Measured against `unikraft` HEAD `3fdffba8`, kraftkit 0.12.15, Unikraft
0.21.0 "Ijiraq", zig 0.15.2, on macOS/arm64.
