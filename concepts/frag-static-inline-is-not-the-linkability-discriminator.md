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

- Closes over **exported symbols only** → free. Reconstruct it; the emitted code
  is what a careful C author's would be.
- Closes over **compile-time constants of the kernel**, file statics, or the
  layout of a private struct → shim or ABI guess, and the case-3 warning holds.

`uk_netdev_rx_one` is in the second class because it walks refcounted netbufs
through struct fields, not because of its storage class. That was always the
reason; the rule was written down one level too shallow, and one level too
shallow is exactly the depth at which a rule sends the next reader to the wrong
answer.

## What follows

- **A shelf column that counts `static inline` is counting the wrong thing.** The
  number is a hazard estimate, not a budget: sixteen inlines that all forward to
  exported entry points cost nothing, and one that embeds a Kconfig integer costs
  the feature.
- **The check is a five-minute read of the header, and it must happen before the
  target is picked, not after.** Reading `vma_types.h` is what turned "ukvmem's
  usable API is behind a wall" into "ukvmem's usable API is three exported calls
  wearing convenience names."
- **A rule stated over a syntactic marker will be applied over the marker.** The
  fix is not to add exceptions; it is to restate the rule over the property that
  actually decides — here, the closure set.
