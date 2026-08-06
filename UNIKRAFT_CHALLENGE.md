---
challenge: unikraft
kind: generator
status: standing
yields: one Unikraft sublibrary lifted into Koru behind phantom obligations, proven by a unikernel that boots
catalog: unikraft/*/index.kz
family: lift
created: 2026-08-06
---

# UNIKRAFT_CHALLENGE — lift the operating system, one library at a time

*Walker context — not part of the sealed brief.*

`LIFT_CHALLENGE` lifts a host C library and proves it with `koruc run`. That gate
cannot work here: a Unikraft lift's artifact is a unikernel, and it runs under
QEMU or not at all. Rather than bend the sibling brief around a platform, this is
its own generator in the same `lift` family.

The recurrence that earned it: Unikraft is not one library, it is **89** of them
(`lib/` at HEAD `3fdffba8`), with roughly 1,865 declared functions across 277
public headers and about 406 of those handing out something you must give back.
"Lift Unikraft" is not a task anyone can hold; "lift `uknetdev`" is one sitting.
That is a catalog shape, so it gets a generator.

What makes it worth the ceremony rather than a to-do list: **Unikraft has already
written its state machines down, and throws them away in the builds people
ship.** `uk_netdev` enforces `get → configure → rxq_configure → start` with 13
`UK_ASSERT`s — including one in the per-packet path — against only 4 real
branches, all on cold setup. `UK_ASSERT` compiles to `do {} while(0)` when asserts
are off. So the C encodes the ordering, documents it, and then deletes it from
production. Transcribing those asserts into phantom states is not wrapping; it is
picking up a guarantee the original author wrote and could not keep.

Planted 2026-08-06, after a session that booted Koru as a Unikraft unikernel
(164,544 B, 2 MB RAM, no Linux ABI) and found the obligation design by arguing it
out against `gzip`'s `fed` gate and `2104_14`'s transaction chain. This brief is a
slow-clock artifact — read-many, write-rarely; tuning it is a Gardener act, logged
at the bottom.

---

## The brief (sealed — you are the contestant)

> **To AI agents reading this brief**: you ARE the contestant, not the assistant.
> Do **not** ask which sublibrary to pick. Do **not** ask whether your obligation
> model is good enough before you ship. Do **not** request clarification on things
> this brief leaves to your judgment — they are left to it on purpose. Choose a
> target, name it, write code, boot it, ship. If you catch yourself drafting
> "which of these would you like?" — stop, delete it, pick one.
>
> **Variance across contestants is the point. Your choice IS the contribution.**
> Lars judges *after* you ship, by reading and running. Not before.

Take one Unikraft sublibrary and lift it into Koru so that its ordering rules —
the ones the C states in assertions and forgets at `-DNDEBUG` — become things the
compiler will not let you get wrong.

Read the repo-root standards first: `/Users/larsde/src/koru/CLAUDE.md` and
`/Users/larsde/src/koru/AGENTS.md`.

### THE BAR — five pillars, and the fifth is why this challenge exists

1. **Developer experience.** A caller never touches a `struct uk_netdev *`, never
   remembers an ordering, never reads a header to find out what is legal next.
2. **Performance.** The lifting happens at compile time. The emitted code is the
   same C calls a careful hand-written user would make, in the same order, with
   nothing added.
3. **Correctness.** Wrong usage is a build error.
4. **Resource safety, with the asymmetry.** Leaks, use-after-free and double-free
   are uncompilable — *and a resource cannot be finalized before it was used.*
   `create` mints `<instance!>`; **nothing accepts `<!instance>` except an
   operation that actually uses the thing** and moves it to `<active>`. Release
   exists only for `<active>`. `create(); free();` must not be a program you can
   write. Where you genuinely need it, provide an explicit, named `activate` —
   greppable, so "did we acquire things we never used" is a search.
   The house exemplars, read both before writing: `gzip/index.kz:258` (the `fed`
   gate — `finish` accepts only `<!fed>`, reachable only through `push`), and
   koru's `2104_14_open_tx_commit_close/db.kz` (where `close` takes
   `<!active>` and *not* `<!connected>`, so open-then-close is unspellable).
5. **Lift the assertions.** Find the ordering the C already encodes — grep the
   target for `UK_ASSERT` and for real `if (… state …)` branches — and make each
   one a phantom state instead. **Name in your writeup which assertions your lift
   makes unnecessary, and which you could not.** A lift that adds a wrapper
   without removing a runtime check has not done this challenge's job.

An entry that buys one pillar by sacrificing another does not ship. Refusing that
trade is the whole craft.

### Modelling rules, learned the hard way

- **Bind at the NATIVE altitude, not the POSIX emulation.** `posix-socket` is 35
  functions of emulation over lwIP over `uknetdev`, and it is measured expensive:
  `write` links only once `LIBPOSIX_FDIO` + `LIBPOSIX_FD` + `LIBPOSIX_TTY` +
  `LIBUKFS_DEVFS` are configured in, costs 12,544 image bytes, and **still traps
  at boot** because nothing has opened fd 1. The native layer is smaller, has the
  state machine exposed, and is the thing worth proving about.
- **A failure arm hands the handle back in a NEW state when the failure changes
  what is legal next.** `| invalid { handle: *Handle<invalid!>, errno: i32 }`,
  where the only tor accepting `<!invalid>` is the correct recovery. The payoff is
  not cleanup, it is that the wrong continuation becomes unreachable.
- **State answers "what may I do now." Payload answers "what happened."** Errno
  and message ride as branch payload — never as a type parameter. A thousand error
  messages must not become a thousand types. Split into separate arms only when
  the **recovery** diverges, never when the message does.
- **Not everything deserves a ratchet.** `ukalloc` is a genuinely symmetric
  alloc/free pair. Forcing multi-state ceremony where no ordering constraint
  exists is feature-maximalism wearing a safety badge. Apply pillar 4's asymmetry
  where the C has an ordering rule; say plainly in your writeup where you decided
  it did not.
- **Obligation-on-failure scales inversely with resource frequency.** A device is
  rare and long-lived: a failed `configure` should hand back an obligation. A
  packet is hot and numerous: a failure there should probably *consume*, or every
  dropped packet grows ceremony on the per-packet path. If your target has both,
  say which line you drew and why.

### Duplicate prevention & variance

**Step one, before you read anything else in this section: list `unikraft/` and
read the SHIPPED CATALOG below.** Every entry there is a slot that is closed.
Read those modules' READMEs and their tests — they are the house style, and they
are also the list of things you may not bring again.

#### Shipped catalog

One line per landed lift. **Append yours when you ship** — that is how the next
contestant knows the slot is gone.

- **[blk](unikraft/blk/README.md)** — `ukblkdev` behind an 8-state ratchet, 11
  tors. Lifecycle *and* transfers proven: a booted image reads a host-planted
  sector and writes one back, verified with `dd` on the host disk afterwards.
  The reference for how far a ratchet is worth taking.
- **[alloc](unikraft/alloc/README.md)** — `ukalloc`'s object allocator behind two
  states, 10 tors, no struct mirror. A MERGE of three independent replays rather
  than a pick of one, with each piece attributed. Strict `free` plus the named
  escape `alloc:untouched`; `take.aligned` boots a 4096-aligned buffer with the
  block header in front of it. The reference for how far restraint is worth
  taking, and for auditing an assert census instead of banking it — 19 of 38
  retired, 19 not, per site.
- **[pages](unikraft/pages/README.md)** — `uk_palloc`/`uk_pfree` behind two
  states, 7 tors, and a `struct uk_alloc` mirror PROVEN at run time against six
  exported symbol addresses before it is used. The catalog's stated
  second-module exception, exercised. Its contribution is not a lifted assertion
  — the page interface has none a caller can violate — but the `num_pages`
  parameter that no longer exists.
- **[lock](unikraft/lock/README.md)** — `uklock`'s READER-WRITER lock behind four
  states, 7 tors, and a `struct uk_rwlock` whose SIZE IS MEASURED on the running
  image rather than transcribed. Two contributions. (1) The linkability verdict:
  15 allowlist lines are 5 usable functions — 2 of the 15 exist nowhere in the
  tree, and the mutex and semaphore export their constructors while leaving every
  verb `static inline`, so they are refused with reasons rather than half-lifted.
  (2) A mirrored `sizeof` was written, booted and was WRONG by 24 bytes —
  `__spinlock` is size ZERO without `CONFIG_HAVE_SMP` — which is why the size is
  now derived by canary probe. Retires the runlock/wunlock assertion pair, and
  forgetting to unlock is a compile ERROR rather than an insertion.

#### The rule that keeps the catalog from turning into an argument

**One module per sublibrary.** A replay CLAIMS a sublibrary; the catalog holds one
`unikraft/<name>/` per C library, not rival readings of the same one. So:

- **If the slot is taken, take a different sublibrary.** Not a different opinion
  about a taken one.
- **If you believe a shipped lift is WRONG**, that is a real and welcome finding —
  but the contribution is a *revision to that module*, argued in its own README
  and its own tests, never a second module for the same library. Say so plainly
  in your writeup and change the existing one.
- **A second module is legitimate only when it lifts a genuinely different C
  API.** `uk_palloc`/`uk_pfree` is a different API from `uk_malloc`/`uk_free` — a
  different unit and a different allocator entry point — so `unikraft/pages`
  beside `unikraft/alloc` is right, while a second `unikraft/alloc` is not.
  `unikraft/blk` sits beside `unikraft/index.kz` today; nesting is the convention.

Worked example of the trap, because "bring something different" is easy to read
too narrowly: `ukblkdev` is shipped. Do **not** lift `ukblkdev` again with a
different state count, and do not reach for a target *because* it also has a
queue and a device lifecycle — that is the same contribution wearing another
library's name. Take something with a different SHAPE: threads and ordering
(`uksched`), address mappings (`ukvmem`), acquire/release on every path
(`uklock`).

**Variance across contestants is the single most important measure of success**,
and variance means a different organ of the OS, not a different opinion about one.

Why this is spelled out at this length: on 2026-08-06 three contestants were
handed the SAME sublibrary deliberately, to test whether the restraint rule below
reads as clearly as the asymmetry rule. It does — all three refused to ratchet a
symmetric pair. But it produced three rival interfaces for one slot, and choosing
between them turned out to be mostly a false question: two of the three
differences had a right answer, and the third dissolved once it was noticed that
a strict design plus a named escape hatch already contains the permissive one.
Rival whole-APIs export our indecision to users. The catalog grows by breadth.

**Check linkability BEFORE you fall in love with a target**, and check it the way
the LINKER does, not the way a header reads. A Koru lift compiles to a
*separately linked* freestanding archive, so it can only call symbols that exist.
Three cases, and they are not obvious:

1. **`lib/<name>/exportsyms.uk` exists** → that file IS the allowlist. Unikraft
   runs `objcopy --keep-global-symbols=<that file>` and localizes everything
   else. Only the listed symbols link.
2. **`exportsyms.uk` is absent** → `addprefix` over an empty list yields no flag
   at all (`support/build/Makefile.rules:1043`), objcopy localizes *nothing*, and
   **everything the library defines links.** Twenty libraries are in this state.
   An absent allowlist is the permissive case, not the empty one — do not read a
   missing file as "exports nothing."
3. **`static inline` in a header** → no symbol is emitted either way. Reaching it
   needs a C shim (an added call frame, against pillar 2) or a hand-mirrored
   struct (an ABI guess). This is independent of cases 1 and 2.

Measured shelf (`unikraft` HEAD `3fdffba8`). **`gate` says which of the three
cases the library is in, and therefore what `linkable` counted** — an allowlist's
length, or the functions the library defines. The two are not the same
measurement and the column would lie if it did not say so:

| C library | gate | linkable | `static inline` | Koru module | shape |
|---|---|---:|---:|---|---|
| `uksched` | allowlist | 42 | 27 | `unikraft/sched` | threads; ordering + lifetime |
| `uknetdev` | allowlist | 33 | 12 | `unikraft/net` | state machine — **but see below** |
| `ukalloc` | allowlist | 25 | 25 | `unikraft/alloc` + `unikraft/pages` | **TAKEN** — three replays landed rival readings and the merge shipped as TWO modules: bytes in `unikraft/alloc`, pages in `unikraft/pages`. Read both. Its lesson is recorded under Duplicate prevention. |
| `ukvmem` | allowlist | 20 | 16 | `unikraft/vmem` | mappings |
| `ukblkdev` | allowlist | 18 | 5 | `unikraft/blk` | **TAKEN** — the first lift; read it before you start |
| `uklock` | allowlist | 15 | 19 | `unikraft/lock` | **TAKEN** — the rwlock, and read its linkability section before trusting any `linkable` count: 2 of those 15 allowlist lines name symbols that exist NOWHERE in the tree, and the mutex/semaphore halves export constructors with every verb `static inline`. 5 functions are usable. |
| `ukfile` | **open** | 10 | 56 | `unikraft/file` | no allowlist, so all 10 link — but they are `nop`/`pollq` helpers and the real surface IS the inlines. Thin. |

`gate: open` means no `exportsyms.uk`, so everything the library defines is
linkable — the permissive case, not the empty one. Twenty of Unikraft's libraries
are `open`; only the seven above were measured, so if you want a target outside
this table, run the three-case check yourself rather than assuming.

**`uknetdev` is a trap, and it cost the first replay an investigation to find.**
Its lifecycle is exported, but its *hot path* is not: `uk_netdev_rx_one` and
`uk_netdev_tx_one` are `static inline` (`netdev.h:476`, `:546`). So the per-packet
half — the interesting half, the one with the refcounted netbufs — cannot be
reached from a Koru archive without a shim or an ABI guess. Lift its lifecycle if
you want; do not promise the transfers.

`ukblkdev` is what `uknetdev` looked like from a distance: the same explicit state
machine and nested queue sub-resource, and it exports its **whole** surface
including `uk_blkdev_queue_submit_one` and `uk_blkdev_queue_finish_reqs`, so the
lifecycle *and* the transfers are provable end to end. It is already taken. The
shelf above is what remains.

### What "done" looks like (the gates)

1. `koruc --check unikraft/<name>/index.kz` passes.
2. **A unikernel built from your lift boots under QEMU and prints.** Not
   `--check`, not a host build — the real boundary. The recipe, the exact
   commands, and the traps are in `/Users/larsde/src/koru/examples/unikraft/BUILD.md`.
   Paste the real console output in your writeup.
3. At least one **negative test**: a misuse that FAILS TO COMPILE — an
   out-of-order call, a use-after-release, or a resource finalized before it was
   ever used. Prove it through the **full pipeline**, never `--check`:
   phantom-obligation validation fires in the emit pass. An uncompilable footgun
   you cannot demonstrate is a claim, not a lift.
4. No silent fallbacks. Failures fail loudly with the real error.
5. The writeup is filed, including which `UK_ASSERT`s your lift makes unnecessary.
6. Lars reads it and the verdict is "yes — that's the definitive edition."

Gates 1–5 you self-check. Gate 6 is not yours.

### Four traps that will each cost you an hour

Measured 2026-08-05; all four are in `BUILD.md` with the evidence:

- **`kraft build` blocks forever** on `project already configured, are you sure
  you want to rerun the configure step [Y/n]`. Pass `--no-prompt`. Without it a
  15-second build looks like a 40-minute one.
- **`UK_CFLAGS="-std=gnu17"` is required.** GCC 16 defaults to `gnu23`, where
  Unikraft's own `lib/ukboot/boot.c:489` is a hard error.
- **`.config.<name>` survives `rm -rf .unikraft/build`.** Delete it too, or a
  stale Kconfig silently drives your next build.
- **A killed build leaves zero-byte `.ld.o` files** that then fail forever as
  `input file is empty`. Looks like a toolchain bug; is not.

And two that are ours, not Unikraft's.

**Koru's print puts a 65,536-byte buffer on the stack**, which is exactly
Unikraft's default 64 KB boot stack (`STACK_SIZE_PAGE_ORDER=4`).
`koru/unikraft:kconfig` emits order 6 for you; if you hand-roll a Kraftfile,
carry it.

**Every entry file you write declares the `unikraft` namespace in its own
source.** The shipped lifts all carry it, so copy the block from any of their
tests:

```
~std/compiler:paths {
    unikraft: {{ ENTRY }}/../..
}
```

That resolves the namespace to the tree the file is *in*. Without it the alias
falls through to koruc's built-in default, which probes
`{{ KORU_HOME }}/koru-libs/unikraft` and `{{ KORU_HOME }}/../koru-libs/unikraft`
(`koru/src/config.zig:242-247`) — the **main checkout**, never your worktree.
Since you work in a worktree, that is always the wrong tree. Both failure modes
were measured 2026-08-06, in a real worktree:

- A **new** module — your lift — fails as `KORU002 module not found:
  'unikraft/<yours>'`. Loud, but loud in the wrong place: on the `ukalloc` wave
  it made a contestant's gate-3 negatives refuse for the wrong reason, and a
  `KORU002` where you expected a `KORU030` reads exactly like "the obligation
  wall does not work."
- An **existing** module — a lift you are revising — is worse: it resolves
  *silently* to main's copy. Measured by breaking a local
  `unikraft/pages/index.kz` on purpose: with the declaration the compiler cites
  **your** file and refuses; without it that same broken file passes `--check`,
  because your edit was never read. You would be testing main and believing you
  tested yourself.

So: if `--check` disagrees with the file in front of you, find out which file
koruc actually opened before you believe either of them.

### If the toolchain rejects your clean code — STOP, report, never route around

Both Koru and this shelf are greenfield. If code you believe is idiomatic is
rejected, or compiles to broken output, do NOT contort the lift to satisfy the
compiler. Pin a minimal repro, name it in your writeup, ship what you can ship
honestly with the gap stated. A toolchain defect surfaced by honest library code
is worth more than a package that hides one.

And **verify before you attribute.** A reproducible failure localises the
*symptom*; the component the error appears in is not evidence about the component
at fault. Before naming a culprit, run the same shape through a path known to
work — that control costs under a minute and it is the step that gets skipped.
(Earned expensively: see
`/Users/larsde/src/koru/concepts/frag-a-reproducible-failure-localises-the-symptom-not-the-defect.md`.)

### Claims you may not make

- **No boot-time numbers.** Everything measured so far is QEMU TCG on arm64 with
  no KVM. There is no boot-time claim in this project and you may not create one.
- **No "faster than C".** The per-packet state check is a `UK_ASSERT` and already
  compiles out in release. The honest claim is that Koru *dissolves* Unikraft's
  asserts-on/asserts-off tradeoff — assert-on guarantees at assert-off cost — and
  it needs a three-way benchmark (asserts-on C, asserts-off C, proven Koru) that
  does not exist yet. Do not assert it; you may *demonstrate* it if you build the
  benchmark.

### The toolkit

| You need | Where |
|---|---|
| The compiler | `/Users/larsde/src/koru/zig-out/bin/koruc` |
| The language's law | `/Users/larsde/src/koru/tests/` — passing tests only, never docs |
| Repo standards | `/Users/larsde/src/koru/CLAUDE.md`, `AGENTS.md` |
| Build recipe + traps | `/Users/larsde/src/koru/examples/unikraft/BUILD.md` |
| Unikraft source | `/Users/larsde/src/unikraft` (our fork, `upstream` wired) |
| Asymmetry exemplars | `gzip/index.kz:258`, koru `2104_14_open_tx_commit_close/db.kz` |
| Obligation house style | `sqlite3/index.kz`, `sqlite3/README.md` |
| Image manifests | `koru/unikraft:image` / `:kconfig` — generated, do not hand-write |

### Go (no permission required)

1. Read the standards, then `BUILD.md`.
2. Read `gzip/index.kz:258` and `2104_14/db.kz` — the asymmetry, twice.
3. **List `unikraft/*/` and read the Shipped catalog section.** Those slots are
   closed. If you think one of them is wrong, revise THAT module — do not open a
   second one for the same C library.
4. Claim an unclaimed sublibrary from the shelf. Grep it for `UK_ASSERT` and real
   state branches before you design anything — that grep IS the state machine.
5. Build. Ground every Koru construct in a passing test.
6. Boot it. Run the gates. Write the writeup. Stop — do not start a second.

---

**Catalog upkeep**: a shipped lift is a directory under `unikraft/<name>/`
with `index.kz`, `tests/`, and `README.md`. The catalog is the repo — AND you add
your one-line entry to the **Shipped catalog** section above, pointing at your
README. A landed module that is not in that list is a slot the next contestant
cannot see is closed, which is how one library ends up lifted twice.

## Tending log

- 2026-08-06 — closed the worktree-alias hole, which had been costing replays
  without ever being written down. All 16 test entry files across `alloc`,
  `blk` and `pages` now declare `unikraft: {{ ENTRY }}/../..` in their own
  source via `std/compiler:paths`, and the brief requires it of every new entry
  file. **`koru.json` is retired** (Lars, this session) — the first version of
  this fix put the alias in the repo-root `koru.json`, which worked and was the
  wrong shape; an alias belongs in the program that needs it. Both failure modes
  were measured in a real worktree rather than asserted: a NEW module fails
  `KORU002` — which on the `ukalloc` wave made gate-3 negatives refuse for the
  wrong reason and read like a broken obligation wall — and an EXISTING module
  resolves **silently** to the main checkout, so the revision you are testing is
  not the file you are editing. The second half was previously unrecorded and is
  the dangerous one. Earned by a replay reporting it as "a real toolchain issue"
  and it being fixed nowhere; a trap known to three sessions and no file is not
  known. — walk Three things
  changed. (1) An in-file **Shipped catalog** section, one line per landed lift,
  which every replay appends to — previously the catalog was only discoverable by
  listing directories, so "is this slot taken" cost a filesystem read the brief
  never told anyone to do. (2) **One module per sublibrary**, stated outright,
  with the escape named: a shipped lift you think is wrong gets REVISED, and a
  second module is legitimate only for a genuinely different C API
  (`uk_palloc` vs `uk_malloc`). (3) A worked negative example, because "bring
  something different" reads too narrowly — the trap is taking a target *because*
  it also has a queue and a device lifecycle, which is the same contribution
  wearing another name.

  Earned the expensive way. The `ukalloc` wave was dispatched with ONE target
  handed to three contestants, deliberately, to test whether the restraint rule
  reads as clearly as the asymmetry rule. That experiment succeeded — 3/3 refused
  to ratchet a symmetric pair, and each named its refusals — but it also produced
  three rival interfaces for one slot, which the brief had no rule for because the
  generator was never meant to be dispatched that way. **The collision was the
  dispatch's fault, not the brief's**; the dedup step would have sent three
  contestants to three sublibraries. What the brief genuinely lacked was any
  statement of what to do when a target admits rival readings, and that gap is now
  closed rather than left for the next wave to re-fight.

  Arbiter-side, and deliberately NOT in the sealed brief because it is process:
  when running a wave, either let each contestant pick from the shelf (the synth
  shape, and the default) or assign DISTINCT sublibraries. Handing one target to
  several contestants is a legitimate instrument for testing whether a RULE in the
  brief reads clearly — it is the only way to get a sample — but it buys a
  methodology answer at the price of catalog growth, and the resulting entries
  compete rather than accumulate. Spend it knowingly, and say up front that at
  most one of the outputs can land. — walk
- 2026-08-06 — first replay landed `unikraft/blk` and corrected the shelf: the
  column was header DECLARATIONS, not linkable symbols. `ukfile` showed as the
  second-richest target; correcting THAT introduced a second error (a missing
  exportsyms.uk is the PERMISSIVE case — everything links — not the empty one),
  caught by Lars asking why anything would be unliftable. `uknetdev`, named the exemplar, has
  a `static inline` hot path. Added the linkability rule and the exports column.
  Tuning earned by a replay, which is what a first replay is for. — walk
- 2026-08-06 — planted. Split from `LIFT_CHALLENGE` because gate 2 (`koruc run`)
  cannot prove a unikernel, and because Unikraft's unit is a sublibrary, not a
  library. Carries the obligation-asymmetry rule, the `invalid!` shape, and the
  four build traps from the session that first booted Koru on Unikraft.
