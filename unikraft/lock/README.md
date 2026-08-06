# `unikraft/lock` — Unikraft's `uklock`, lifted

```koru
~import unikraft/lock

~unikraft/lock:probe
| ready proof |> unikraft/lock:create(proof.locks)
    | lock guard |> unikraft/lock:write.acquire(lock: guard): exclusive
        |> …
        |> unikraft/lock:write.release(lock: exclusive): rested
            |> unikraft/lock:destroy(lock: rested)
```

Seven tors, four phantom states, a partial struct mirror whose **size is measured
on the running image rather than transcribed**, and one named escape hatch.

The lift is the **reader-writer lock**, and that is a linkability verdict rather
than a preference — see below. `uklock`'s mutex and semaphore are not here and
cannot honestly be brought.

---

## The linkability verdict — 15 allowlist lines, 5 usable functions

`lib/uklock/exportsyms.uk` exists, so the brief's **case 1** applies: that file is
the allowlist, `objcopy --keep-global-symbols` localizes everything else, and only
the listed symbols link. Fifteen lines. Read as the linker reads them:

| allowlist line | what it actually is | liftable? |
|---|---|---|
| `uk_rwlock_init_config` | real, `rwlock.c:12` | **yes** |
| `uk_rwlock_rlock` | real, `rwlock.c:30` | **yes** |
| `uk_rwlock_wlock` | real, `rwlock.c:67` | **yes** |
| `uk_rwlock_runlock` | real, `rwlock.c:93` | **yes** |
| `uk_rwlock_wunlock` | real, `rwlock.c:115` | **yes** |
| `uk_rwlock_upgrade` | **does not exist** | no |
| `uk_rwlock_downgrade` | **does not exist** | no |
| `uk_mutex_init_config` | real — but every mutex VERB is `static inline` | no |
| `uk_semaphore_init` | real — but every semaphore VERB is `static inline` | no |
| `_uk_mutex_lock_wait` | the contended half of an inline, precondition unmet standalone | no |
| `_uk_mutex_unlock_wait` | same | no |
| `_uk_mutex_trylock_wait` | same | no |
| `uk_mutex_get_metrics` | `CONFIG_LIBUKLOCK_MUTEX_METRICS`, `default n` | no |
| `_uk_mutex_metrics` | same — a data symbol absent from a stock image | no |
| `_uk_mutex_metrics_lock` | same | no |

Three findings, each of which changes what "15 linkable" means.

### 1. Two of the fifteen do not exist

```
$ grep -rn "rwlock_upgrade\|rwlock_downgrade" /Users/larsde/src/unikraft
lib/uklock/exportsyms.uk:14:uk_rwlock_upgrade
lib/uklock/exportsyms.uk:15:uk_rwlock_downgrade
```

Two hits over the entire tree at HEAD `3fdffba8`, both in the allowlist itself. No
declaration in `rwlock.h`, no definition in `rwlock.c`, no caller anywhere.

**An allowlist is not an inventory.** `objcopy --keep-global-symbols` is a filter,
not an assertion — naming a symbol that does not exist is not an error, it simply
keeps nothing. The shelf's `linkable` column counts allowlist lines for
allowlist-gated libraries, which is the right measurement to take and is not the
same as "functions you can call". For `uklock` the gap is 2 out of 15.

### 2. The mutex and the semaphore are `uknetdev`'s trap wearing another name

`uknetdev` exports its lifecycle and leaves `uk_netdev_rx_one` / `tx_one`
`static inline`, so the interesting half is unreachable. `uklock` does the same
thing one level down: it exports the *constructors* and leaves the *verbs* inline.

- `uk_mutex_lock` (`mutex.h:163`), `uk_mutex_trylock` (`:186`),
  `uk_mutex_is_locked` (`:212`), `uk_mutex_unlock` (`:227`) — all `static inline`.
- `uk_semaphore_down` (`semaphore.h:53`), `_down_all` (`:74`), `_down_try` (`:98`),
  `_down_to` (`:122`), `uk_semaphore_up` (`:157`) — all `static inline`.

So a lift of `uk_mutex_init_config` hands a caller a mutex it can never lock, and
a lift of `uk_semaphore_init` hands out a semaphore that can never be waited on.
**Both are refused.** A module that binds a constructor and no verb is a wrapper
that looks like a lift, and it would fail the brief's no-fallbacks rule in the
worst way: it would compile, link, boot, and be useless.

The three `_uk_mutex_*_wait` symbols are the reason this is not fixable by
re-implementing the inline. They are the *contended branches* —
`_uk_mutex_lock_wait(m, tid, v)` is entered only after the caller's
compare-exchange has already failed and `v` holds the word it observed
(`mutex.h:172-177`). Calling one standalone is not "lock"; it is the slow path
with its precondition unmet. Reconstructing `uk_mutex_lock` in Koru would mean
re-implementing `_uk_mutex_lock_fetch` (a macro with two definitions, chosen by
`CONFIG_LIBUKLOCK_MUTEX_ATOMIC`) plus `uk_thread_current()` (itself `static
inline`, and `uksched`'s business), against a mirrored `struct uk_mutex`. That is
not a lift of the C, it is a fork of it that silently diverges the day upstream
changes the fast path.

### 3. The rwlock is the half that survives whole — and it is the half worth having

All five reader-writer functions are exported, and together they are the complete
API. No `static inline` is needed. The archive links against a stock unikernel
with no shim, no C wrapper and no extra call frame.

---

## The state machine, and why it is two hold-states and not one

`uk_rwlock_runlock` and `uk_rwlock_wunlock` take the same argument, return the
same `void`, and are spelled four characters apart. They are not interchangeable:

```c
rwlock.c:98    UK_ASSERT(rwl->nactive > 0);     /* runlock: a READ lock is held  */
rwlock.c:120   UK_ASSERT(rwl->nactive == -1);   /* wunlock: a WRITE lock is held */
```

`UK_ASSERT` is `do {} while(0)` whenever `CONFIG_LIBUKDEBUG_ENABLE_ASSERT` is off,
which is every image anyone ships. Cross the two in production and:

- **`wlock` then `runlock`** takes `nactive` from -1 to **-2**. `rlock` waits on
  `nactive >= 0` and `wlock` waits on `nactive == 0`; neither is ever true again,
  and the only code that could reset `nactive` is now blocked. **The lock is
  permanently dead**, and the symptom is a hang at some later acquire, in another
  thread, arbitrarily far from the mistake.
- **`rlock` then `wunlock`** takes `nactive` from 1 to **0**. The lock now reads as
  free while a reader is still inside it, so the next writer is admitted alongside
  it. **Silent data race** — no hang, no crash, no message.

That pair is what this lift makes structural.

| tor | takes | mints | C call |
|---|---|---|---|
| `probe` | — | — (branch, not state) | `uk_rwlock_init_config` ×2, `rlock`/`runlock`/`wlock`/`wunlock` ×1 |
| `create` | `*Locks` | `<fresh!>` | `uk_rwlock_init_config(l, 0)` |
| `read.acquire` | `<!fresh\|!idle>` | `<reading!>` | `uk_rwlock_rlock` |
| `read.release` | `<!reading>` | `<idle!>` | `uk_rwlock_runlock` |
| `write.acquire` | `<!fresh\|!idle>` | `<writing!>` | `uk_rwlock_wlock` |
| `write.release` | `<!writing>` | `<idle!>` | `uk_rwlock_wunlock` |
| `hold.skipped` | `<!fresh>` | `<idle!>` | **none — the escape** |
| `destroy` | `<!idle>` | — | `free` (uklock has no destructor) |

The mode is the first token of the tor name deliberately: `grep -r "lock:write"`
answers "where does this program take the write lock", which is the question a
reader of concurrent code actually asks and which the word `unlock` cannot answer.

### The emitted code, verbatim

Pillar 2 says the emitted code should be the same C call a careful hand-written
user would make, with nothing added. From `output_emitted.zig`:

```zig
pub const read_acquire_event = struct {
    pub const Input = struct { lock: *Lock };
    pub const Output = *Lock;
    pub fn handler(__koru_event_input: Input) Output {
        const lock = __koru_event_input.lock;
        uk_rwlock_rlock(lock);
        return lock;
    }
};
```

One call, one return. Nothing checks a state; the states do not exist at run time.
`hold.skipped` emits `return lock;` and no call at all, which is the honest
emission — nothing happened.

The handle is the struct: `*Lock` points straight at the `struct uk_rwlock`. Unlike
`unikraft/blk` and `unikraft/pages`, which allocate a Koru-side header beside the C
object, **this lift adds zero bytes to the object it wraps.** Everything it knows
that the C does not lives in the phantom state, which costs nothing at run time.

---

## The asymmetry (pillar 4)

`destroy` accepts only `<!idle>`, and `<idle!>` is minted only by a release. So:

```koru
~unikraft/lock:create(proof.locks)
| lock guard |> unikraft/lock:destroy(lock: guard)      // does not compile
```

This is `2104_14_open_tx_commit_close/db.kz`'s shape (`close` takes `<!active>`,
not `<!connected>`) and gzip's `fed` gate. **You cannot build a lock and throw it
away without ever entering it.**

The C has nothing to say about this and could not have. `uk_rwlock_init_config` on
a struct nobody ever locks is correct, silent and warning-free, and there is no
destructor to assert in. But the mistake is real and it is a *design* error rather
than a memory one: a lock exists to serialize a critical section, so a lock with no
critical section means either the section was deleted and the lock outlived it, or
the section is still there and somebody forgot to take the lock around it. The
second reading is a data race that no amount of testing finds.

The legitimate case stays expressible and stays loud:

```
grep -r "lock:hold.skipped"    ->   "which locks do we build and never enter"
```

`tests/negative_destroy_without_hold.kz` is the refusal. `tests/boot_lock.kz`
contains the same program spelled honestly — it compiles and boots, which is what
proves the gate costs the honest program nothing but one word.

### Where I decided the C has NO ordering rule, and refused to ratchet

Three places, stated as plainly as the ratchets, because the brief asks for both:

1. **Acquire and release are a symmetric pair within a mode.** There is no
   `read.acquire` → `read.used` → `read.release` chain, and there should not be.
   Taking a read lock and releasing it without reading anything is a legitimate
   idiom — it is how you wait for a writer to finish — and `rwlock.c` asserts
   nothing about it. The gate this lift has is on the LOCK OBJECT, never on an
   individual critical section. `unikraft/blk` requires a transfer between `start`
   and `stop` because `ukblkdev` has a device lifecycle with real ordering; a
   critical section does not, and imposing one would be exactly the
   feature-maximalism `unikraft/alloc` refused.
2. **Nothing counts.** `uk_rwlock_rlock` admits N concurrent readers and `nactive`
   counts them. A phantom state cannot count. Minting `reading1`/`reading2` would
   be a lie about what is proven, so this module models one holder per handle and
   says so under *Claims I do not make*.
3. **No failure arms on the four hot tors.** `rlock`, `wlock`, `runlock` and
   `wunlock` return `void`. They cannot fail — they block. The brief's rule that
   obligation-on-failure scales inversely with resource frequency lands here as:
   the rare operation (`create`, once per lock) carries the failure arm, and the
   frequent one (every critical section) carries none. That is not a choice this
   lift made; it is what the C signatures already say. The hot path is four
   bare-return tors with no branch and no payload.

---

## The `UK_ASSERT` census

Counted with `grep -rn UK_ASSERT` over `lib/uklock` at `unikraft` HEAD
`3fdffba8`. **30 assertions**, in five files:

| file | sites |
|---|---:|
| `rwlock.c` | 10 |
| `mutex.c` | 6 |
| `include/uk/mutex.h` | 8 |
| `include/uk/semaphore.h` | 5 |
| `include/uk/isr/semaphore.h` | 1 |

This module binds `rwlock.c` and nothing else, so the census splits at that line
and the two halves are counted separately. Banking all 30 would be the easiest
inflation available in this file.

### Retired — 8 of the 10 sites in `rwlock.c`, per site

**A. The pointer-existence rule — 5 sites, one rule**

| where | function | expression |
|---|---|---|
| `rwlock.c:15` | `uk_rwlock_init_config` | `UK_ASSERT(rwl)` |
| `rwlock.c:32` | `uk_rwlock_rlock` | `UK_ASSERT(rwl)` |
| `rwlock.c:69` | `uk_rwlock_wlock` | `UK_ASSERT(rwl)` |
| `rwlock.c:95` | `uk_rwlock_runlock` | `UK_ASSERT(rwl)` |
| `rwlock.c:117` | `uk_rwlock_wunlock` | `UK_ASSERT(rwl)` |

A caller never supplies the pointer. `create` mints it from a checked `memalign`
and hands it out only on the `| lock` arm, so there is no program in which a lock
operation is attempted against a pointer the module did not produce. **The proof
rides on the branch, not on a state** — no phantom state was spent on it and none
was needed, which is the same move `unikraft/alloc` makes for its 29
`UK_ASSERT(a)` sites.

Stated precisely: these are retired against *null*. They are not retired against
*stale*, and no assertion in `uklock` distinguishes those — see
`tests/negative_lock_after_destroy.kz`, which closes the stale case structurally
by consuming the handle.

**B. The two ordering assertions — 2 sites, and the reason this module exists**

| where | expression | how it is retired |
|---|---|---|
| `rwlock.c:98` | `UK_ASSERT(rwl->nactive > 0)` | `read.release` accepts only `<!reading>`, minted only by `read.acquire`. A `<writing!>` handle has no type here. `tests/negative_runlock_after_wlock.kz`. |
| `rwlock.c:120` | `UK_ASSERT(rwl->nactive == -1)` | `write.release` accepts only `<!writing>`, minted only by `write.acquire`. `tests/negative_wunlock_after_rlock.kz`. |

Both also cover the double-release direction: a release consumes its `<!held>` and
mints `<idle!>`, so a second one has nothing to take.

**C. The config rejection — 1 site**

| where | expression | how it is retired |
|---|---|---|
| `rwlock.c:23` | `UK_ASSERT(!uk_rwlock_is_write_recursive(rwl))` | `create` has no flags parameter and always passes 0. `UK_RWLOCK_CONFIG_WRITE_RECURSE` is not refused at run time — it is **unspellable**, so the condition the assertion tests cannot arise. |

### NOT retired — 2 sites in `rwlock.c`, stated plainly

| where | expression | why not |
|---|---|---|
| `rwlock.c:83` | `UK_ASSERT(rwl->npending_writes > 0)` | inside `uk_rwlock_wlock`, on the lock's own bookkeeping between its own increment and its own decrement, after a wait. No caller supplies the value, so there is no caller-side mistake to prevent and nothing for a lift to take away. |
| `rwlock.c:84` | `UK_ASSERT(rwl->nactive == 0)` | the wait predicate the loop above it just exited on, re-checked. Same reason: it guards the implementation against itself. |

### NOT retired — 20 sites on surfaces this module does not bind

`mutex.c` :36 :41 :50 :73 :83 :125; `include/uk/mutex.h` :167 :173 :193 :199 :218
:232 :233 :234; `include/uk/semaphore.h` :60 :81 :105 :128 :161;
`include/uk/isr/semaphore.h` :22.

A Koru program cannot fire any of these — but only because it cannot call the
mutex or the semaphore at all, which is a different and much weaker thing than
retiring a check. **Not offering a feature is not retiring its assertion.** This is
`unikraft/alloc`'s group-C rule applied to a whole primitive rather than a few
entry points, and the reason those primitives are unbound is the linkability
verdict above, not a scoping choice.

### Net

| | count |
|---|---:|
| retired — pointer existence, group A | **5** |
| retired — the ordering pair, group B | **2** |
| retired — the config rejection, group C | **1** |
| not retired — internal invariants in bound code | 2 |
| not retired — surfaces not bound (mutex, semaphore) | 20 |
| **total** | **30** |

**8 of 30 retired, 22 not.** A much larger number is available by counting the
mutex and semaphore sites, and it would be dishonest.

And the qualifier the brief requires: `UK_ASSERT` compiles to `do {} while(0)`
when `CONFIG_LIBUKDEBUG_ENABLE_ASSERT` is off, which it is in every image measured
here. So the 8 were not *costing* anything in a shipped image. What changes is that
the guarantee they describe now holds in the shipped image too, where before it
held only in a debug build. That is the asserts-on/asserts-off tradeoff dissolving,
and it is the honest form of the claim.

### And five rules the C states or implies and never checks at all

Not assertions, so not in the census — but they are the ones that actually bite,
and each is structural here.

- **Recursive write locking self-deadlocks.** `rwlock.h:24` defines a flag to
  enable it, `rwlock.c:22` says in a TODO that it is unimplemented, and
  `rwlock.c:23` asserts the flag is off — in a build where the assertion is gone.
  The second `wlock` waits for `nactive == 0` while holding `nactive == -1`, which
  only it could clear. `write.acquire` does not accept `<!writing>`:
  `tests/negative_recursive_write.kz`.
- **Recursive READ locking deadlocks when a writer arrives between the two
  acquires.** `rlock` twice is silently legal in the C and sets `nactive` to 2; but
  a reader arriving while `npending_writes > 0` waits (`rwlock.c:53`) and the
  writer waits for `nactive == 0` (`rwlock.c:76`). There is a comment about
  starvation at `rwlock.c:41-50` and no check. `read.acquire` does not accept
  `<!reading>` either.
- **A held lock that is never released hangs the next acquirer.** No assertion in
  `uklock` can see it — from inside the lock, a critical section that has not ended
  yet and one that never will are the same state. Here it is a **compile error**:
  `tests/negative_unlock_forgotten.kz`.
- **There is no `uk_rwlock_destroy`,** so nothing guards the storage's lifetime.
  Every rwlock in the Unikraft tree is a static or lives inside a longer-lived
  object; a caller who allocates one owns the free, and `rlock` on freed storage
  reads whatever the allocator left in `nactive`. `destroy` consumes the handle:
  `tests/negative_lock_after_destroy.kz`.
- **`sizeof(struct uk_rwlock)` is 48 or 72 depending on a Kconfig option that no
  symbol reports.** The next section is about that one.

---

## The mirror that was wrong, and what replaced it

This module's first draft mirrored `struct uk_rwlock` in full — the four counters,
`struct uk_spinlock`, and two `struct uk_waitq` — with `@offsetOf` and `@sizeOf`
comptime assertions in `unikraft/blk`'s house style. Every offset was transcribed
correctly from the headers. **It was wrong by 24 bytes, and it took a boot to find
out.**

```
uk_rwlock layout refused: struct uk_rwlock does not reach offset 68:
uk_rwlock_init_config left the mirror's last word untouched, so the waitq
layout this lift mirrors is not this image's
```

The cause is `include/uk/arch/spinlock.h:35`:

```c
#ifdef CONFIG_HAVE_SMP
#include <uk/asm/spinlock.h>
typedef struct __spinlock __spinlock;          /* { volatile int lock; }  — 4 bytes */
#else
typedef struct __spinlock {
	/* empty */
} __spinlock;                                  /* SIZE ZERO */
#endif
```

`struct uk_waitq` embeds one, and `struct uk_rwlock` embeds two wait queues plus a
spinlock. So on a single-core image — the default, and what boots here — the struct
is **48 bytes**, and on an SMP image it is **72**. `uklock`'s own `Config.uk` never
mentions SMP. `rwlock.h` never mentions it. No exported symbol reports it. A lift
that transcribed the header and asserted `@sizeOf == 72` would have been
self-consistently, confidently wrong in every image anyone actually builds — and
`@offsetOf` assertions would have passed, because they only ever prove a mirror
agrees with itself.

**The replacement mirrors only what it reads and measures the rest.** The four
leading `int`-sized counters are mirrored, because their offsets are fixed by the C
ABI on every target Unikraft supports and because `probe` reads `nactive` and
`config_flags`. Everything from offset 16 down is never named. Its extent is
measured on the running image:

1. `memalign(8, 512)`, all 512 bytes painted `0xA5`.
2. `uk_rwlock_init_config(m, 0x02)`.
3. Scan down from the top for the highest byte that is no longer the canary. That
   index plus one is how far the C's own initializer reached, and it is where
   `create`'s allocation size comes from. `uk_rwlock_init_config` writes every
   field the struct has — four stores, `uk_spin_init`, two `uk_waitq_init`
   (`rwlock.c:15-27`) — so the last byte it touches is the last byte of the last
   field. The result is rounded up to the `__align(8)` that `rwlock.h:23` declares,
   which is the one layout number taken from the source rather than the image,
   because trailing padding is by definition never written and so cannot be seen.
4. Refuse unless a 64-byte guard at the top of the scratch is still canary. The
   guard is INSIDE the allocation, which is the whole point: a struct larger than
   the measurement window is *detected* here instead of silently corrupting
   whatever the allocator hands out next.
5. Refuse unless `0x02` comes back out of offset 12 and the three counters read
   zero. Bit 1 is undefined — `rwlock.h:24` defines only bit 0, and
   `uk_rwlock_is_write_recursive` masks bit 0 only — so it travels from the
   argument into `config_flags` and is read by nothing. It is the only offset below
   the first word the C can be made to confirm.
6. Re-init with 0, then walk `rlock → runlock → wlock → wunlock`, reading offset 0
   after each: **0, 1, 0, -1, 0**. `wlock`'s -1 is the strongest single witness in
   the set — no other Unikraft primitive produces it — so seeing it proves the
   symbols this archive linked are `rwlock.c`'s and not something that merely
   satisfied the names. The four calls cannot block:
   `_uk_waitq_wait_until` (`wait.h:106`) is `while (!(condition))`, and on a lock
   nobody holds every condition is already true, so the scheduler is never entered.

If any test fails, `probe` takes `| unsupported` naming which one. `create` is the
only source of a `*Lock` and it needs the `*Locks`, so nothing in this module can
be used at all. **There is no degraded path and no "assume 72".** The first draft is
the argument for why there must not be.

Cost: one 512-byte allocation, one 512-byte paint, a backwards scan and four lock
operations — once per image, not per lock. A program calls `probe` once.

---

## Gate 1 — `--check`

```
$ koruc --check unikraft/lock/index.kz
✓ Shape checking passed
```

## Gate 2 — it boots

Traps and their evidence: `/Users/larsde/src/koru/examples/unikraft/BUILD.md`.

`koruc` writes its generated files **beside the entry file**, not into `$PWD`, and
`~std/compiler:paths { unikraft: {{ ENTRY }}/../.. }` resolves relative to the entry
file too. So the build happens in a copy of the tree, from inside `tests/`:

```sh
rm -rf /tmp/uklockbuild && mkdir -p /tmp/uklockbuild
cp -R <worktree>/unikraft /tmp/uklockbuild/unikraft
cd /tmp/uklockbuild/unikraft/lock/tests

koruc boot_lock.kz unikraft gen         # -> Makefile.uk + Kraftfile
koruc boot_lock.kz                      # -> output_emitted.zig
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

No disk, no network, no device model. `CONFIG_LIBUKLOCK` is `default n` and selects
`LIBUKSCHED`, so `boot_lock.kz`'s `~unikraft:kconfig` block names `LIBUKLOCK`,
`LIBUKLOCK_RWLOCK`, `LIBUKSCHED` and `LIBUKSCHEDCOOP` explicitly.

Real console output, `\r` stripped, nothing else edited:

```
SeaBIOS (version rel-1.17.0-0-gb52ca86e094d-prebuilt.qemu.org)

iPXE (http://ipxe.org) 00:03.0 CA00 PCI2.10 PnP PMM+02FD1D60+02F31D60 CA00
Press Ctrl-B to configure iPXE (PCI 00:03.0)...

Booting from ROM..heap at start:  65466368 bytes free
uk_rwlock:      48 B measured (uk_rwlock_init_config wrote through byte 48)
identity:       nactive: init 0, rlock 1, runlock 0, wlock -1, wunlock 0
write.acquire:  uk_rwlock_wlock — nactive is -1, no reader can enter
read.acquire:   uk_rwlock_rlock — nactive is 1
read.release:   the mode is in the type, so wunlock here would not compile
hold.skipped:   a lock built and never entered, said out loud
heap at end:    65466368 bytes free
```

Five things that output proves, beyond "it runs":

1. **The size was MEASURED and the number is 48**, not the 72 the headers add up
   to. That line is the entire argument of the previous section, on a real image.
2. **`nactive` reached -1.** The identity witness passed against the linked
   `rwlock.c`, so the mirror's offset 0 and the symbols' identity are both
   established rather than assumed.
3. **All four hot tors ran in order** against a real lock on a real cooperative
   scheduler: `wlock → wunlock → rlock → runlock`.
4. **`hold.skipped` costs the honest program nothing.** The second lock is created
   and never taken; it says so in one greppable word and compiles. Delete the word
   and the same program is refused.
5. **The heap brackets exactly** — 65,466,368 bytes before and after. `create` is a
   `memalign` and `destroy` is a `free`; two locks made and two released leave the
   number where it started. `uklock` has no destructor of its own, so this is the
   only thing that can show `destroy` is not leaking an allocation per lock.

### Measured

| | |
|---|---:|
| `boot_lock.kz` freestanding archive | 12,864 B |
| `boot_lock.kz` bootable unikernel | 172,800 B |
| baseline: `hello.kz` with its own Kconfig (reproduces `BUILD.md`) | 164,544 B |
| measured `sizeof(struct uk_rwlock)`, single-core x86_64 | 48 B |
| build, from clean | ~40 s |

**No boot-time number, and none may be created.** QEMU TCG on arm64, no KVM. And
no "faster than C" claim: the three-way benchmark (asserts-on C, asserts-off C,
proven Koru) that would support one does not exist and this lift did not build it.
What is measured above is image bytes.

## Gate 3 — six misuses that fail to compile

Phantom validation fires in the **emit** pass, not in `--check`. All six pass
`koruc --check` and are refused by `koruc <file>`. Diagnostics verbatim.

**`tests/negative_wunlock_after_rlock.kz`** — hold for reading, release as a
writer. The silent one: in C this admits a writer alongside a live reader.

```
error[KORU030]: Phantom state mismatch: expected 'unikraft.lock:writing' but got 'unikraft.lock:reading!' for argument 'lock'
  --> negative_wunlock_after_rlock.kz:42:0
```

**`tests/negative_runlock_after_wlock.kz`** — hold for writing, release as a
reader. The loud one: in C this kills the lock permanently.

```
error[KORU030]: Phantom state mismatch: expected 'unikraft.lock:reading' but got 'unikraft.lock:writing!' for argument 'lock'
  --> negative_runlock_after_wlock.kz:42:0
```

**`tests/negative_destroy_without_hold.kz`** — the asymmetry gate: build a lock,
throw it away, never enter it.

```
error[KORU030]: Phantom state mismatch: expected 'unikraft.lock:idle' but got 'unikraft.lock:fresh!' for argument 'lock'
  --> negative_destroy_without_hold.kz:43:0
```

**`tests/negative_recursive_write.kz`** — take the write lock while holding it.
Self-deadlock in C; `rwlock.c` calls it a TODO and asserts it away in debug only.

```
error[KORU030]: Phantom state mismatch: expected '!unikraft.lock:fresh|!unikraft.lock:idle' but got 'unikraft.lock:writing!' for argument 'lock'
  --> negative_recursive_write.kz:45:0
```

**`tests/negative_lock_after_destroy.kz`** — lock it again after destroying it.
Double-destroy is the same unspellable shape.

```
error[KORU030]: Use-after-discharge: binding 'done' was already discharged and cannot be used
  --> negative_lock_after_destroy.kz:39:0
```

**`tests/negative_unlock_forgotten.kz`** — take the lock and never give it back.

```
error[KORU030]: Resource 'shared' obligation <reading!> was not discharged. Call: read.release
```

The control is `boot_lock.kz`, which compiles clean through the emit pass and
boots.

### Forgetting to unlock is a compile ERROR — and here is why that is sayable

`unikraft/alloc` deliberately does **not** claim "forgetting to free is a compile
error", because a dropped `<live!>` block has exactly one unattended terminal
disposer and the compiler silently *inserts* the `free`. An insertion is not a
catch.

This module can make the claim, and it is the same mechanism reaching the opposite
outcome. `<reading>`'s only consumer is `read.release`, which is not a disposal —
it mints `<idle!>`, another live obligation. There is nothing for auto-discharge to
elect, so the drop is reported. Measured in all four states:

| dropped handle | outcome |
|---|---|
| `<fresh!>` | **compile error** — `Resource 'guard' obligation <fresh!> was not discharged. Call one of: read.acquire, write.acquire, hold.skipped` |
| `<reading!>` | **compile error** — `Call: read.release` |
| `<writing!>` | **compile error** — `Call: write.release` |
| `<idle!>` | **auto-discharged.** `destroy` is inserted. Verified by compiling a source with zero literal `lock:destroy` calls and finding exactly one `destroy_event.handler` in the emitted Zig. |

So, precisely:

- **Forget to unlock → compile error.**
- **Forget to use a lock you created → compile error.**
- **Forget to destroy an idle lock → compile-time insertion, silent, no leak.**
  Not a catch, and not claimed as one.

## Gate 4 — no silent fallbacks

Every refusal in this module is loud and carries the real reason. The first boot of
this lift is the proof: the layout mirror was wrong, and what the console printed
was the specific test that failed and the reason for it, with **no lock handed
out** — not a guessed size, not a fallback allocation, not a zero. The `| ready`
arm is the only source of a `*Locks`, and `create` is the only source of a `*Lock`,
so a failed probe makes the whole module unusable by construction rather than by
convention.

---

## Claims I do not make

- **Not "faster than C".** Forbidden by the brief, and there is no benchmark. The
  honest claim is that Koru dissolves the asserts-on/asserts-off tradeoff for the
  8 assertions above.
- **No boot-time number.** QEMU TCG, no KVM.
- **Not "this lifts `uklock`".** It lifts `rwlock.c`. The mutex and the semaphore
  are unreachable from a separately-linked archive and are named, with their line
  numbers, in the linkability section. 20 of the 30 assertions are theirs and none
  are retired.
- **Not "forgetting to destroy a lock is a compile error."** True for `<fresh!>`,
  `<reading!>` and `<writing!>`; for `<idle!>` it is an *insertion*. Both are stated
  above with their evidence.
- **Not "this makes locking safe."** It is a single-holder model. `nactive` counts
  concurrent readers and a phantom state cannot count, so one `*Lock` handle means
  one holder. Two Koru flows sharing a lock is not something this module models,
  and the two properties it therefore cannot give you are:
  - **Destroying a lock other threads are still waiting on.** The waiters are on
    the lock's own wait queues and no state on this handle knows about them.
  - **Lock-ORDER inversion between two locks.** Classic ABBA deadlock is a property
    of a *set* of locks; every state here is per-handle. A lift that ordered locks
    would need a lattice in the type system and would be a different design.
- **Not "the critical section is protected."** The states prove the lock is held,
  not that the data was touched under it. Nothing in Koru ties a lock to the memory
  it guards, and pretending otherwise by requiring a `read`/`write` between acquire
  and release would be ceremony that proves nothing — see refusal 1 above.
- **`UK_RWLOCK_CONFIG_WRITE_RECURSE` is not supported**, and not because this lift
  chose to omit it. `rwlock.c:22` says the implementation does not have it. It has
  no spelling here.
- **No ISR variants.** `include/uk/isr/` holds interrupt-context mutex and
  semaphore wrappers. They are inline, and the rwlock has no ISR variant at all.
- **`uk_rwlock_upgrade` / `uk_rwlock_downgrade` are not lifted** because they do
  not exist. If upstream ever adds them they are the obvious next two tors:
  `upgrade` would take `<!reading>` and mint `<writing!>`, `downgrade` the reverse,
  and both fall out of the existing states with no new ones.

## What the toolchain got wrong

**Nothing, this session.** Every refusal `koruc` produced was correct and named the
right file and the right binding. The one wrong belief in this work was mine — the
transcribed `sizeof` — and the compiler had no way to know about it. Recorded here
because "the search came back empty" is a result: `unikraft/blk`'s three pinned
defects (empty `Source` block, double `unikraft` import, zero-arg tor needing
`()`), `unikraft/alloc`'s `Allocator` identifier collision, and the worktree-alias
hole are all still the known list, and this lift hit none of them because they are
all written down.

Two working notes for the next contestant, neither a defect:

1. **`koruc` writes beside the ENTRY FILE, not into `$PWD`.** `koruc
   /tmp/build/unikraft/lock/tests/boot_lock.kz unikraft gen` run from `/tmp/build`
   puts `Makefile.uk` and `Kraftfile` in `unikraft/lock/tests/`, and then the
   `kraft build` that expects them in `$PWD` fails. Combined with
   `~std/compiler:paths { unikraft: {{ ENTRY }}/../.. }`, which is also
   entry-relative, the consequence is that **the build directory must be the
   tests directory of a copy of the tree.** The recipe in gate 2 does exactly that.
2. **A branch payload field puns.** `create(locks: proof.locks)` is a `PARSE005`
   error, not an accepted redundancy: *"redundant explicit label 'locks:' — the
   value 'proof.locks' already puns to 'locks'"*. Write `create(proof.locks)`.

## Files

| | |
|---|---|
| `index.kz` | the lift |
| `tests/boot_lock.kz` | gate 2 — probe, create, write/read acquire+release, destroy, `hold.skipped`, bracketed heap |
| `tests/negative_wunlock_after_rlock.kz` | `rwlock.c:120`, enforced — the silent data race |
| `tests/negative_runlock_after_wlock.kz` | `rwlock.c:98`, enforced — the permanently dead lock |
| `tests/negative_destroy_without_hold.kz` | the asymmetry gate |
| `tests/negative_recursive_write.kz` | the self-deadlock the C's own TODO admits to |
| `tests/negative_lock_after_destroy.kz` | use-after-discharge; double-destroy is the same shape |
| `tests/negative_unlock_forgotten.kz` | a hold that is never released — a compile error, not an insertion |
| `tests/wrapper.zig` | C-ABI seam; derives the flow list at comptime |
| `tests/main.c` | Unikraft's `main` calls `koru_main` |
