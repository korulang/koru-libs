# unikraft/mpi — Unikraft's mailbox (`ukmpi`), lifted

`lib/ukmpi/mbox.c` is Unikraft's inter-thread mailbox: a fixed-capacity ring
of `void *` slots guarded by a pair of counting semaphores, with `post`/`recv`
each in blocking / `_try` / `_to` (timeout) flavours plus two ISR-safe `_try`
variants — 10 exported functions, all real (0 phantom, 0 inert — the cleanest
linkability row on the whole shelf). `struct uk_mbox` is never defined in any
public header, only forward-declared, so this lift needs **no struct mirror
at all** — the first shipped module that doesn't.

```koru
~import unikraft/mpi

~unikraft/mpi:create(capacity: 4)
| ok m |> unikraft/mpi:post(mbox: m, token: 101): m2
    |> unikraft/mpi:recv(m2): r
        |> unikraft/mpi:drain(r.mbox)
        | ok drained |> unikraft/mpi:release(mbox: drained)
        | pending p  |> unikraft/mpi:abandon(p.mbox)
| failed why |> …
```

## The assert this module names

`uk_mbox_free` (`mbox.c:38`):

```c
UK_ASSERT(m->readpos == m->writepos);
```

Drain before free. With `CONFIG_LIBUKDEBUG_ENABLE_ASSERT` off — every image
anyone ships — `uk_mbox_free` runs unconditionally: the backing allocation is
freed while a message may still be sitting in the ring, and anything still
blocked in `uk_mbox_recv` on that mailbox is now waiting on freed memory. The
C's own comment says the plain part out loud: *"it is an indication of a
programming error in lwIP and the developer should be notified."* Assert-off,
nobody is.

## The ratchet

Two states — see *"Where pillar 4 does not apply"* in `index.kz` for why this
is deliberately smaller than `blk`'s eight or `vmem`'s five.

```
create   mints  <open!>                                uk_mbox_create
post*    needs  <!open>  mints <open!>  (self-loop)     uk_mbox_post / _try / _to / _try_isr
recv*    needs  <!open>  mints <open!>  (self-loop)     uk_mbox_recv / _try / _to / _try_isr
drain    needs  <!open>  mints <drained!> ON EVIDENCE   NO C CALL — reads this lift's own count
         or refuses, handing <open!> back with the count still outstanding
release  needs  <!drained>                              uk_mbox_free
abandon  needs  <!open>                                 NO C CALL — give up, leak the ring
```

`drain` is the only tor that can mint `<drained!>`, and it mints it only when
this lift's own `pending` counter — incremented on every successful `post*`,
decremented on every successful `recv*`, both via `@atomicRmw` — reads zero.
`uk_mbox_free` has no accessor for `readpos`/`writepos`, mirrored or
otherwise, so this counter is the only way to ask "is the ring empty" at all.
Full reasoning, including the exact difference from `blk`'s zero-runtime-check
asymmetry and the soundness boundary this counter has under real concurrent
use, is in `index.kz`'s header comment — read it before revising this module.

**Where pillar 4 does *not* apply**, and why this reads differently from
`unikraft/alloc`'s ruling on the same question: `alloc` imposes an asymmetry
the C does not have (`take(); free();` is legal C, refused here anyway,
because unread memory freed unread is pointless by construction). A mailbox
does not have that property — `create(4); drain; release;` with zero messages
ever posted is a real program (pre-wiring a channel a config path never uses),
and the C agrees: `readpos == writepos` at `0 == 0` satisfies the assert with
room to spare. So `drain` right after `create` is legal and cheap, and this
lift does not force a post/recv before release the way `blk` forces a
transfer before `stop`. Flow C of the boot demo is the live proof.

**No named escape from `drain` itself**, unlike `blk:io.skipped` or
`lock:hold.skipped`. Both of those exist because the gate they bypass costs
something real (a device transfer, a lock acquisition). `drain` costs a load
of a Koru-owned integer — there is no honest program for which skipping it
buys anything.

**The unwritten rule the assert census does not count**: `uk_mbox_create`
takes an allocator and `uk_mbox_free` takes one too, and nothing in the C
checks they are the same one. `create` reads `_uk_alloc_head` once and the
handle carries that pointer to `release`, so a mismatched create/free
allocator pairing is not a program this lift's surface can express.

---

## A load-bearing finding: `abandon` is auto-discharged, and that is correct

While building the negative tests I wrote a "create a mailbox and walk away"
test expecting `KORU030` (mirroring `blk`'s
`negative_device_never_discharged.kz`). It compiled clean. That sent me into
`src/auto_discharge_inserter.zig` rather than assuming a compiler bug, per the
brief's own instruction to verify before attributing.

The mechanism is real, documented, and unrelated to this lift:
`isUnattendedDischarge` in that file auto-inserts a disposal call at scope
exit when exactly one candidate tor accepting the outstanding obligation is
**void with no branches** — the RAII half of the obligation system, as
`unikraft/blk`'s own header comment already puts it: *"RAII guarantees a
resource is CLEANED UP; it cannot force it to be USED."* `abandon` — `{ mbox:
*Mailbox<!open> }`, no branches, no return — is exactly that shape, and it is
the **unique** such candidate for `<open!>` (`drain` has branches so it does
not qualify; `post*`/`recv*`/`pending` all return values). So:

```
$ koruc negative_walkaway.kz --auto-discharge=warn
warning[AUTO-DISCHARGE]: Inserting 'unikraft.mpi:abandon' to discharge 'm0' (state: unikraft.mpi:open!)
✓ Compiled to a.out
```

```
$ koruc negative_walkaway.kz --auto-discharge=disable
error[KORU030]: Resource 'm0' carries obligation <open!> was not discharged.
Call one of: unikraft.mpi:pending, unikraft.mpi:abandon, unikraft.mpi:recv
```

**This is correct, not a hole**, once you track what auto-insertion is
choosing between: `abandon` never calls `uk_mbox_free`. A caller who forgets
to resolve a mailbox does not get a silent double-free or a corrupted ring —
they get the exact same safe leak an explicit `abandon` call produces. The
compiler is choosing *leak, never corrupt* as its unattended default, which
is the same choice this lift itself makes by hand everywhere else. So the
claim in `index.kz`'s header — *"a caller that ignores a `pending` refusal is
caught holding an obligation gate 3 will not let the program end with"* — is
**imprecise as originally written** and is corrected here: the program *does*
compile, silently, via auto-discharge, and what actually cannot happen,
under any settings, with or without auto-discharge, is `uk_mbox_free` running
on an undrained ring. That is the guarantee this lift actually earns, and it
is a real one — I want to name the imprecision rather than let a stronger
sentence stand uncorrected.

**Practical consequence for the negative tests below**: a bare "never
discharged" test does not demonstrate a compile failure under default
settings for this module, because `abandon` is exactly the shape
auto-discharge is designed to paper over. `negative_release_without_drain.kz`
and `negative_abandon_after_drain.kz` do not have this problem — both are
*wrong-state* mismatches (`KORU030` phantom mismatch, not the auto-dischargeable
"never touched" case), and both fail under plain `koruc`, no flags, exactly as
gate 3 requires.

---

## Gate 1 — `--check`

```
$ koruc --check unikraft/mpi/index.kz
✓ Shape checking passed
```

## Gate 2 — it boots

Recipe (traps and their evidence: `/Users/larsde/src/koru/examples/unikraft/BUILD.md`):

```sh
mkdir /tmp/mpi && cp -R unikraft /tmp/mpi/
cd /tmp/mpi/unikraft/mpi/tests

koruc boot_mpi.kz unikraft gen        # -> Makefile.uk + Kraftfile
koruc boot_mpi.kz                     # -> output_emitted.zig
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

`boot_mpi.kz` runs six short flows (A–F) rather than one long chain, so the
branch structure driving them stays readable — see the file's header comment
for the map. Real console output, verbatim, boot banner elided:

```
heap at start:  31899648 bytes free
== flow A: fill via post + post.try, drain refuses, drain full receive ==
create:         capacity 4, mailbox open
post:           uk_mbox_post — token 101 queued (blocking, slot was free)
post:           uk_mbox_post — token 102 queued
post.try:       ok — token 103 queued
post.try:       ok — token 104 queued, ring full (capacity 4)
pending:        4 messages outstanding (expect 4)
drain:          pending — refused with 4 message(s) still in the ring (expect 4)
recv:           uk_mbox_recv — got token 101 (expect 101, FIFO)
recv:           got token 102 (expect 102)
recv:           got token 103 (expect 103)
recv:           got token 104 (expect 104), ring now empty
drain:          ok — mbox.c:38's assert is unreachable from here, checked BEFORE uk_mbox_free ever runs
== flow B: post.try full, post.timeout times out ==
create:         capacity 1, mailbox open
post.try:       ok — token 201 queued, ring full (capacity 1)
post.try:       full — uk_mbox_post_try returned -ENOBUFS, ring already at capacity
post.timeout:   timeout — 5ms elapsed, uk_mbox_post_to returned __NSEC_MAX, ring still full
recv:           got token 201 (expect 201), ring now empty
drain:          ok
== flow C: recv.try empty, recv.timeout times out, zero-message release ==
create:         capacity 2, mailbox open, nothing posted yet
recv.try:       empty — uk_mbox_recv_try returned -ENOMSG on a never-touched ring
recv.timeout:   timeout — 5ms elapsed, uk_mbox_recv_to returned __NSEC_MAX
drain:          ok — readpos == writepos at 0 == 0, a mailbox that carried zero messages is a legal release (index.kz: "where pillar 4 does not apply")
== flow D: the isr-safe try variants ==
create:         capacity 2, mailbox open
post.try-isr:   ok — uk_mbox_post_try_isr — token 301 queued from ordinary thread context
recv.try-isr:   ok — uk_mbox_recv_try_isr — got token 301 (expect 301)
drain:          ok
== flow E: the drain gate, caught live — mbox.c:38 in miniature ==
create:         capacity 2 mailbox for the drain-gate demo
post:           token 401 queued, nothing received yet
drain:          pending — refused with 1 message(s) still in the ring (expect 1) — mbox.c:38's assert is EXACTLY this check, made loud here instead of silent there
recv:           got token 401 (expect 401), ring now empty
drain:          ok — now that it is actually empty
== flow F: abandon — the named escape from an undrained mailbox ==
create:         capacity 2 mailbox for the abandon demo
post:           token 501 queued, then abandoned without draining — the C ring and its one message are intentionally leaked, this lift's own handle wrapper is not
heap at end:    31895552 bytes free
```

Every "expect N" printed matches what actually came back — no `UNEXPECTED`
branch fired anywhere in the run (each flow's off-path arms exist only for
type-exhaustiveness and route through `abandon`, never taken here).

**The heap does not bracket exactly, and that is flow F working as designed.**
`31899648 − 31895552 = 4096` bytes — one page — held after all six mailboxes
are torn down. I checked rather than asserted: rebuilding and booting the
identical image with flow F's `post` + `abandon` removed brings the end
figure back to **31899648**, matching the start exactly. Flows A–E (five
mailboxes, all torn down through `release`) bracket precisely; flow F's
mailbox is the one deliberately abandoned with a message still in it, and its
backing allocation is the one page that does not come back — exactly what
`abandon`'s own doc comment says it does.

| | |
|---|---:|
| Koru freestanding static archive (`libkoruapp.a`) | 33,272 B |
| bootable unikernel image | 185,088 B |
| baseline (`examples/unikraft/hello.kz`, no mpi) | 164,544 B |

No boot-time number. Everything here is QEMU TCG on arm64 with no KVM, and
this project does not have a boot-time claim to make.

## Gate 3 — misuses that fail to compile

Phantom validation fires in the **emit** pass, not `--check`. Both pass
`koruc --check` and are refused by plain `koruc <file>`, no flags.

**`negative_release_without_drain.kz`** — post a message, then `release`
directly, skipping `drain`. The exact program `mbox.c:38` exists to catch.

```
$ koruc --check negative_release_without_drain.kz
✓ Shape checking passed

$ koruc negative_release_without_drain.kz
error[KORU030]: Phantom state mismatch: expected 'unikraft.mpi:drained' but got 'unikraft.mpi:open!' for argument 'mbox'
  --> negative_release_without_drain.kz:38:0
❌ Compiler coordination error: Phantom semantic validation failed
```

**`negative_abandon_after_drain.kz`** — `drain` a genuinely empty mailbox
(which succeeds, minting `<drained!>`), then call `abandon` instead of
`release`. `abandon` accepts only `<!open>`; a caller cannot launder a
legitimately drained mailbox through the leak-a-ring escape hatch just
because both tors take a bare `*Mailbox` and return nothing.

```
$ koruc negative_abandon_after_drain.kz
error[KORU030]: Phantom state mismatch: expected 'unikraft.mpi:open' but got 'unikraft.mpi:drained!' for argument 'mbox'
  --> negative_abandon_after_drain.kz:35:0
❌ Compiler coordination error: Phantom semantic validation failed
```

**Why not a third "leak" test.** See *"A load-bearing finding"* above: a
mailbox left in `<open!>` at scope exit is auto-discharged through `abandon`
by design, so that program compiles clean under default settings — pinning it
`compile_fail` would have been a lying test. It only fails with
`--auto-discharge=disable`, which is not the pipeline gate 3 asks for.

## Gate 4 — no fallbacks

One named, greppable escape hatch: `unikraft/mpi:abandon`. `grep -r
"unikraft/mpi:abandon"` answers "which programs gave up on a mailbox without
draining it" exactly the way `grep -r "blk:io.skipped"` answers blk's
equivalent question. It runs no C call — the honest emission for "I am not
going to resolve this" — and it is the only place this module is allowed to
leak the C-side ring on purpose. Everywhere else, failure arms carry a real
`errno`/`reason` and a real Koru pointer type prevents a null device from
ever entering the chain (`create` fails loudly if `_uk_alloc_head` is null or
`uk_mbox_create` returns `NULL`, never silently substituting a stub handle).

## Gate 5 — the assert census

`lib/ukmpi` carries 15 `UK_ASSERT`s total: 10 in `mbox.c`, 3 in
`mbox_defs.h`, 2 in `mbox_isr.c`. Every one, and what happened to it:

| file:line | assertion | disposition | why |
|---|---|---|---|
| `mbox.c:38` | `free`: `m->readpos == m->writepos` | **RETIRED** | `release` accepts only `<!drained>`; the only tor minting `<drained!>` is `drain`, gated on this lift's own `pending == 0`. `uk_mbox_free` cannot run on an undrained ring through any path this module exposes — see the auto-discharge finding above for the precise (and corrected) shape of this guarantee. |
| `mbox.c:10` | `create`: `size <= __L_MAX` | **RETIRED, by type choice** | `capacity` is `u32`; `u32::MAX` (4,294,967,295) is below `__L_MAX` (`LONG_MAX` = 9,223,372,036,854,775,807 on the 64-bit target this lift builds — x86_64 only, per BUILD.md). A `comptime` block in `index.kz` turns "not actually 64-bit" into a build error rather than a silently wrong claim. Not a phantom state — it is a value bound, and phantom states are symbolic — so this is a different kind of retirement than the drain gate: earned by the parameter's width, not by an unreachable program shape. |
| `mbox.c:36` | `free`: `UK_ASSERT(a)` | structurally satisfied | Koru's `*UkAlloc` cannot be null; also moot in practice — `release` never re-exposes the allocator as a caller-supplied argument at all (see "the unwritten rule" above). |
| `mbox.c:37` | `free`: `UK_ASSERT(m)` | structurally satisfied | Koru's `*Mailbox` cannot be null. |
| `mbox.c:49` | `post`: `UK_ASSERT(m)` | structurally satisfied | same |
| `mbox.c:57` | `post_try`: `UK_ASSERT(m)` | structurally satisfied | same |
| `mbox.c:69` | `post_to`: `UK_ASSERT(m)` | structurally satisfied | same |
| `mbox.c:85` | `recv`: `UK_ASSERT(m)` | structurally satisfied | same |
| `mbox.c:109` | `recv_try`: `UK_ASSERT(m)` | structurally satisfied | same |
| `mbox.c:137` | `recv_to`: `UK_ASSERT(m)` | structurally satisfied | same |
| `mbox_isr.c:10` | `recv_try_isr`: `UK_ASSERT(m)` | structurally satisfied | same |
| `mbox_isr.c:23` | `post_try_isr`: `UK_ASSERT(m)` | structurally satisfied | same |
| `mbox_defs.h:55` | `_do_mbox_post`: `UK_ASSERT(m)` | structurally satisfied | same, and see the next row — this helper is unreachable from this lift's surface at all. |
| `mbox_defs.h:34` | `_do_mbox_recv`: `m->readpos != m->writepos` | not applicable | Internal helper, `static inline`, called only from inside the public `uk_mbox_recv*` after their own semaphore `down` has already succeeded — the C's own protocol guarantees a message is present before this line runs. Nothing this lift's surface can call reaches `_do_mbox_recv` outside that protocol; the assert protects a C-internal invariant this lift never had a way to violate, lifted or not. |
| `mbox_defs.h:60` | `_do_mbox_post`: `m->readpos != m->writepos` | not applicable | Same reasoning, write side. |

**Totals: 2 retired (1 the headline drain gate, 1 a value bound retired by
parameter width), 11 structurally satisfied (null-pointer hygiene, all of
them), 2 not applicable (C-internal invariants this lift's surface cannot
reach).** No real (non-`UK_ASSERT`) ordering branches exist in `ukmpi` the way
`blk` has three `-EINVAL`/`-EBUSY` checks — `mbox.c` has none; every ordering
rule in this library is exactly the one `UK_ASSERT` at line 38.

---

## Files

| | |
|---|---|
| `index.kz` | the lift |
| `tests/boot_mpi.kz` | gate 2 — six flows, in a unikernel, against the real `lib/ukmpi` |
| `tests/negative_release_without_drain.kz` | gate 3 — the drain gate |
| `tests/negative_abandon_after_drain.kz` | gate 3 — wrong-state use of the escape hatch |
| `tests/wrapper.zig`, `tests/main.c` | the C-ABI seam, from `koru/examples/unikraft` |

Measured against `unikraft` HEAD `3fdffba8`, kraftkit 0.12.15, Unikraft
0.21.0 "Ijiraq", zig 0.15.2, on macOS/arm64.

## What I left out

- **A real cross-thread producer/consumer.** Every flow in the boot demo runs
  on the single boot thread; blocking calls only ever block for durations I
  can guarantee are zero (a slot or a message is already there) or for a
  timeout I let expire on purpose. The mailbox's actual reason to exist —
  handing a message from one `uksched` thread to another — is not exercised
  here. `unikraft/sched` is a shipped sibling and the natural composition
  partner for that; I did not build it under this session's time budget, and
  said so rather than implying flow A's four sequential `recv`s prove
  something they do not.
- **The three-way benchmark** (assert-on C, assert-off C, proven Koru) that
  would let anyone say "assert-on guarantees at assert-off cost" with
  numbers. Not built; not claimed.
- **A tighter soundness statement for `pending` under real concurrency.**
  Stated precisely in `index.kz`'s header rather than glossed over: the
  counter's two writers are not atomic *with* the C calls that cause them, so
  `drain` racing a concurrently running `post` on another thread is not
  linearizable. This matches the assumption the C's own comment makes
  (teardown after quiescence, not during), and is not a claim this lift makes
  stronger than the assert it replaces.
