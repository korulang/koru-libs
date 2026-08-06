---
type: belief
id: frag-an-abi-mirror-can-be-proven-by-an-invariant-when-no-witness-address-exists
provenance: lifting Unikraft's `uksched`, where `struct uk_sched` is reachable only through two `static inline` accessors and every callback slot in it is a `ukschedcoop` file static — so `unikraft/pages`' symbol-address proof had nothing to compare against
ts: 2026-08-06
---

# A hand-mirrored struct can be proven without knowing a single address in it — walk an invariant the owner maintains (belief)

A lift that mirrors a C struct is making an **ABI claim**, and a wrong ABI claim
corrupts memory silently. The corpus had two answers, and they are not equally
strong:

- **`unikraft/blk`** guards its mirror with `@offsetOf` assertions. Those prove
  the mirror is *self-consistent* and say nothing whatever about the C.
- **`unikraft/pages`** interrogates the C at run time: it compares six slots of
  `struct uk_alloc` against the addresses of six **exported** symbols, and only
  one initializer in `ukalloc` produces that exact sequence. That is a real
  proof, and it was taken as the bar.

`uksched` cannot pay that bar and the reason generalises: **the witness has to be
a symbol you can name from a separately-linked archive**, and a library that
initializes its vtable from file statics exports none. `struct uk_sched.yield`,
`.thread_add`, `.thread_remove` are `schedcoop_yield` and friends in
`lib/ukschedcoop`, on no `exportsyms.uk`, so there is nothing to compare against.

## The move

Prove the mirror against a **structural invariant the owner maintains**, not
against an address it holds. For `uksched` that invariant is roster membership:
`uk_sched_thread_add` links a thread into `sched->thread_list`, and
`uk_sched_start` does the same for the boot thread. So the lift walks
`s->thread_list` from the scheduler it *thinks* it found and looks for the thread
it started from.

Passing that walk confirms **three** mirrored offsets at once — that
`uk_thread + 80` is `sched`, that `uk_sched + 72` is that scheduler's roster, and
that `uk_thread + 224` is a thread's link on it — because a list that closes back
onto the thread you started from does not close by accident under wrong offsets.
It also re-proves itself every time the same walk is used to count threads.

## What follows

- **Address-witness and invariant-witness are two techniques, not one technique
  with a fallback.** Reach for the address when the library exports its
  implementation symbols; reach for the invariant when it does not. Neither is
  weaker in principle. The invariant walk is arguably stronger, because a matching
  address proves the field is where you think, while a closing traversal proves
  several fields are *and* that the structure is live.
- **Look for a cycle, not a value.** The useful invariants are the ones where a
  data structure points back at something you already hold: a roster containing
  its own members, a parent whose child list names you, a handle stored in the
  object it refers to. A single scalar sanity check ("this looks like a count")
  proves nothing; a closed loop through several mirrored offsets proves all of
  them.
- **Guard the walk with a bound and refuse on overrun.** An unterminated list is
  the exact symptom of a wrong offset, so the bound is not defensive padding — it
  is one of the tests.
- **Do the read-only cheap checks first, and make no call through the pointer
  until the walk closes.** The failure mode being defended against is jumping
  through a garbage function pointer, so the ordering of the proof is part of the
  proof.
