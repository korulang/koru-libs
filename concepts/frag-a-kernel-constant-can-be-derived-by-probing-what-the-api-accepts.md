---
type: belief
id: frag-a-kernel-constant-can-be-derived-by-probing-what-the-api-accepts
provenance: `unikraft/vmem` needed `UK_PAGING_VADDR_ANY` and the page size, neither of which any symbol exports and neither of which is a ratio of two exported numbers
ts: 2026-08-06
---

# A kernel compile-time constant can be recovered by probing what the API accepts, not only by arithmetic on exported values (belief)

`unikraft/pages` established the discipline: a lift **derives** a constant the
kernel does not export, or it refuses — never "assume 4096". Its instrument was
arithmetic. `uk_alloc_availmem_total()` is `pavailmem << __PAGE_SHIFT` exactly, so
dividing the two exported totals *is* the page size.

That instrument needs two exported numbers standing in a known ratio. Most
constants do not have one, and the honest-looking conclusion is that those
constants cannot be derived and the lift must guess or refuse.

## The instance

`unikraft/vmem` needed two constants and had no ratio for either.

`UK_PAGING_VADDR_ANY` is `0xBAADBAADBAADBAAD` aligned down to a page level that
varies by architecture and by whether the platform runs 4- or 5-level page
tables. Nothing exports it. But `uk_vma_map` **behaves differently** for it than
for anything else: hand it that value and the kernel runs first-fit and writes a
different address back; hand it any other valid address and the kernel honours
yours and writes the same value back; hand it a non-canonical address and the
call fails. Three outcomes, all distinguishable from the caller's side. So the
lift aligns the seed down by 2^12 through 2^47 in turn and keeps the candidate
that produced the first behaviour. It printed `0xbaadbaad80000000` on a real
kernel — the seed aligned to 1 GiB, a number the module never names.

The page size fell out of the same trick. `uk_vma_map` returns `-EINVAL` when the
length is not a whole number of pages and every other refusal has a different
code, so the smallest power of two it accepts *is* the page size.

## What follows

- **The instrument is the API's own acceptance behaviour.** If a function
  branches on a constant, the branch is observable, and an observable branch is a
  measurement. This works where no ratio exists and it works for values that are
  not numbers you could divide.
- **The success condition has to be a behaviour only the right answer produces.**
  That is what separates a derivation from a guess with a plausibility check
  bolted on. "First-fit ran" is such a condition; "the number looks like a page
  size" is not, and `unikraft/pages` needed both because its ratio could be
  computed from mismatched heaps.
- **A probe that mutates must restore.** Each candidate here is a real
  reservation in the kernel's live address space, and each one is unmapped before
  the next. A derivation that leaves residue is a derivation that changed the
  thing it measured.
- **Cost is the wrong objection.** Thirty-odd `uk_vma_map` calls sounds
  expensive until you notice it happens once, at the tor that hands out the
  handle, and that the alternative is a hardcoded constant that is wrong on some
  configuration nobody will test.
- **Say which constants you did NOT derive.** The same module hardcodes
  `PROT_READ` = 0x01 and `PROT_WRITE` = 0x02 because no ukvmem call branches on
  them observably — a wrong value there surfaces as a fatal page fault, not as a
  refusal. Deriving two of three and being loud about the third is honest;
  deriving two and letting the reader assume three is not.
