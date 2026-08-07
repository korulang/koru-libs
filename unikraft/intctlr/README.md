# unikraft/intctlr — Unikraft's interrupt controller (`ukintctlr`), lifted

`lib/ukintctlr/ukintctlr.c` sits between a real interrupt controller driver
(`xpic` on x86_64, `gic` on arm) and everything else in Unikraft that wants an
interrupt line. It owns two independent resources — an allocable-IRQ bitmap
and a per-IRQ handler-slot table — that no shipped lift on this shelf had
touched: "an organ nothing shipped touches" per the shelf's own row.
`grep -rn "uk_intctlr_irq_alloc\|uk_intctlr_irq_free" .` outside
`lib/ukintctlr` itself returns nothing anywhere in this fork — the bitmap has
no caller at all before this lift. Not a naive wrap: both resources are
behind real ratchets, both retire real `UK_ASSERT`s, and the boot demo drives
every tor through the real C.

```koru
~import unikraft/intctlr

~unikraft/intctlr:alloc()
| ok line |> unikraft/intctlr:register(line.irq, handler_fn: tok, arg: 0)
    | ok h |> unikraft/intctlr:unregister(h)
        | ok |> unikraft/intctlr:free(line)
        | failed x |> unikraft/intctlr:abandon(x.line)
    | failed x |> unikraft/intctlr:handler.abandon(x.h)
| exhausted e |> …
```

## The two resources, and why they are not nested

```
alloc          mints  <allocated!>                    uk_intctlr_irq_alloc
free           needs  <!allocated>                     uk_intctlr_irq_free
abandon        needs  <!allocated|!stuck>              NO C CALL — leak the line on purpose

register       mints  <registered!>                    uk_intctlr_irq_register
unregister     needs  <!registered>                     uk_intctlr_irq_unregister
handler.abandon needs <!stuck>                          NO C CALL — give up on a handler the C already dropped

configure, init, status — no obligation
```

It would be tempting to require `register` to take an `<!allocated>` line,
nesting `Handler` inside `Irq`. The C refuses that reading:
`plat/kvm/x86/time.c:74` registers the boot timer's handler on IRQ 0 —
`uk_intctlr_irq_register(0, timer_handler, NULL)` — and IRQ 0 is never
allocated (it is below `UK_INTCTLR_FIRST_ALLOCABLE_IRQ = 16`). Fixed,
well-known IRQ lines (legacy PIC 0–15) are registered directly, with no
bitmap involved at all. Forcing every `register` through `alloc` first would
make the platform's own timer program — the one every boot of this image
already runs — unspellable. So the two resources are separate handle types,
composable but not nested. `boot_intctlr.kz` exercises both shapes: flow D
composes them (allocate, then register on the allocated line); flow E
registers directly on a fixed, never-allocated line.

## Why `uk_intctlr_irq_mask`/`unmask` are not exposed — they do not link

Both are ordinary, non-`static` functions defined in `ukintctlr.c` — but
`lib/ukintctlr/exportsyms.uk` (11 lines, the allowlist, case 1) does not list
either name. `objcopy --keep-global-symbols` localizes every global not on
that list, so a separately linked Koru archive cannot call them. This has a
real consequence: `register` unmasks the line it installs a handler on
(`ukintctlr.c:103`), but `unregister` never calls `mask_irq` anywhere in its
body — the C leaves the line unmasked after the last handler is removed.
Even if this lift wanted to close that gap, it structurally cannot: the only
function that could re-mask a line is not linkable from here. Named as a
real ceiling in the assert census below, not smoothed over.

## Why `uk_intctlr_irq_fdt_xlat` is not exposed — it is a guaranteed crash

`uk_intctlr_irq_fdt_xlat` is on the allowlist, has a real definition, and its
guard `UK_ASSERT(uk_intctlr->ops->fdt_xlat)` (`ukintctlr.c:222`) compiles to
nothing in every shipped image. On x86_64/xpic — this lift's only target —
`drivers/ukintctlr/xpic/pic.c:34` sets `pic_ops.fdt_xlat = __NULL`
UNCONDITIONALLY. There is no code path on this platform that ever populates
it. Calling `uk_intctlr_irq_fdt_xlat` here is a guaranteed NULL indirect
call, in debug and release alike, on every invocation — the same
`allocpool`/`UK_CRASH` shape the brief warns about: "an assertion guarding a
call nobody can complete is not an assertion you can retire." This lift does
not expose `fdt_xlat` at all.

## Why `uk_intctlr_irq_handle` is not exposed

It is on the allowlist and links, and takes one argument:
`struct uk_lcpu_except_irq_ctx *`, an opaque platform trap frame. Koru code
has no legitimate way to construct one. Nothing needs to: the xpic driver
already wires it into the real interrupt path automatically
(`UK_EVENT_HANDLER(UK_LCPU_EXCEPT_EVENT_IRQ, uk_intctlr_xpic_handle_irq)`,
`drivers/ukintctlr/xpic/ukintctlr.c:102`), so a handler this lift registers
via `register` genuinely runs on a real hardware interrupt without this lift
ever calling `irq_handle` itself. See "What I left out" for why the boot
demo does not (and, on this platform, cannot safely) trigger that delivery
live.

## An off-by-one this lift corrects rather than reproduces

`ukintctlr.c` declares `irq_handlers[MAX_IRQ][MAX_HANDLERS_PER_IRQ]` (valid
row indices `0 .. MAX_IRQ-1`, `MAX_IRQ = 224` on x86_64/xpic) and guards every
access with `UK_ASSERT(irq <= MAX_IRQ)` at four call sites
(`allocate_handler`, `register`, `unregister`, `irq_handle`) — all of them
admitting `irq == MAX_IRQ`, one row past the end. `register`/`unregister`
below refuse `irq >= MAX_IRQ`, strictly, closing the gap the C's own `<=`
leaves open.

## The other range mismatch, and why this lift never needs its own check for it

`uk_intctlr_irq_free`'s bound check is
`irqs[i] >= FIRST_ALLOCABLE_IRQ(16) && irqs[i] <= LAST_ALLOCABLE_IRQ(224)` —
but `uk_intctlr_irq_alloc` can never produce `224`: it finds a zero run
starting at a bit index `< ALLOCABLE_IRQ_COUNT (208)`, so the highest real
IRQ number it can ever hand out is `207 + 16 = 223`, one less than what
`free`'s own assert admits. A caller who constructed `irq = 224` by hand and
passed it to `uk_intctlr_irq_free` would clear a bitmap bit no `alloc` call
ever sets — not a memory-safety bug (`UK_BITS_TO_LONGS(208)` rounds the
backing storage up to 256 bits, so bit 208 is still inside the array), but a
logic bug the C's own `UK_ASSERT(rc)` two lines later exists to catch, and
which evaporates the moment asserts are off. This lift's `free` tor does not
take a bare `irq: u32` — it takes `*Irq<!allocated>`, and the only tor that
mints `<allocated!>` is `alloc`, which can never produce `224`. The mismatch
is real in the C and UNREACHABLE through this lift's typed surface, with no
extra bound check needed.

## The aliasing hazard — the deepest finding here

`allocate_handler` finds any free slot with no de-duplication: calling
`register(irq, sameFunc, arg)` TWICE installs the same function pointer in
two different slots, and this lift mints two INDEPENDENT `Handler<registered!>`
obligations — one per Koru-level call, matching the C's one-call-one-slot
contract. But `uk_intctlr_irq_unregister`'s removal loop
(`ukintctlr.c:122-133`) does not stop at the first match — it `goto recheck`s
and clears every slot in that IRQ's row that still holds `func`, compacting
the rest left with `memmove`. So ONE `unregister` call on ONE of the two
`Handler` objects silently discharges BOTH slots at the C level, while only
one Koru obligation was consumed. The second `Handler`'s `unregister` then
finds nothing left to remove: the real C returns `-ENOENT`
(`ukintctlr.c:140`, `"Invalid irq handler ... for irq"`), which this lift
surfaces rather than swallows, landing the second handle in `<stuck!>` — the
only safe move once the C's own state has diverged from what this lift's
per-binding obligation assumed.

This is the direct analogue of `unikraft/store`'s refcount-vs-per-binding
finding, applied to a different C shape: store found that a REFCOUNT (a
count) and a phantom obligation (a claim about ONE binding) do not agree
about how many holders exist; here, the C's dedup-BY-VALUE unregister
collapses two Koru-level claims into one C-side fact. Reproduced live in
`boot_intctlr.kz`, flow E — the console shows the real `uk_pr_crit` line the
C itself prints for the failed second `unregister`.

## Gate 1 — `--check`

```
$ koruc --check unikraft/intctlr/index.kz
✓ Shape checking passed
```

## Gate 2 — it boots

Recipe (traps and their evidence: `/Users/larsde/src/koru/examples/unikraft/BUILD.md`):

```sh
mkdir /tmp/intctlr && cp -R unikraft /tmp/intctlr/
cd /tmp/intctlr/unikraft/intctlr/tests

koruc boot_intctlr.kz unikraft gen    # -> Makefile.uk + Kraftfile
koruc boot_intctlr.kz                 # -> output_emitted.zig
                                       #    (host link then fails on the
                                       #     Unikraft symbols; expected)
zig build-lib wrapper.zig \
    -target x86_64-freestanding -O ReleaseSmall \
    -fno-stack-protector -femit-bin=libkoruapp.a
UK_CFLAGS="-std=gnu17" kraft build --arch x86_64 --plat qemu --no-prompt

qemu-system-x86_64 -kernel .unikraft/build/koru_qemu-x86_64 \
  -cpu 'qemu64,+pdpe1gb,+rdrand,+rdseed,-vmx,-svm' \
  -m 32M -nographic -no-reboot -display none -parallel none
```

`boot_intctlr.kz` runs six short flows (A–F) — see the file's header comment
for the map. Real console output, verbatim, boot banner elided:

```
heap at start:  31899648 bytes free
== flow A: status — the subsystem is already active before this program runs ==
status:         uk_intctlr already registered, name=PIC (set by plat/kvm/x86/setup.c before koru_main ever ran)
== flow B: the bitmap — allocate two lines, free the first, allocate again, see it reused ==
alloc:          line 16 allocated (a)
alloc:          line 17 allocated (b), expect b == a + 1
free:           line a freed, its bitmap bit is open again
alloc:          line 16 allocated (c), expect c == a, the reused low bit
free:           line b freed
free:           line c freed — the bitmap is back where it started
== flow C: configure — a real call, inert on this platform's stub, freed after ==
alloc:          line 16 allocated for the configure demo
configure:      ok — uk_intctlr_irq_configure ran (xpic's configure_irq stub always returns 0)
free:           configure demo's line freed
== flow D: the composed path — allocate a line, register a real handler on it, unregister, free ==
alloc:          line 16 allocated for the register demo
nop.handler:    token obtained — a real, C-ABI-callable, always-safe handler this module owns
register:       ok — uk_intctlr_irq_register installed nopHandler on line 16 and unmasked it
unregister:     ok — uk_intctlr_irq_unregister removed it (the line stays unmasked — see the header note)
free:           the register demo's line was freed
== flow E: the aliasing hazard — the same handler registered twice on a FIXED, never-allocated line ==
nop.handler:    token obtained
register:       ok — first registration of nopHandler on irq 50 (never allocated — see "TWO RESOURCES, NOT ONE")
register:       ok — SECOND registration of the SAME handler on the SAME irq, a distinct C-side slot
unregister:     ok — uk_intctlr_irq_unregister's removal loop cleared BOTH slots matching this func (ukintctlr.c:122-133), not just this one
[    0.111055] CRIT: [libukintctlr] <ukintctlr.c @  139>  Invalid irq handler 0x11261e for irq 50  unregister:     failed, as predicted — uk_intctlr_irq_unregister found no matching slot left (-ENOENT): the aliasing hazard, live
== flow F: init — the documented no-op ==
init:           ok — uk_intctlr_init's body genuinely is "nothing for now; return 0" — see the header note on why its own UK_ASSERT(irqs disabled) is unsatisfiable from here
heap at end:    31899648 bytes free
```

The `[ 0.111055] CRIT: ...]` line is the real `uk_pr_crit` Unikraft's own
`uk_intctlr_irq_unregister` prints on the path this lift's flow E deliberately
drives it down (`ukintctlr.c:139`) — not a crash, a loud log line, printed by
the C itself, interleaved with this lift's own print because both write to
the same console with no lock between them. **The heap brackets exactly**:
`31899648` at start, `31899648` at end, after six lines allocated and freed,
one register/unregister pair, one aliasing-hazard pair whose second handle
goes through `handler.abandon` (frees only this lift's own wrapper, same
shape `unikraft/mpi:abandon` already proved), and one `configure` call. No
leak anywhere across all six flows.

| | |
|---|---:|
| Koru freestanding static archive (`libkoruapp.a`) | 29,584 B |
| baseline (`examples/unikraft/hello.kz`, no intctlr) | 164,544 B |

No boot-time number. Everything here is QEMU TCG on x86_64 with no KVM, and
this project does not have a boot-time claim to make.

## Gate 3 — misuses that fail to compile

Phantom validation fires in the **emit** pass, not `--check`. All three pass
`koruc --check` and are refused by plain `koruc <file>`, no flags.

**`negative_handler_never_discharged.kz`** — register a handler, walk away.
Unlike `unikraft/intctlr:Irq`'s `abandon` (void, no branches — the exact
shape Koru's auto-discharge pass elects, matching `unikraft/mpi`'s own
finding), the only tor accepting `<!registered>` is `unregister`, which
BRANCHES (`ok`/`failed`). Auto-discharge only elects a void, branch-free
acceptor, so `unregister` does not qualify and this program is refused under
default settings — not merely under `--auto-discharge=disable`.

```
$ koruc --check negative_handler_never_discharged.kz
✓ Shape checking passed

$ koruc negative_handler_never_discharged.kz
error[KORU030]: Resource 'h' obligation <registered!> was not discharged. Call: unregister
  --> negative_handler_never_discharged.kz:26:0
❌ Compiler coordination error: Auto-discharge failed (multiple disposal options or no disposal event)
```

**`negative_line_use_after_free.kz`** — free a line, then use the same
handle again (the Koru twin of a double `uk_intctlr_irq_free`). This is the
exact mistake the compiler caught by accident while writing
`boot_intctlr.kz`'s flow D — see "A load-bearing catch" below — pinned here
on purpose.

```
$ koruc --check negative_line_use_after_free.kz
✓ Shape checking passed

$ koruc negative_line_use_after_free.kz
error[KORU030]: Use-after-discharge: binding 'line' was already discharged and cannot be used
  --> negative_line_use_after_free.kz:31:0
❌ Compiler coordination error: Phantom semantic validation failed
```

**`negative_handler_abandon_while_registered.kz`** — register a handler,
then call `handler.abandon` directly instead of `unregister`.
`handler.abandon` accepts only `<!stuck>` — the state ONLY `unregister`'s
failure arm mints. A caller cannot launder a live registration through the
leak escape hatch just because both tors take a bare `*Handler`. The Koru
twin of `unikraft/mpi`'s `negative_abandon_after_drain.kz`.

```
$ koruc --check negative_handler_abandon_while_registered.kz
✓ Shape checking passed

$ koruc negative_handler_abandon_while_registered.kz
error[KORU030]: Phantom state mismatch: expected 'unikraft.intctlr:stuck' but got 'unikraft.intctlr:registered!' for argument 'h'
  --> negative_handler_abandon_while_registered.kz:28:0
❌ Compiler coordination error: Phantom semantic validation failed
```

**Why not a "line never discharged" test.** `unikraft/intctlr:abandon`
(the `Irq` side) is void, takes only `line`, and is the UNIQUE such acceptor
of `<allocated!>` — exactly the shape Koru's auto-discharge pass
(`src/auto_discharge_inserter.zig`) splices in unattended at scope exit,
matching `unikraft/mpi`'s own finding about its `abandon`. A program that
allocates a line and walks away compiles clean under default settings:

```
$ koruc negative_would_be_line_leak.kz --auto-discharge=warn
warning[AUTO-DISCHARGE]: Inserting 'unikraft.intctlr:abandon' to discharge 'line' (state: unikraft.intctlr:allocated!)
✓ Compiled to a.out
```

Pinning that as `compile_fail` would have been a lying test. What actually
cannot happen, under any settings, is `uk_intctlr_irq_free` running twice on
the same line or a handler outliving a bare `handler.abandon` call — both
covered above instead.

## A load-bearing catch, found while writing the boot demo

`boot_intctlr.kz`'s flow D originally printed `d0.irq` in the print
following `free(line: d0)`. The compiler refused it:
`error[KORU030]: Use-after-discharge: binding 'd0' was already discharged and
cannot be used`. This is not a bug report against the compiler — it is the
obligation system doing exactly its job on a mistake this lift's own author
made while writing the positive path, caught before the mistake ever reached
a real `uk_intctlr_irq_free` call. Fixed in the boot demo by not
re-referencing the field after the tor that consumes it, and pinned on
purpose as `negative_line_use_after_free.kz` above so the same mistake is a
permanent regression test rather than a one-off catch.

## Gate 4 — no fallbacks

Two named, greppable escape hatches: `unikraft/intctlr:abandon` (leak an
allocated line on purpose) and `unikraft/intctlr:handler.abandon` (give up
on a handler the C's own dedup-by-value unregister already dropped).
`grep -r "unikraft/intctlr:abandon"` / `grep -r "unikraft/intctlr:handler.abandon"`
each answer exactly one question. Every failure arm carries a real
`errno`/`reason`; nothing is silently substituted. `alloc`'s own
out-of-memory path for its handle wrapper frees the just-allocated line back
to the C before returning failure — this lift's own OOM path does not
reproduce the leak class it exists to prevent.

## Gate 5 — the assert census

`lib/ukintctlr/ukintctlr.c` carries all 21 of the library's `UK_ASSERT`s
(the shelf's own count, reconfirmed here by reading the file). Every one,
and what happened to it:

| file:line | assertion | disposition | why |
|---|---|---|---|
| `ukintctlr.c:74` (`allocate_handler`) | `irq <= MAX_IRQ` | **RETIRED, corrected** | `register` refuses `irq >= MAX_IRQ` before any C call — strict, closing the C's own off-by-one (`<=` admits `irq == MAX_IRQ`, one row past the array). |
| `ukintctlr.c:88` (`register`) | `func` non-null | **RETIRED** | `register` refuses `handler_fn == 0` before any C call. |
| `ukintctlr.c:89` (`register`) | `irq <= MAX_IRQ` | **RETIRED, corrected** | Same bound check as above. |
| `ukintctlr.c:116` (`unregister`) | `func` non-null | **RETIRED, structurally** | `unregister` reads `func` from the `Handler` handle, never from a fresh caller-supplied value — the only way to mint `<registered!>` already validated it non-null. |
| `ukintctlr.c:117` (`unregister`) | `irq <= MAX_IRQ` | **RETIRED, structurally** | Same: `irq` on the handle was already validated at `register` time. |
| `ukintctlr.c:159` (`irq_handle`) | `irq <= MAX_IRQ` | **NOT APPLICABLE** | `irq_handle` is not exposed by this lift at all — no safe way to construct its `*uk_lcpu_except_irq_ctx` argument; the platform calls it automatically. |
| `ukintctlr.c:192` (`irq_mask`) | `uk_intctlr && ops` non-null | **NOT APPLICABLE** | `irq_mask` is not linkable — absent from `exportsyms.uk`, localized by `objcopy`. |
| `ukintctlr.c:199` (`irq_unmask`) | `uk_intctlr && ops` non-null | **NOT APPLICABLE** | Same — not linkable. |
| `ukintctlr.c:206` (`irq_configure`) | `uk_intctlr && ops` non-null | **STRUCTURALLY SATISFIED** | Not by Koru's type system — by boot ordering. `uk_intctlr_probe` (`plat/kvm/x86/setup.c:145`) and `uk_intctlr_init` (`lib/ukboot/boot.c:348`) both run before the application's main thread — the thread that eventually runs any Koru flow — is even created. On x86_64/xpic this cannot be false by the time Koru code runs. `status`'s printed `name=PIC` in the boot console is the live proof. |
| `ukintctlr.c:207` (`irq_configure`) | `irq`-descriptor pointer non-null | **RETIRED, structurally** | `configure` always passes the address of a struct it builds itself; a null `struct uk_intctlr_irq *` is not a value this surface can produce. |
| `ukintctlr.c:215` (`fdt_xlat`) | `uk_intctlr && ops` non-null | **NOT APPLICABLE** | `fdt_xlat` is not exposed at all — see the crash finding above. |
| `ukintctlr.c:216` (`fdt_xlat`) | `fdt` non-null | **NOT APPLICABLE** | Same. |
| `ukintctlr.c:217` (`fdt_xlat`) | `irq` non-null | **NOT APPLICABLE** | Same. |
| `ukintctlr.c:222` (`fdt_xlat`) | `ops->fdt_xlat` non-null | **NOT LIFTED — genuine crash hazard** | `pic_ops.fdt_xlat = __NULL` unconditionally on xpic (`pic.c:34`). This assert, compiled out, guards a call that is a guaranteed NULL indirect call in every build. Deliberately never exposed. |
| `ukintctlr.c:231` (`irq_alloc`) | `irqs` non-null | **RETIRED, structurally** | `alloc` always passes the address of a local variable. |
| `ukintctlr.c:252` (`irq_free`) | `irqs` non-null | **RETIRED, structurally** | Same. |
| `ukintctlr.c:255-256` (`irq_free`) | `FIRST_ALLOCABLE_IRQ <= irqs[i] <= LAST_ALLOCABLE_IRQ` | **RETIRED, structurally** | `free` takes `*Irq<!allocated>`, and only `alloc` mints that state — `alloc` can never produce a value outside this range (see "the other range mismatch" above), so a caller cannot construct an out-of-range `free` argument at all. |
| `ukintctlr.c:260` (`irq_free`) | `rc` (the bit was actually set) | **RETIRED under typed usage; guarded anyway** | Should be unreachable by construction (only `alloc`-derived irqs ever reach `free`) — `free`'s own return code is still checked and surfaced as a real `failed` arm rather than assumed, per "no fallbacks". |
| `ukintctlr.c:268` (`init`) | `uk_intctlr` non-null | **STRUCTURALLY SATISFIED** | Same boot-ordering argument as `irq_configure`'s ops check. |
| `ukintctlr.c:269` (`init`) | `uk_lcpu_irqs_disabled()` | **NOT LIFTED — genuine ceiling** | By the time any Koru code can call `init`, `uk_lcpu_enable_irq()` (`boot.c`) has already run — IRQs are unconditionally ENABLED. This lift has no way to control when a caller invokes `init` relative to that point; harmless only because the function body does nothing besides this assert and `return 0`, and only in a release build. |
| `ukintctlr.c:277` (`register`, the driver-registration function) | `intctlr` non-null | **NOT APPLICABLE** | `uk_intctlr_register` (which sets the global `uk_intctlr` pointer) is driver-only, called during platform probe before any Koru code runs. Not exposed — no legitimate Koru-level use, and calling it incorrectly could brick the whole subsystem. |

**Totals: 10 retired (2 of them corrected off-by-ones, 6 structural, 2 by
explicit pre-call value check), 2 structurally satisfied by boot ordering
(not by Koru's type system), 7 not applicable (not exposed / not linkable),
2 not lifted (genuine ceilings this lift cannot close: the `fdt_xlat` crash
hazard, and `init`'s IRQs-disabled precondition).** Three real
(non-`UK_ASSERT`) error branches exist in the C and are all surfaced as real
failure arms with real payloads, never swallowed: `register`'s `-ENOMEM` (no
free handler slot), `unregister`'s `-ENOENT` (no matching slot — the
aliasing hazard), `alloc`'s `-ENOSPC` (bitmap exhausted).

---

## Files

| | |
|---|---|
| `index.kz` | the lift |
| `tests/boot_intctlr.kz` | gate 2 — six flows, in a unikernel, against the real `lib/ukintctlr.c` |
| `tests/negative_handler_never_discharged.kz` | gate 3 — pure non-discharge, no auto-discharge candidate |
| `tests/negative_line_use_after_free.kz` | gate 3 — use-after-discharge |
| `tests/negative_handler_abandon_while_registered.kz` | gate 3 — wrong-state use of the escape hatch |
| `tests/wrapper.zig`, `tests/main.c` | the C-ABI seam, from `koru/examples/unikraft` |

Measured against `unikraft` HEAD `3fdffba8`, kraftkit 0.12.15, Unikraft
0.21.0 "Ijiraq", zig 0.15.2, on macOS/arm64 (QEMU TCG x86_64 guest).

## What I left out

- **Genuine hardware-interrupt DELIVERY to a Koru-registered handler.** Every
  handler this lift's boot demo installs is proven through real C
  bookkeeping calls (`register`/`unregister` succeed or fail exactly as the
  C's own state predicts), never actually FIRED by a hardware IRQ. Piggybacking
  on the one IRQ line guaranteed to fire in a headless boot — IRQ 0, the
  timer — does not work: `plat/kvm/x86/time.c`'s own `timer_handler` returns
  `1` ("yes, handled"), which makes `uk_intctlr_irq_handle`'s dispatch loop
  (`ukintctlr.c:178`, `if (h->func(h->arg) == 1) return;`) stop after the
  first slot — a handler registered after the timer's on the same line would
  never run. Triggering a dynamically allocated line would need platform
  vector-level plumbing (APIC/PCI MSI programming) outside `ukintctlr`'s own
  public API — out of this challenge's altitude rule. Named rather than
  hidden: the compile-time and bookkeeping story is fully proven; live
  dispatch is not.
- **Batch allocation (`count > 1`).** The C supports it; nothing in this fork
  calls it that way (nothing calls `irq_alloc`/`irq_free` at all before this
  lift), so this lift models the single-line unit, matching every other
  dynamic-resource API on this shelf. A straightforward later extension.
- **`gic` (arm) support.** This lift, like the challenge's own BUILD.md,
  targets x86_64/xpic only. `MAX_IRQ` and the allocable range are hardcoded
  from `drivers/ukintctlr/xpic/include/uk/intctlr/limits.h` and are cited as
  such; a `gic` variant would need its own numbers re-derived.
- **The three-way benchmark** (assert-on C, assert-off C, proven Koru) that
  would let anyone say "assert-on guarantees at assert-off cost" with
  numbers. Not built; not claimed.

## Toolchain defects found and pinned

- **`ai/toolchain-repros/D_unikraft_submodule_std_ambiguous.kz`** (+
  `D_control.kz`) — a `unikraft/<name>` submodule that declares its own
  top-level `const std = @import("std");` collides (Zig `error: ambiguous
  reference`) with the identical declaration in the auto-pulled
  `unikraft/index.kz` the moment any code path that actually calls a tor
  referencing `std.*` gets compiled. Hit first while writing `status`'s
  `std.mem.span` call, worked around by removing this module's own
  redundant `const std` declaration (Zig's ordinary lexical scoping already
  makes the outer one visible to a nested module body). **This bug is
  already live and latent in the shipped `unikraft/store`**: its
  `get.charp` tor calls `std.mem.span` and its own `index.kz` also declares
  `const std` — but `store`'s own boot test never calls `get.charp`
  (verified: `grep -n "get\.charp" boot_store.kz` returns nothing), so the
  collision has never fired for that module. Not fixed there — out of this
  lift's slot — named here so it is not rediscovered as folklore.
- A smaller, second finding, worked around rather than filed as its own
  repro pair under this session's time budget: a Koru tor **parameter**
  literally named `handler` collides with the compiler's own
  auto-generated Zig implementation function, which is named `handler`
  uniformly for every tor (`pub inline fn handler(__koru_event_input: Input)
  Output` in the emitted code). Silent until Zig itself refuses it:
  `error: local constant shadows declaration of 'handler'`. `register`'s
  parameter is named `handler_fn` here instead.
