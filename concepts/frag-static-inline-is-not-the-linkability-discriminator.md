---
type: belief
id: frag-static-inline-is-not-the-linkability-discriminator
provenance: lifting Unikraft's `ukvmem`, whose five caller-facing functions are ALL `static inline` and four of which cost nothing to reconstruct; the fifth is genuinely unreachable, for a different reason
ts: 2026-08-06
---

# `static inline` is not the linkability discriminator — what the inline closes over is (belief)

The rule we have been carrying, earned expensively on `uknetdev` and written into
the Unikraft challenge brief as case 3:

> `static inline` in a header → no symbol is emitted either way. Reaching it needs
> a C shim (an added call frame, against pillar 2) or a hand-mirrored struct (an
> ABI guess).

Stated that way it is a property of the *keyword*, and as a property of the
keyword it is false. It happens to be true of `uk_netdev_rx_one`, and the reason
it is true there is not that the function is inline.

## The instance

`ukvmem` exports `uk_vma_map`, `uk_vma_unmap`, `uk_vma_set_attr`, `uk_vma_find`
and four `struct uk_vma_ops` **data** symbols. Every function a C author actually
calls is `static inline` in `vma_types.h`: `uk_vma_reserve`, `uk_vma_reserve_ex`,
`uk_vma_map_anon`, `uk_vma_map_dma`, `uk_vma_map_stack`. By the keyword rule the
library's whole usable surface is unreachable from a freestanding archive.

It is not. Four of the five are one line:

```c
return uk_vma_map(vas, vaddr, len, attr, flags, name, &uk_vma_anon_ops, __NULL);
```

An exported function and an exported global. Reconstructing that in the lift is
**the identical call with the identical arguments** — no shim, no extra frame, no
ABI claim, nothing added to the emitted code. The inline was a spelling
convenience, and spelling conveniences do not survive a language boundary anyway.

The fifth, `uk_vma_map_stack`, genuinely is out of reach — and the reason names
the real rule. It computes where the usable stack begins inside the VMA from
`CONFIG_LIBUKVMEM_STACK_GUARD_PAGES_TOP` and `…_BOTTOM`, which are Kconfig
integers baked into the kernel with no symbol and no behaviour that recovers
them. Same keyword, opposite verdict.

## The discriminator

**Ask what the inline closes over, not whether it is inline.**

The first statement of this belief split the answer two ways — free, or out of
reach. Re-measuring the whole of `lib/` against it showed the second half was
still banking two unlike costs under one word, so the split is **three**:

- Closes over **exported symbols only** → **free**. Reconstruct it; the emitted
  code is what a careful C author's would be.
- Reads or calls through **struct fields** → **a mirror**, which is a layout
  question, not a linkability one. A struct offset is not a symbol you lack; it
  is a number you can measure, and three shipped lifts have measured it and
  proved it (`pages` against exported symbol addresses, `sched` by walking an
  invariant, `lock` by canary probe). An **indirect call through a
  function-pointer field belongs here** — `dev->rx_one(…)` wants an offset and a
  public typedef, not a symbol.
- Closes over something with **neither a symbol nor an offset** → genuinely out
  of reach: a Kconfig integer baked into the kernel, a file static in another
  compilation unit, or inline assembly, where there is nothing to call at all
  and only something to re-emit.

### The reversal this cost

The first version of this belief said `uk_netdev_rx_one` "is in the second class
because it walks refcounted netbufs through struct fields". The observation was
right; the conclusion inverted. Walking struct fields is what puts it in the
*mirror* class — the class we already know how to pay for — and the brief had
been telling contestants for a wave not to promise `uknetdev`'s transfers on the
strength of it.

With `UK_ASSERT` compiled out, which is the config every lift builds, the whole
body is `dev->rx_one(dev, dev->_rx_queue[qid], pkt)`. A probe unikernel printing
`offsetof` settled the layout in under a minute: `struct uk_netdev` is 64 bytes,
`rx_one` at 8, `_rx_queue` at 32, and **every Kconfig-conditional member is at
the tail**, so the mirror does not move when they flip. `uk_netdev_state_get` is
exported, so it can even be proved by value witness.

So a rule stated one level too shallow does not just misfile the instance it was
derived from — restating it one level deeper reopened a target that had been
written off, and the write-off had already been copied into a brief as guidance.

## What follows

- **A shelf column that counts `static inline` is counting the wrong thing.** The
  number is a hazard estimate, not a budget: sixteen inlines that all forward to
  exported entry points cost nothing, and one that embeds a Kconfig integer costs
  the feature. Re-measured across all 87 `lib/` directories, the split is
  lopsided in the *permissive* direction — most inline surface is mirror-class,
  and pure-NO surface is rare.
- **Measure the body that survives your build, not the body in the file.** Asserts
  are the largest single source of false dependency: every `CONFIG_` name that
  wrote off `uk_netdev_rx_one` appears inside a `UK_ASSERT` that compiles to
  `do {} while(0)`.
- **The same shallowness has two more instances in the same file format.** An
  `exportsyms.uk` line can name a symbol that does not exist (19 across 10
  libraries), and it can name one that exists only as a `static inline` and so
  emits no global at all (33 across 6). Both inflate a "linkable" count, and
  neither is visible to a reading of the keyword or of the list.
- **The check is a five-minute read of the header, and it must happen before the
  target is picked, not after.** Reading `vma_types.h` is what turned "ukvmem's
  usable API is behind a wall" into "ukvmem's usable API is three exported calls
  wearing convenience names."
- **A rule stated over a syntactic marker will be applied over the marker.** The
  fix is not to add exceptions; it is to restate the rule over the property that
  actually decides — here, the closure set.
