# `unikraft/sched` — Unikraft's `uksched`, lifted

```koru
~import unikraft/sched

~unikraft/sched:current
| ready sched |> unikraft/sched:reserve(sched, name: "koru-worker", stack: 0)
    | thread box |> unikraft/sched:prime(thread: box, laps: 3)
        | ok wired |> unikraft/sched:attach(thread: wired)
            | ok queued |> unikraft/sched:run(thread: queued)
                | ok live |> unikraft/sched:join(thread: live)
                    | done fin |> unikraft/sched:terminate(fin.thread)
```

Thirteen tors, six phantom states, two mirrored structs **proven at run time by
walking an invariant rather than comparing an address**, and two named escape
hatches.

**The gate this module exists for: a thread that was given a stack, a TLS and a
place in the run queue, and then destroyed without ever executing an
instruction, is not a program you can write.** `terminate` accepts only `<!ran>`
or `<!parked>`, and `<ran!>` is minted only on *evidence* that the thread ran.

---

## Why `uksched` and not another device

The brief asks for a different **organ**, not a different opinion. `ukblkdev`
(shipped) and `uknetdev` are one object walking forward through a bring-up.
A thread is two things at once:

- an **ordering** — you may not install an entry point twice, you may not attach
  a thread the scheduler already holds, you may not free a thread the scheduler
  still holds; and
- a **lifetime the resource itself can end** — a thread body can call
  `uk_sched_thread_exit()` and invalidate its parent's handle at a moment the
  parent cannot observe.

`ukblkdev` has no analogue of either. The second one is the interesting half and
it is where this lift makes its one big design commitment (below).

---

## The tors

| tor | takes | mints | C call |
|---|---|---|---|
| `current` | — | branch, not state | none — reads the per-CPU current thread and runs the layout proof |
| `census` | `*Sched` | — | none — walks `sched->thread_list` |
| `reserve` | `*Sched`, `name`, `stack` | `<container!>` | `uk_thread_create_container` |
| `prime` | `<!container>`, `laps` | `<primed!>` | `uk_thread_container_init_fn1` |
| `attach` | `<!primed>` | `<queued!>` | `uk_sched_thread_add` |
| `run` | `<!queued\|!ran>` | `<ran!>` | `sched_yield`, then proof it ran |
| `join` | `<!queued\|!ran>` | `<ran!>` + lap count | `sched_yield` until finished |
| `park` | `<!ran>` | `<parked!>` | `uk_thread_block` |
| `unpark` | `<!parked>` | `<ran!>` | `uk_thread_wake` |
| `terminate` | `<!ran\|!parked>` | — | `uk_sched_thread_terminate` |
| `never-ran` | `<!queued>` | `<ran!>` | **none — the escape** |
| `unspawned` | `<!container\|!primed>` | `<detached!>` | **none** |
| `release` | `<!detached>` | — | `uk_thread_release` |

Six states: `container`, `primed`, `queued`, `ran`, `parked`, `detached`.

### `<ran!>` is an observation, not an inference

Every other state in this module is a claim about what the C did. `<ran!>` is a
claim about what the *scheduler* did, and a lift is not entitled to infer that
from a yield — "one yield reaches the new thread" is a statement about
`ukschedcoop`'s round-robin policy, not about the thread.

So the entry shim raises a flag as its first act, and `run` reads that flag after
yielding. If it is clear, `run` takes `| stalled` and hands the handle back in
`<queued!>` — the weaker of the two claims. **There is no arm in this module that
mints `<ran!>` without evidence**, except `never-ran`, which is the escape and
says so in its name.

The number of yields `run` will spend is the scheduler's roster size, taken from
`census`. Not a constant: a program with eight workers needs eight yields to
reach the last one, and hardcoding a number would be a policy this module made up.

### The two escapes, and why there are two rather than one

- **`sched:never-ran`** — `<!queued>` → `<ran!>`. "This worker was attached and
  deliberately never scheduled." `grep -r "sched:never-ran"` answers *which
  programs allocate thread stacks they never run*.
- **`sched:unspawned`** — `<!container|!primed>` → `<detached!>`. "This thread
  never reached the scheduler at all."

They are not the same question and they cannot be one tor: an *attached* thread
must go through `uk_sched_thread_terminate` (which removes it first), and an
*unattached* one must go through `uk_thread_release` (which asserts it was never
attached). Two exits, because the C has two.

`unspawned` has a second role and it is stated rather than hidden: it is also the
recovery arm out of a failed `attach` and a rejected `prime`. That does dilute
its grep a little — it will appear on failure arms as well as on deliberate
skips — and the alternative was two tors with identical bodies and identical
states, which is ceremony, not information.

---

## Who owns a thread's death — the one decision everything follows from

Unikraft supports two disciplines and they are incompatible:

| | who ends the thread | who frees it |
|---|---|---|
| **(A) owned** | the parent, via `uk_sched_thread_terminate` | the same call (`sched.c:327`) |
| **(B) self-exiting** | the body, via `uk_sched_thread_exit()` | `uk_sched_thread_gc`, later |

**An obligation can only describe (A).** Under (B) the parent's handle becomes
dangling at a moment the parent cannot observe: `uk_sched_thread_terminate` has
already run `uk_sched_thread_remove`, which NULLs `t->sched`, so a subsequent
`terminate` from the parent trips its own `UK_ASSERT(thread->sched)` in a debug
build and writes through a freed allocation in a release one. The C's own comment
at `sched.c:294-299` says exactly this about double-termination and offers only
"test for the exited flag" as the remedy — a race the caller is expected to win.

**This lift models (A), and it does not merely document that — it makes (B)
unreachable.** The entry shim it owns never returns and never exits: after its
last lap it parks (`uk_thread_block` + yield, forever). So while a `*Thread`
handle exists, the thread it names is still there, and `terminate` is always a
legal call.

The cost is stated under *claims I do not make*: `uk_sched_thread_exit`,
`uk_sched_thread_exit2` and `uk_sched_thread_gc` are not bound, and a thread pool
whose workers exit on their own is not expressible in this module.

---

## What a caller supplies, and what it cannot

The C thread entry is `void (*)(void *) __noreturn`. **Koru has no first-class
function value at the surface.** Nothing in the language's test suite passes a
flow or a tor as an argument; every callback in `koru-libs` (`curl/index.kz:53`,
`unikraft/blk`'s queue callback) is a module-private Zig function, never
something a caller hands in. And "no threads at the surface" is a stated tenet of
the language, so there is no spelling to invent here either — inventing one would
break the repo's first rule.

So **this module owns the entry point and the caller supplies data**: a thread
name and a lap count. The shipped body announces each lap on the console from its
own stack and yields between laps.

That is enough to drive every state in the machine against the real cooperative
scheduler, and the console output proves a context switch rather than a function
call. It is **not** a general-purpose "run my code on a thread" facility, and the
gap is a language question, not a lift question — it is filed under *claims I do
not make* and in *what the toolchain got wrong*.

---

## The layout proof

There is **no exported way to obtain a `struct uk_sched *`.** `uk_sched_current()`
is `static inline` (`sched.h:53`) over `uk_thread_current()`, which is also
`static inline` (`thread.h:100`), and every field of `struct uk_sched` is reached
by member access. That is the brief's **case 3**, and the two routes it names are
a C shim (an added call frame, and it would put the shim in every *user's* build,
not just the test harness) or a hand-mirrored struct. This module mirrors, and
then proves the mirror before writing through it — the bar `unikraft/pages` set.

But `pages`' technique is not available here. `pages` compares table slots against
the addresses of six **exported** symbols; `struct uk_sched`'s function pointers
are `schedcoop_yield` and friends, which are **file statics in `lib/ukschedcoop`**
and on no `exportsyms.uk`. This archive cannot know a single one of their
addresses.

So the proof is **structural** — it checks an invariant the scheduler maintains
rather than an address it holds. Six tests, all read-only, and no call is made
through any mirrored pointer until every one passes:

1. `uk_thread_current()` is non-NULL. Before `uk_sched_start` it is NULL —
   `sched.c:213` asserts precisely that — so this also proves boot got far enough.
2. `t->sched` at offset 80 is non-NULL and 8-aligned.
3. `s->is_started` is true. `sched.c:249` sets it and nothing clears it.
4. `s->next` is NULL, and `s->a` and `s->a_uktls` are `_uk_alloc_head` — the one
   allocator address this archive knows independently. `ukboot/boot.c:360` passes
   `uk_alloc_get_default()` as both. `a_stack` and `a_auxstack` are checked
   non-NULL only, because `ukboot` hands those two *different* allocators
   (measured: `0x16b020` and `0x43020` against `0x41000`).
5. Every callback slot the scheduler must have — `yield`, `thread_add`,
   `thread_remove`, `thread_blocked`, `thread_woken`, `sched_start` — is non-NULL.
6. **The round trip.** Walk `s->thread_list` and find the current thread on it.
   That list is threaded through `uk_thread.thread_list` at offset 224, and
   membership is the exact invariant `uk_sched_thread_add` (`sched.c:373`) and
   `uk_sched_start` (`sched.c:241`) maintain. Passing it confirms **three**
   mirrored offsets at once — that 80 is `sched`, that 72 is that scheduler's
   roster, and that 224 is a thread's link on it — in a structure that could not
   close by accident.

If any test fails, `current` takes `| unavailable` and names which one. Because
`current` is the only source of a `*Sched` and `reserve` is the only source of a
`*Thread`, nothing in this module is reachable after a refusal. There is no
degraded path and no assumed layout.

Cost: about a dozen loads and one walk of a two-element list, once per program.

### How the offsets were measured

Not guessed and not read off a header — measured on the kernel that gets linked,
which is **Unikraft 0.21.0 "Ijiraq"** (what `Kraftfile: unikraft.version: stable`
fetches), x86_64. A probe image whose whole `main.c` is `printf`s of `offsetof`:

```c
#include <stdio.h>
#include <stddef.h>
#include <uk/sched.h>
#include <uk/thread.h>
#include <uk/alloc.h>
#include <uk/pcpuvar.h>

extern struct uk_alloc *_uk_alloc_head;
extern __uk_pcpuvar struct uk_thread *__uk_sched_thread_current;

int main(int argc, char *argv[])
{
	struct uk_thread *t = uk_thread_current();
	struct uk_sched *s = uk_sched_current();

	printf("sizeof(uk_thread)=%zu sched=%zu thread_list=%zu\n",
	       sizeof(struct uk_thread), offsetof(struct uk_thread, sched),
	       offsetof(struct uk_thread, thread_list));
	printf("sizeof(uk_sched)=%zu is_started=%zu thread_list=%zu a=%zu next=%zu\n",
	       sizeof(struct uk_sched), offsetof(struct uk_sched, is_started),
	       offsetof(struct uk_sched, thread_list), offsetof(struct uk_sched, a),
	       offsetof(struct uk_sched, next));
	printf("current=%p sched=%p direct-read=%p alloc_head=%p\n",
	       (void *)t, (void *)s, (void *)__uk_sched_thread_current,
	       (void *)_uk_alloc_head);
	printf("s->a=%p s->a_stack=%p s->a_auxstack=%p s->a_uktls=%p started=%d\n",
	       (void *)s->a, (void *)s->a_stack, (void *)s->a_auxstack,
	       (void *)s->a_uktls, (int)s->is_started);
	return 0;
}
```

What it printed:

```
PROBE sizeof(struct uk_thread)=240
PROBE offsetof(uk_thread, flags)=64
PROBE offsetof(uk_thread, sched)=80
PROBE sizeof(struct uk_sched)=144
PROBE offsetof(uk_sched, is_started)=64
PROBE offsetof(uk_sched, thread_list)=72
PROBE offsetof(uk_sched, exited_threads)=88
PROBE offsetof(uk_sched, a)=104
PROBE offsetof(uk_sched, a_stack)=112
PROBE offsetof(uk_sched, a_auxstack)=120
PROBE offsetof(uk_sched, a_uktls)=128
PROBE offsetof(uk_sched, next)=136
PROBE current thread=0x91020 sched=0x3fd1020
PROBE direct-read __uk_sched_thread_current=0x91020
PROBE alloc_head=0x41000 default=0x41000
PROBE s->a=0x41000 s->a_stack=0x16b020 s->a_auxstack=0x43020 s->a_uktls=0x41000 next=0 started=1
```

`offsetof(uk_thread, thread_list)` is 224 by construction: `name` sits at 216 and
the struct is 240 bytes, with a 16-byte tailq entry closing it.

### The per-CPU read, which the probe also settled

`__uk_sched_thread_current` is `__uk_pcpuvar` (`sched.c:50`): the symbol addresses
a **template** in `.uk_pcpuvar`, and each CPU's live copy sits at
`template + tmpl_size * cpu_idx`, reached through GS on x86_64 and `TPIDR_EL1` on
arm64.

The probe line that matters is `direct-read == current thread`: on the boot CPU a
plain load of the extern variable happens to be right, because `cpu_idx` is 0 and
the live copy *is* the template. **That is a coincidence and this module does not
take it.** `currentThread()` emits the same one instruction the C macro emits, for
both architectures Unikraft implements, and `@compileError`s on any third. The
instruction costs the same; the assumption is what would have cost something.

The `struct uk_sched` mirror has one property `pages`' does not: **no build option
can shift it.** The only `#ifdef` in the C declaration is
`CONFIG_LIBUKSCHED_STATS`, and it appends fields *after* `next` — past everything
mirrored. So this module needs no equivalent of `pages`' `IFMALLOC` detector.

---

## The `UK_ASSERT` census

`grep -rn UK_ASSERT lib/uksched` returns **112** hits at Unikraft 0.21.0.
**This lift retires 22 of them.** Per site, not banked.

### Retired — 22

| where | function | how it is retired |
|---|---|---|
| `thread.c:870` | `uk_thread_container_init_fn1` | `*Thread` is non-nullable and only `reserve` mints one |
| `thread.c:871` | `uk_thread_container_init_fn1` | the entry point is `&workerBody`, a module constant — a caller cannot supply NULL |
| **`thread.c:872`** | `uk_thread_container_init_fn1` | **`UK_ASSERT(t->ctx.ip == 0x0)`** — `prime` consumes `<!container>` and nothing re-mints it for a primed thread. Pinned by `negative_prime_twice.kz` |
| **`thread.c:873`** | `uk_thread_container_init_fn1` | **`UK_ASSERT(!(t->flags & UK_THREADF_RUNNABLE))`** — same consumption; the runnable bit is set by `prime` itself |
| `sched.c:362` | `uk_sched_thread_add` | a `*Sched` can only be **named** inside `current`'s `\| ready` arm |
| `sched.c:363` | `uk_sched_thread_add` | non-nullable handle |
| **`sched.c:364`** | `uk_sched_thread_add` | **`UK_ASSERT(!t->sched)`** — `attach` consumes `<!primed>`, which an attached thread cannot be in |
| `sched.c:293` | `uk_sched_thread_terminate` | non-nullable handle |
| **`sched.c:300`** | `uk_sched_thread_terminate` | **`UK_ASSERT(thread->sched)`**, whose own comment says it "can also fail on a double-termination" — `terminate` **consumes** the handle, so a second call has nothing to pass |
| `sched.c:384` | `uk_sched_thread_remove` | reached only from `terminate`; same argument |
| `sched.c:385` | `uk_sched_thread_remove` | same |
| `thread.c:1003` | `uk_thread_release` | non-nullable handle |
| **`thread.c:1004`** | `uk_thread_release` | **`UK_ASSERT(t != uk_thread_current())`** — this module never hands out a handle on the running thread. `current` returns a `*Sched`, never a `*Thread` |
| **`thread.c:1005`** | `uk_thread_release` | **`UK_ASSERT(!t->sched)`** — `release` accepts only `<!detached>`, minted only by `unspawned`, reachable only from never-attached states. Pinned by `negative_release_while_attached.kz` |
| `thread.c:1043` | `uk_thread_block_until` | non-nullable handle, via `park` |
| `thread.c:1066` | `uk_thread_block` | same |
| `sched.h:136` | `uk_sched_thread_blocked` | same |
| `sched.h:137` | `uk_sched_thread_blocked` | `UK_ASSERT(t->sched)` — `<ran>` is only reachable while attached |
| `sched.h:149` | `uk_sched_thread_woken` | non-nullable handle, via `unpark` |
| `sched.h:150` | `uk_sched_thread_woken` | `UK_ASSERT(t->sched)` — `<parked>` is only reachable while attached |
| `sched.h:121` | `uk_sched_yield` | `UK_ASSERT(current)` — a `sched_yield` in this module is reachable only after `current` proved a running thread exists |
| `sched.h:124` | `uk_sched_yield` | `UK_ASSERT(s)` — same proof established the scheduler |

### Traversed but NOT retired — 11

Assertions on code paths this lift *does* call, which it does not retire because
**a caller could not violate them in the first place.** Counting them would be
inflation.

| where | why not |
|---|---|
| `sched.h:138` | `UK_ASSERT(!uk_thread_is_runnable(t))` — `uk_thread_block_until` clears the bit two lines above the call. An internal invariant, not a caller rule |
| `sched.h:151` | `UK_ASSERT(uk_thread_is_runnable(t))` — `uk_thread_wake` sets it two lines above the call. Same |
| `thread.c:83`, `:84` | inittab entry validity, inside `_inittab_call_init` |
| `thread.c:100`, `:101` | termtab entry validity |
| `thread.c:117` | about the **parent** thread's ECTX flag |
| `thread.c:179` | about whether a termination callback runs on a thread with ectx |
| `thread.c:242`, `:270` | `_uk_thread_struct_init`'s own TLS/aux-stack consistency |
| `thread.c:501` | `_uk_thread_struct_init_alloc`'s `UK_ASSERT(t)`, on memory `create_container` just allocated and checked |

### Not bound at all — 79

| group | count | why not |
|---|---:|---|
| `uk_sched_thread_create_fn0/1/2` (`sched.c:82-84,127-129,172-174`) | 9 | **Deliberately unbound.** That fused call does create-container + prime + add in one, so lifting it would COLLAPSE exactly the three ordering rules the C asserts separately — `ip == 0`, `!RUNNABLE`, `!t->sched`. Binding it would have hidden the assertions this challenge exists to lift |
| `uk_sched_start` (`sched.c:210-213`) | 4 | `ukboot` calls it before `main`; a Koru program cannot reach it, and `sched.c:213` asserts no thread is running, which is false by the time any Koru flow exists |
| `uk_sched_thread_gc` (`sched.c:272-273`) | 2 | the exited list is populated only by a thread exiting *itself*, which discipline (A) makes unreachable — so this tor would always return zero, and a tor that cannot do anything is not restraint, it is decoration |
| `sched_setaffinity` (`sched.c:439-440`) | 2 | SMP affinity; the images here are single-core |
| `uk_thread_init_bare*` / `uk_thread_init_fn*` / `uk_thread_create_bare` / `create_container2` (`thread.c:290-370, 539-629`) | 24 | caller-supplied stack and TLS pointers. A lift of these would be handing users raw `uintptr_t` stack pointers, which is the opposite of pillar 1 |
| `uk_thread_container_init_bare/fn0/fn2` (`thread.c:843-847, 856-859, 884-887`) | 12 | the same assertions `fn1` carries, on the arities this module does not use. The rule is retired once, on the arity that is bound |
| `uk_thread_create_fn0/1/2` (`thread.c:909-910, 942-943, 975-976`) | 6 | fused, same argument as `uk_sched_thread_create_fn*` |
| `uk_thread_block_timeout` (`thread.c:1059`) | 1 | timed blocking is a clock facility; `ukplat`'s monotonic clock is a different library |
| `stats.c` | 9 | `CONFIG_LIBUKSCHED_STATS`, off in these images |
| `wait.h`, `isr/sched.h`, `tcb_impl.h`, `thread.h:704`, `sched_impl.h:107`, `sched.h:168` | 10 | wait queues, ISR wake paths, the TLS accessor macro, and the context switch itself — none of them a surface this module binds |

**22 retired, 90 not, per site.** The number is not the contribution; *which* 22
is. Four of them (`thread.c:872`, `:873`, `sched.c:364`, `sched.c:300`) are the
ordering rules that make this an ordering lift rather than a wrapper, and one
(`thread.c:1005`) is a use-after-free the C only notices with asserts on.

### The state branches, and what they say about the C

The brief also asks for real `if (… state …)` branches. `uksched` has them, and
they all point the same way:

```c
uk_thread_block_until:  if (uk_thread_is_runnable(thread)) { ...set blocked... }
uk_thread_wake:         if (!uk_thread_is_runnable(thread)) { ...set runnable... }
schedcoop_thread_add:   if (uk_thread_is_runnable(t))  INSERT into run queue
uk_sched_thread_terminate: if (thread == uk_thread_current()) ...gc list... else ...release...
```

**Every one is an idempotence guard.** Blocking a blocked thread is a silent
no-op; waking a runnable one is a silent no-op. So `uksched`'s runtime state
checks do not *reject* misuse, they *absorb* it — which is worse than an
assertion, because it survives `-DNDEBUG` and still tells you nothing. The
phantom states turn the same four questions into build errors.

### The one place the C is silently dangerous and there is no assertion

`schedcoop_thread_woken_isr` (`lib/ukschedcoop/isrwoken.c`) re-queues a woken
thread **only if `UK_THREADF_QUEUEABLE` is set**, and that flag is set by the
context switch, on the thread being switched *away from*. So waking a thread that
has never yet been switched away from does not put it back in the run queue: the
thread is runnable, attached, on `thread_list`, and never scheduled again. No
assertion fires, in any build.

This module cannot reach that shape, because `park` accepts only `<!ran>`, and
`<ran!>` exists only after the thread executed and yielded — which is precisely
the context switch that sets the flag. That is not a lifted assertion; it is a
hazard with no assertion to lift, and the ratchet closes it as a side effect of
being honest about what `<ran>` means.

---

## Gate 1 — `--check`

```
$ koruc --check unikraft/sched/index.kz
✓ Shape checking passed
```

## Gate 2 — it boots

```sh
# The build dir must sit two levels under a tree containing `unikraft/`,
# because the entry file resolves its own namespace with
# `unikraft: {{ ENTRY }}/../..`. `unikraft/sched/boot/` is that place.
mkdir unikraft/sched/boot && cd unikraft/sched/boot
cp ../tests/{boot_threads.kz,wrapper.zig,main.c} .

koruc boot_threads.kz unikraft gen     # -> Makefile.uk + Kraftfile
koruc boot_threads.kz                  # -> output_emitted.zig.
                                       # The host link then fails on Unikraft
                                       # symbols; that is expected.
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

Booting from ROM..proven:    2 threads on the scheduler (init + idle), roster walked
attached:  3 threads, the worker has a stack and has run nothing
  [koru-worker] lap 1 of 3, on its own stack
main:      back from one yield, the worker executed
main:      worker parked; <parked> is not a state run accepts
  [koru-worker] lap 2 of 3, on its own stack
  [koru-worker] lap 3 of 3, on its own stack
joined:    worker finished 3 laps
reaped:    2 threads, stack and TLS given back
```

Four things that output proves:

1. **The structural proof passed on a real image.** Reaching `| ready` at all is
   the six tests passing, including the roster walk finding the running thread on
   its own scheduler's list. A wrong offset prints a reason and takes nothing.
2. **The roster brackets the program and comes back equal.** 2 → 3 → 2, counted
   by the same walk, so the two end numbers are also the proof re-run.
3. **The interleave is real.** `[koru-worker] lap 1` appears *between* two `main:`
   lines, and laps 2 and 3 appear inside `join`. Two threads alternating on one
   console is a cooperative context switch, not a function call.
4. **`park` and `unpark` moved a live thread out of and back into the run queue**
   while `main` held the only handle to it, and the worker resumed afterwards —
   which is the `QUEUEABLE` hazard above not firing.

### Measured

| | |
|---|---:|
| `boot_threads.kz` freestanding archive | 15,344 B |
| `boot_threads.kz` bootable unikernel | 172,800 B |
| baseline: `unikraft/pages`' image | 168,704 B |
| baseline: `hello.kz` from `BUILD.md` | 164,544 B |
| build, from `rm -rf .unikraft/build .config.koru` | ~18 s |
| RAM floor (boots) | 3 MB |
| RAM floor (fails) | 2 MB |

The floor is 1 MB above the 2 MB `BUILD.md` records for a thread-free image, and
that is the point of the asymmetry gate stated in bytes:
`CONFIG_STACK_SIZE_PAGE_ORDER` is 6, so the worker's stack alone is 256 KiB, plus
an aux stack and a TLS.

**No boot-time number and no "faster than C" claim** — both forbidden by the
brief, and neither benchmark exists.

## Gate 3 — three misuses that fail to compile

Phantom validation fires in the **emit** pass, not in `--check`. All three pass
`koruc --check` and are refused by `koruc <file>`. Diagnostics verbatim.

**`tests/negative_terminate_without_run.kz`** — the asymmetry gate. Reserve, prime,
attach, then destroy without ever giving the thread CPU.

```
error[KORU030]: Phantom state mismatch: expected '!unikraft.sched:ran|!unikraft.sched:parked' but got 'unikraft.sched:queued!' for argument 'thread'
  --> negative_terminate_without_run.kz:48:0
```

**`tests/negative_prime_twice.kz`** — `thread.c:872-873` lifted. Install an entry
point on a thread that already has one, rewriting where the CPU will resume.

```
error[KORU030]: Phantom state mismatch: expected 'unikraft.sched:container' but got 'unikraft.sched:primed!' for argument 'thread'
  --> negative_prime_twice.kz:38:0
```

**`tests/negative_release_while_attached.kz`** — `thread.c:1005` lifted. Free a
thread's struct, stack, aux stack and TLS while the scheduler still holds it.

```
error[KORU030]: Phantom state mismatch: expected 'unikraft.sched:detached' but got 'unikraft.sched:ran!' for argument 'thread'
  --> negative_release_while_attached.kz:40:0
```

Two controls, both of which compile clean through the emit pass:

- **`tests/boot_threads.kz`** — the full chain, which also boots.
- **`tests/never_ran_escape.kz`** — the first negative with `sched:never-ran`
  inserted in front of the `terminate`, and nothing else changed. It compiles, so
  the refusal next door is about the missing declaration and not about the shape
  of the chain.

---

## What the toolchain got wrong

### A host-line local shadows a tor input, and the emitter answers with unscoped find-and-replace

**This cost the first build and it edits string literals, so it can produce wrong
*behaviour*, not only a compile error.**

If any host line in a module declares a name that a tor also takes as an input —
**including a function-local `const` inside an unrelated helper** — `koruc` stops
binding that input to a local in the emitted handler and instead substitutes the
bare token textually across the whole proc body. The substitution is not scoped:
it rewrites the field name in `box.laps`, and it rewrites text inside string
literals.

Minimal repro, `lib/mod/index.kz`:

```koru
const Box = extern struct { laps: u32 };

// A module-private helper with a FUNCTION-LOCAL `const laps`.
fn total(b: *Box) u32 {
    const laps = b.laps;
    return laps + 1;
}

~pub tor prime { box: *Box<!fresh>, laps: u32 }
| ok *Box<primed!>
| rejected { box: *Box<fresh!>, reason: string }

~proc prime|zig {
    if (laps == 0) {
        return .{ .rejected = .{ .box = box, .reason = "zero laps is not a lap count" } };
    }
    box.laps = laps;
    return .{ .ok = box };
}
```

Emitted:

```zig
pub fn handler(__koru_event_input: Input) Output {
    const box = __koru_event_input.box;
    _ = &box;
    _ = &__koru_event_input;

        if (__koru_event_input.laps == 0) {
            return .{ .rejected = .{ .box = box, .reason = "zero __koru_event_input.laps is not a lap count" } };
        }
        box.__koru_event_input.laps = __koru_event_input.laps;
        return .{ .ok = box };
}
```

Note the two failures are of different severity. `box.__koru_event_input.laps`
fails to compile — loud. `"zero __koru_event_input.laps is not a lap count"`
compiles fine and ships a corrupted diagnostic to a user.

**The control that localises it:** delete the `total` helper and nothing else. The
same file then emits `const laps = __koru_event_input.laps;` and the body is left
untouched. So the trigger is the host-line declaration, not the field name, not
the branch payload, and not the arity — a `Box` with a `laps` field and a second
tor whose branch payload also has a `laps` field were both tried first and neither
reproduces it.

This is the same disease as koru's `store.kz` find-and-replace hazard: textual
substitution over source that has no scope model.

**What this lift did about it, stated plainly.** Every name in the design survives
— the tor input is still `laps`, the handle field is still `laps`, no state and no
tor was renamed. What changed is one incidental local inside `workerBody`
(`const laps = h.laps;`), which was a readability convenience and is now an inline
`h.laps`. A comment at the site says why so nobody re-adds it. That is the
smallest honest containment; the defect itself is not fixed here and it is not
mine to fix.

### `string` is not a type outside a `~proc`

A host-line helper cannot be written `fn dupz(text: string)`. Inside a `~proc`
body a `string` parameter behaves like a slice, but the identifier `string` is not
in scope for raw Zig host lines and the emitted file fails with `use of undeclared
identifier 'string'`. The Zig spelling is `[]const u8`. Not a defect, but nothing
says so anywhere and it costs a build to find out.

### Punning is enforced on member expressions

`terminate(thread: fin.thread)` is a `PARSE005` — `fin.thread` already puns. Worth
knowing before writing a deep pipeline, because the error appears once per site.

---

## Claims I do not make

- **Not "you can run your own code on a thread."** This module owns the entry
  point. Koru has no first-class function value at the surface, and "no threads at
  the surface" is a language tenet, so there is no spelling to invent. The caller
  supplies a name and a lap count.
- **Not "this lifts self-exiting threads."** `uk_sched_thread_exit`,
  `uk_sched_thread_exit2` and `uk_sched_thread_gc` are unbound. The obligation
  model cannot describe a resource that ends its own life, and pretending
  otherwise would put a dangling handle behind a compile-time guarantee.
- **Not "the fused spawn is missing."** `uk_sched_thread_create_fn1` is left
  unbound *on purpose*, and that is a design claim, not an omission: it collapses
  three separately-asserted ordering rules into one call. Someone may reasonably
  want it back for ergonomics; they should read the assert census first.
- **Not "the ABI is guaranteed."** It is *checked*, at run time, by walking an
  invariant. That is stronger than `@offsetOf` self-consistency and weaker than a
  compile-time guarantee. It is what is available when every candidate witness
  symbol is a file static.
- **Not "the mirror is version-independent."** The offsets were measured against
  Unikraft 0.21.0 x86_64. A different release moves them, and the run-time proof
  is what turns that into a loud refusal instead of a corrupted list.
- **Not "one yield schedules a thread."** `run` and `join` yield up to the roster
  size and then say `| stalled` rather than assume.
- **No preemption, no SMP.** These images run `ukschedcoop` on one core.
  `sched_setaffinity` is unbound and multi-scheduler setups are refused outright
  by `current` (`s->next` must be NULL).
- **No boot-time number, no "faster than C".** Both forbidden by the brief.
- **The 22-of-112 assert score is not dressed up.** 79 of the remaining 90 are on
  surfaces this lift deliberately does not bind, and 11 are internal invariants a
  caller could not violate. The four that matter are named.

## Files

| | |
|---|---|
| `index.kz` | the lift |
| `tests/boot_threads.kz` | gate 2 — the whole chain, with the roster bracketed |
| `tests/negative_terminate_without_run.kz` | the asymmetry gate |
| `tests/negative_prime_twice.kz` | `thread.c:872-873` — priming a live thread |
| `tests/negative_release_while_attached.kz` | `thread.c:1005` — freeing a scheduler's thread |
| `tests/never_ran_escape.kz` | positive control: the escape hatch compiles |
| `tests/wrapper.zig` | C-ABI seam; derives the flow list at comptime |
| `tests/main.c` | Unikraft's `main` calls `koru_main` |
