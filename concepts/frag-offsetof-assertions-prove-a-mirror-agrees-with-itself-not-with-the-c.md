---
type: belief
id: frag-offsetof-assertions-prove-a-mirror-agrees-with-itself-not-with-the-c
provenance: a `struct uk_rwlock` mirror transcribed correctly from three Unikraft headers, guarded with seven `@offsetOf` and a `@sizeOf` assertion, booted and was wrong by 24 bytes
ts: 2026-08-06
---

# A comptime layout assertion proves the mirror agrees with itself; only the running image can say whether it agrees with the C (belief)

Binding a C library that hands out caller-owned structs means transcribing a
layout, and the house reflex for making that safe is a comptime guard:

```zig
comptime {
    if (@offsetOf(Mirror, "field") != 24) @compileError("field moved");
    if (@sizeOf(Mirror) != 72) @compileError("struct changed size");
}
```

That guard reads as rigour and is one. It is rigour about **the wrong thing**. It
compares the mirror against numbers a human wrote down beside it, and both sides
of the comparison come from the same reading of the same headers. It cannot fail
when the reading was wrong; it fails only when someone edits the mirror and
forgets the constant. **A guard that both sides of a mistake pass is not a check.**

## The instance

`unikraft/lock` mirrored `struct uk_rwlock` (`lib/uklock/include/uk/rwlock.h:23`)
in full: four counters, `struct uk_spinlock`, two `struct uk_waitq`. Every field
was transcribed from the right header at the right line. `@sizeOf` came to 72, the
seven `@offsetOf` assertions all held, and `koruc --check` passed.

The image booted and refused, because the struct on the running kernel is **48
bytes**. `struct uk_waitq` embeds a `__spinlock`, and
`include/uk/arch/spinlock.h:35` reads:

```c
#ifdef CONFIG_HAVE_SMP
typedef struct __spinlock __spinlock;      /* { volatile int lock; } — 4 bytes */
#else
typedef struct __spinlock { /* empty */ } __spinlock;    /* SIZE ZERO */
#endif
```

Single-core is the default, so a member vanishes — twice, once per wait queue —
and everything below it moves. `uklock`'s own `Config.uk` never mentions SMP.
`rwlock.h` never mentions it. No exported symbol reports it. Nothing in the
library being bound points at the switch that changes its own layout.

Had the mirror been used to *allocate* rather than to *read a field*, 72 would
have over-allocated and hidden the error indefinitely. In the other direction —
an SMP image, a non-SMP transcription — the same class of mistake is silent heap
corruption.

## What follows

- **Mirror only the fields you read.** Fields you never name cost nothing to omit
  and are the ones whose offsets you have no way to verify. `unikraft/lock` ended
  up mirroring four leading `int`s — offsets the C ABI fixes on every target — and
  naming nothing below them.
- **Do not transcribe a size. Measure it.** Paint an over-allocation with a
  canary, hand it to the library's own initializer, and scan for the highest byte
  it touched. The initializer writes every field the struct has, so its high-water
  mark IS the size, taken from the binary that will run rather than from the
  headers someone read.
- **Put the guard INSIDE the allocation.** A canary tail that must come back
  untouched turns "the struct is bigger than I thought" from silent corruption of
  the allocator's next neighbour into a refusal that names itself. Containment is
  what makes the measurement safe to take at all.
- **Prefer a behavioural witness to a structural one.** Driving the C through a
  transition and reading back a value only that implementation produces — here,
  `nactive == -1` after `wlock` — proves both the offset and the identity of the
  symbol that was linked. `@offsetOf` proves neither.
- **The tell is a `#ifdef` anywhere under the struct you are copying.** Not in the
  struct — *under* it, in a type it embeds, possibly two headers away, keyed on a
  config the library you are binding does not own. Follow every embedded type to
  its definition before believing a transcribed `sizeof`.

## Relation to what was already believed

`unikraft/blk` guards two mirrors this way and its README says the guards "prove
the mirror is self-consistent and say nothing about the C it is mirroring" —
correctly. `unikraft/pages` acted on that and proved its mirror at run time against
six exported symbol addresses. So the limitation was **written down twice and still
did not stop the third lift from transcribing a size**, because the two shipped
modules read as a menu of two equally good techniques rather than as one
superseding the other.

The correction is not new knowledge, it is an ordering: a comptime layout
assertion is a *regression guard on your own edits*, never evidence about the
foreign ABI, and it may not be the only thing standing between a lift and memory
corruption.
