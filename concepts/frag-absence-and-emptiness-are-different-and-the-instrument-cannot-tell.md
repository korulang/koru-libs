---
type: belief
id: frag-absence-and-emptiness-are-different-and-the-instrument-cannot-tell
provenance: `grep -c . lib/ukfile/exportsyms.uk` returned 0 for a file that does not exist; read as "exports nothing", it is in fact the permissive case where everything exports
ts: 2026-08-06
---

# A missing thing and an empty thing measure identically, and their meanings are usually opposite (belief)

`grep -c . <file>` returns `0` when the file is empty **and** when the file does
not exist. `wc -l` the same. `ls | wc -l`, a glob that matches nothing, a config
key that was never set — the whole family of cheap counts collapses *absent* and
*empty* into one number, and then the number gets a meaning attached to it.

The meanings are rarely the same, and they are frequently **inverted**. An empty
allowlist admits nothing. A missing allowlist usually means the allowlist does not
apply, which admits everything.

## The instance

Unikraft gates which symbols a library exports with `exportsyms.uk` and
`objcopy --keep-global-symbols=<file>`. Counting those files produced a shelf of
liftable surface, and `ukfile` came out at **0** — read as "exports nothing,
unliftable", and written into a challenge brief as guidance.

`lib/ukfile/exportsyms.uk` does not exist. And the build does
`$(addprefix --keep-global-symbols=,$(EXPORTS))`
(`support/build/Makefile.rules:1043`) — `addprefix` over an empty list yields
**no flag at all**, so objcopy localizes nothing and every symbol the library
defines stays global. Twenty of Unikraft's libraries are in that state.

So the reading was not merely wrong, it was **the opposite of the truth**:
`ukfile` is the most permissive library on the shelf, not the most closed. The
real constraint on it is unrelated — 56 of its functions are `static inline` and
emit no symbol regardless, which is why it is *thin* rather than *closed*.

The error was made **while correcting a previous error** in the same table, which
is the part worth remembering: a correction pass runs on the same confidence that
produced the original.

## What follows

- **Before attaching meaning to a zero, establish which zero it is.** `test -f`
  costs nothing and separates the two cases the count cannot. Any predicate that
  returns 0 for "absent" needs that check before the number is used.
- **Find the consumer's default for the absent case; never assume it.** The
  question is not "what does an empty file mean" but "what does the code that
  reads this file do when it is not there." Here the answer was four tokens of
  `addprefix` in a makefile, and it inverted the conclusion.
- **Absence tends to mean *unrestricted*, presence tends to mean *restricted*.**
  A missing allowlist, a missing filter, a missing `depends_on`, a missing
  `.gitignore` — the common design is that the mechanism is off when unconfigured.
  That prior is worth holding, and worth checking anyway.
- **A correction is not automatically more careful than the thing it corrects.**
  This one shipped into a brief that a sealed contestant would have been steered
  by. Treat the second pass as a fresh claim requiring fresh evidence, not as
  cleanup.

## Resolved the same day: name the measurement in the row

The shelf table carried two different measurements in one column — an allowlist
length for libraries that have one, a defined-in-`.c` count for those that do not
— and that is exactly the ambiguity this belief is about, reproduced one level up
in the artifact written to warn about it.

The fix was not a footnote. A `gate` column now names which case each row is in
(`allowlist` / `open`), so the number cannot be read without reading what
produced it. **A number whose meaning varies by row needs the discriminator IN
the row, not in prose above the table** — prose above a table is not read by
someone scanning the table, which is the only way anyone reads a shelf.
