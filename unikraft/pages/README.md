# `unikraft/pages` — Unikraft's `uk_palloc` / `uk_pfree`, lifted

```koru
~import unikraft/pages

~unikraft/pages:default
| ready pager |> unikraft/pages:take(pager, count: 2)
    | pages region |> unikraft/pages:write(pages: region, at: 0, bytes: "…")
        | ok written |> unikraft/pages:read(pages: written, at: 0, len: 39)
            | view seen |> …
```

Seven tors, two phantom states, one mirrored struct that is **proven at run time
before it is used**, and a named escape hatch.

Lifted from the 02b replay's `pages.*` surface, de-prefixed (the module name now
carries what the prefix carried) and re-spined onto the
`default | ready | unavailable` shape the merged `unikraft/alloc` uses.

---

## Why this is a second module beside `unikraft/alloc`

The catalog rule is one module per sublibrary, with one stated exception:

> "A second module is legitimate only when it lifts a genuinely different C API.
> `uk_palloc`/`uk_pfree` is a different API from `uk_malloc`/`uk_free` — a
> different unit and a different allocator entry point — so `unikraft/pages`
> beside `unikraft/alloc` is right."

Three concrete differences make it more than a naming argument:

1. **The unit is a page, not a byte.** `uk_palloc(a, num_pages)` counts in pages,
   and the page size is a compile-time constant of the *kernel* (`__PAGE_SIZE`)
   that no symbol exports. A lift has to derive it or refuse. This one derives it
   and prints what it got.
2. **The release rule is splittable.** `alloc.h:344-347`: "pages obtained in a
   single palloc may be freed through any combination of pfree calls, as long as
   each page gets freed exactly once." Nothing in `uk_malloc`'s contract
   resembles that.
3. **The linkability case is different**, and it is why this module has a struct
   mirror while `unikraft/alloc` has none. `unikraft/alloc` calls exported
   `uk_*_ifpages` implementations *directly*. There is no exported implementation
   of `palloc`: the backend's own `bbuddy_palloc` / `bbuddy_pfree` are file
   statics, and the exported `uk_palloc_compat` / `uk_pfree_compat` are the
   **fallbacks for allocators that have malloc and no page interface**
   (`alloc.c:296-320`) — the opposite of what a page-backed allocator's table
   holds. The real page interface is reachable **only** through
   `struct uk_alloc`.

---

## The tors

| tor | takes | mints | C call |
|---|---|---|---|
| `default` | — | — (branch, not state) | reads `_uk_alloc_head`; runs the layout proof |
| `available` | `*Pager` | — | `t.pavailmem` |
| `take` | `*Pager` | `<blank!>` | `t.palloc` + `uk_malloc_ifpages` (the handle) |
| `write` | `<!blank\|!filled>` | `<filled!>` | none |
| `read` | `<!filled>` | `<filled!>` | none |
| `untouched` | `<!blank>` | `<filled!>` | **none — the escape** |
| `give` | `<!filled>` | — | `t.pfree` + `uk_free_ifpages` (the handle) |

Same two-state shape as `unikraft/alloc`, and the same named escape spelled the
same way — see that README for why `untouched` and not `unused`.

---

## The `UK_ASSERT` census

### Which this lift makes unnecessary

The page path has **no assertion of its own that a caller could violate**, and
saying so is the finding. `grep -rn UK_ASSERT` over `lib/ukalloc` at HEAD
`3fdffba8` returns 38 hits, and not one of them is about `num_pages`, about the
region a `pfree` describes, or about anything else a page caller supplies. The
two assertions nearest the path — `alloc.c:198-199`, `metadata->base != __NULL`
and `metadata->num_pages != 0` — live inside `uk_free_ifpages` and are about the
*byte* allocator's own metadata.

Six of the 38 sit on the page interface, and every one is `UK_ASSERT(a)` — the
handle-exists rule. This lift retires three:

| where | function | how it is retired |
|---|---|---|
| `alloc.h:311` | `uk_do_palloc` | a `*Pager` can only be **named** inside `default`'s `\| ready` arm, so there is no program that reaches `palloc` without a registered allocator |
| `alloc.h:335` | `uk_do_pfree` | same |
| `alloc.h:397` | `uk_alloc_pavailmem` | same — this is what `available` reads |

### Which it CANNOT

| where | function | why not |
|---|---|---|
| `alloc.h:380` | `uk_alloc_pmaxalloc` | not lifted. Largest-contiguous-run is a buddy-allocator question this module does not answer, and a lift that does not bind a surface retires none of its assertions. |
| `alloc.c:581` | `uk_alloc_pmaxalloc_compat` | the compat *fallback* for allocators with no page interface. A page-backed allocator never installs it, and this module refuses any allocator that is not page-backed, so the path is unreachable here — but unreachable-by-refusal is not the same as retired, and it is not counted as one. |
| `alloc.c:594` | `uk_alloc_pavailmem_compat` | same |

**So the honest score for this module is 3 retired, 3 not — a small number, and
that is the point.** A lift that claimed to retire assertions here would be
inflating: the interesting rule in this half of `ukalloc` has *no assertion at
all*.

### The rule that has no assertion, which is the whole contribution

`alloc.h:342-347` states that `num_pages` must be non-zero and must describe the
region `uk_palloc` handed out. **Neither is asserted anywhere.** `uk_pfree` on a
page-backed allocator goes straight into `bbuddy_pfree`, which merges buddies
using the count you hand it. Pass the wrong count and the allocator merges memory
it does not own — heap corruption, no diagnostic, in release and debug alike.

> **The parameter that could be wrong does not exist.** `take` records the count;
> `give` reads it back. No tor in this module ever asks a caller for a page count
> at release.

That is not a transcribed assertion. There was nothing to transcribe.

---

## The layout proof

A mirrored struct is an ABI **claim**, and an ABI claim that is wrong corrupts
memory silently. `unikraft/blk` mirrors `struct uk_blkdev.capabilities` and
guards it with `@offsetOf` assertions — which prove the mirror is
self-consistent and say nothing about the C it is mirroring. Here the C can be
interrogated at run time, so it is. Four tests, all inside `default`:

1. `_uk_alloc_head` is non-NULL — an allocator is registered.
2. Slots 0..40 hold, in order, the addresses of `uk_malloc_ifpages`,
   `uk_calloc_compat`, `uk_realloc_ifpages`, `uk_posix_memalign_ifpages`,
   `uk_memalign_compat` and `uk_free_ifpages` — six exported symbols whose
   addresses this archive knows. Only `uk_alloc_init_palloc`
   (`alloc_impl.h:260-281`) produces that exact sequence, so a match proves BOTH
   that the first six fields are where `alloc.h` says AND that the default
   allocator is page-backed.
3. `palloc` and `pfree` at slots 48/56 are non-NULL.
4. Slots 80/88 do **not** hold `uk_alloc_maxalloc_ifpages` /
   `uk_alloc_availmem_ifpages`. This is the `CONFIG_LIBUKALLOC_IFMALLOC`
   detector: that option inserts two pointers after `free`, shifting everything
   below by 16 bytes, which is exactly where those two symbols would land. Test 2
   cannot see the shift because it is entirely above the inserted fields; test 4
   is what closes it.

Then the page size, **derived**: `uk_alloc_availmem_ifpages` is
`pavailmem << __PAGE_SHIFT` exactly (`alloc.c:354`), so the ratio of the two
exported no-argument totals IS the page size. It is checked for
power-of-two-at-least-4-KiB before it is believed.

**If any test fails, `default` takes `| unavailable` and names which one.**
Because `default` is the only source of a `*Pager` and `take` is the only source
of a `*Pages`, nothing in this module is reachable after a refusal. There is no
degraded path: no fallback to byte allocation, no "assume the common layout", no
zero returned in place of an answer.

Cost: four to twelve pointer compares, once. A program calls `default` once and
threads the `*Pager`.

---

## Gate 1 — `--check`

```
$ koruc --check unikraft/pages/index.kz
✓ Shape checking passed
```

## Gate 2 — it boots

**A separate image from `unikraft/alloc`'s, on purpose.** The two modules lift
separate C entry points, and one image importing both would prove them only
jointly: if the page path were broken in a way the byte path masked — a `pfree`
with the wrong count freeing memory the byte allocator then handed out — a single
bracketed reading over both would still balance. Two images, two brackets, two
independent proofs. The cost is one extra ~23-second build.

```sh
mkdir /tmp/ukpages && cp tests/{boot_pages.kz,wrapper.zig,main.c} /tmp/ukpages
cd /tmp/ukpages

cat > koru.json <<'EOF'
{ "paths": { "unikraft": "/abs/path/to/worktree/unikraft" } }
EOF

koruc boot_pages.kz unikraft gen
koruc boot_pages.kz                     # host link fails on Unikraft symbols;
                                        # that is expected
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

Booting from ROM..pages at start: 15984 free x 4096 B/page (size derived, not assumed)
take(2):        two raw pages straight out of uk_palloc
pages at end:   15984 free x 4096 B/page
```

Three things that output proves:

1. **The layout proof passed on a real image.** Reaching `| ready` at all is
   those four tests passing against `ukallocbbuddy` as `ukboot` registered it.
2. **The page size was derived, not assumed** — 4096, printed, from the ratio of
   two exported totals. `__PAGE_SIZE` is a kernel compile-time constant that no
   symbol exports.
3. **The free-page count brackets the program and comes back equal** — 15,984
   pages before and after. `uk_pfree` takes a page count that nothing in ukalloc
   asserts; this lift never asks the caller for it, and two equal numbers are
   what proves the recorded count was the right one.

### Measured

| | |
|---|---:|
| `boot_pages.kz` freestanding archive | 13,192 B |
| `boot_pages.kz` bootable unikernel | 168,704 B |
| baseline: `hello.kz` with its own Kconfig (reproduces `BUILD.md`) | 164,544 B |
| build, from clean | ~23 s |

**No boot-time number and no "faster than C" claim** — both forbidden by the
brief, and neither benchmark exists.

## Gate 3 — two misuses that fail to compile

Phantom validation fires in the **emit** pass, not in `--check`. Both pass
`koruc --check` and are refused by `koruc <file>`. Diagnostics verbatim.

**`tests/negative_give_without_use.kz`** — reserve two pages, give them straight
back. 8 KiB out of a 2 MB floor, taken and returned with no work done.

```
error[KORU030]: Phantom state mismatch: expected 'unikraft.pages:filled' but got 'unikraft.pages:blank!' for argument 'pages'
  --> negative_give_without_use.kz:35:0
    |
 35 | | ready pager |> unikraft/pages:take(pager, count: 2)
    | ^
```

**`tests/negative_read_before_write.kz`** — read a page region nothing wrote. The
buddy allocator does not zero the pages it hands out, so this is a read of the
previous tenant's bytes.

```
error[KORU030]: Phantom state mismatch: expected 'unikraft.pages:filled' but got 'unikraft.pages:blank!' for argument 'pages'
  --> negative_read_before_write.kz:28:0
    |
 28 | | ready pager |> unikraft/pages:take(pager, count: 2)
    | ^
```

The control is `boot_pages.kz`, which compiles clean through the emit pass and
boots.

---

## The discharge wall does not guard later arms — and which guarantees rest on it

The same live compiler defect that `unikraft/alloc` pins in
`tests/frontier_failure_arm_leak.kz` applies here, and this module has no
separate pin because one pin per defect is enough — read that file.

> **Only a tor's FIRST declared branch has its payload obligations tracked for
> discharge.** A handle handed back on a later branch can be bound and discarded
> with no diagnostic. The STATE wall on later arms is intact; only the DISCHARGE
> wall is missing.

**Which of this module's guarantees rest on the un-enforced arms:**

| guarantee | arm | enforced today? |
|---|---|---|
| `write \| rejected` hands back `<blank!>` — the thing that keeps a refused write from satisfying the gate | 2nd | **NO** |
| `read \| rejected` hands back `<filled!>` | 2nd | **NO** |
| `take \| pages`, `write \| ok`, `read \| view` | 1st | yes |

This module is **less exposed than `unikraft/alloc`**, and for a structural
reason worth naming: it has no `resize`. The headline un-enforced arm over there
is `resize | refused` handing back a still-owed original — the failed-realloc
leak. There is no `prealloc` in ukalloc, so this module's later arms carry a
handle only on refused *accesses*, never on a refused *reallocation*. The two
rows above can still be bound and dropped, and today the compiler will not say so.

---

## Claims I do not make

- **The splittable release is NOT modelled.** `alloc.h:344-347` permits giving
  back a 4-page region as four separate `pfree`s. This module gives back exactly
  what it took, in one call. A splittable obligation — one `<filled!>` becoming
  two, each separately owed — is a real design and it is not this one. Modelling
  it half-way (a `split` handing back two handles the compiler cannot prove
  partition the original) would be worse than saying no, because it would look
  like a proof and not be one.
- **Not "the page size is known."** It is *derived*, and if it cannot be derived
  `default` refuses. There is no "assume 4096" anywhere in this module.
- **Not "the ABI is guaranteed."** It is *checked*, at run time, against six
  exported symbol addresses, and the check is what makes a `*Pager` exist. That
  is stronger than `@offsetOf` self-consistency and weaker than a compile-time
  guarantee; it is what is available.
- **Not "this covers ukalloc's page interface."** `uk_alloc_pmaxalloc` is not
  lifted — a caller sizing a page request wants free pages, which `available`
  gives, and largest-contiguous-run is a buddy-allocator question this module
  does not answer.
- **No boot-time number, no "faster than C".** Both forbidden by the brief.
- **The 3-of-6 assertion score is small and is not dressed up.** The interesting
  rule in this half of `ukalloc` has no assertion at all; the contribution is the
  parameter that no longer exists, not a count.

## Files

| | |
|---|---|
| `index.kz` | the lift |
| `tests/boot_pages.kz` | gate 2 — take/write/read/give with a bracketed page count |
| `tests/negative_give_without_use.kz` | the asymmetry gate at page granularity |
| `tests/negative_read_before_write.kz` | reading pages nothing wrote |
| `tests/wrapper.zig` | C-ABI seam; derives the flow list at comptime |
| `tests/main.c` | Unikraft's `main` calls `koru_main` |
