---
type: belief
id: frag-an-export-allowlist-is-curated-so-nothing-relates-it-to-the-code
provenance: `lib/uk9p/exportsyms.uk` lists 46 non-blank lines and yields 44 symbols (two names appear twice), and omits `uk_9preq_ready` — the only transition out of the state the exported `uk_9pdev_req_create` produces
ts: 2026-08-06
---

# An export allowlist is hand-curated, so no invariant connects it to the code it names (belief)

`exportsyms.uk` is consumed by `objcopy --keep-global-symbols`. objcopy is a
**filter**. A filter has no opinion about whether the set it filters against is
complete, minimal, or coherent — only whether a given symbol is in it. Nothing
in Unikraft's build ever asks "is this list right", because there is no
definition of right that a build could check.

The existing hazards recorded against this — a listed symbol that does not exist
(`uk_rwlock_upgrade`), and a listed symbol that is only a `static inline`
(`ukring`'s ten of twelve) — are both special cases of that, and both are about
**over-counting what links**. They share a shape: the list says more than the
code does.

The `uk9p` measurement found the list saying *less* than the code does, and
found it saying the *same thing twice*, and neither is visible to a check
designed for the other two.

## Two instances, one cause

**The list can repeat a name.** `uk_9pdev_set_msize` and `uk_9pdev_get_msize`
each appear at two separate lines of `lib/uk9p/exportsyms.uk`. 46 non-blank
lines; 44 distinct names. objcopy does not care — a repeated filter entry is a
filter entry — and nothing warns. So **a line count is not a symbol count**, and
the mistake is invisible to both the phantom check (the symbol exists) and the
inert check (it is not an inline). It inflates in the same direction as both.
Verified rather than argued, on the built object: `nm -g libuk9p.o` reports
exactly **44** `T` symbols, an exact set match with the de-duplicated list.

**The list is not closed under the state machine it exposes.** `uk9p` exports
`uk_9pdev_req_create`, which is the only producer of `UK_9PREQ_INITIALIZED`. It
does **not** export `uk_9preq_ready`, which is the only transition out of that
state — a real, non-`static`, externally-visible function in `9preq.c` that
`nm` shows as `t`, localized. Three others are in the same position
(`uk_9preq_init`, `uk_9pdev_req_to_freelist`, `uk_9pdev_fid_release`).

So the exported surface hands a caller a resource in a state the caller has no
exported way to leave. Not because anybody decided the low-level request API was
private — `uk_9pdev_req_create`, `uk_9pdev_req_lookup`, `uk_9pdev_req_remove`,
`uk_9preq_get`, `uk_9preq_put`, `uk_9preq_waitreply` and `uk_9preq_error` are
*all* on the list — but because the list was written by hand, one name at a
time, and one name was not written.

## What follows

- **Measure the allowlist against the object, not against itself.** `nm -g` on
  the built `.o` is the only statement anybody actually checked. It costs one
  command, it answers the repeat hazard, the phantom hazard and the inert hazard
  at once, and it is a stronger claim than any reading of the file.
- **Before committing to a level of the API, walk its state machine and ask
  whether every EDGE is reachable, not whether every NOUN is.** The nouns were
  all there. A lift designed from the exported noun list would have got as far as
  writing the serializers before discovering the transition was missing — and the
  serializers are the `##` token-pasted family, i.e. exactly the surface a
  name-based scan already files wrong. Two independent traps meeting on the same
  path.
- **An omission and a design boundary look identical from outside.** Nothing in
  the header, the Config, or the list distinguishes "this is internal" from
  "somebody forgot a line". Treat an unreachable edge as a fact about what you
  can build, and stop trying to infer intent from it.
- **This is the same disease as `frag-static-inline-is-not-the-linkability-
  discriminator`, one level up.** That belief says the keyword is not the
  verdict; this one says the *list* is not the verdict either. Neither artifact
  was ever derived from anything, so neither can be trusted as a derivation.
