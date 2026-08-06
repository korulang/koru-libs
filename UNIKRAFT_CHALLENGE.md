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

The recurrence that earned it: Unikraft is not one library, it is **87** of them
(`lib/` at HEAD `3fdffba8` holds 87 directories; the "89" first written here
counted `Config.uk` and `Makefile.uk` as libraries), with roughly 1,865 declared
functions across 277 public headers and about 406 of those handing out something
you must give back.
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

**The one exception, and it is a shipping lane, not a lower bar.** Where the open
question about a target is *reachability* — can this thing be linked, mirrored and
booted from Koru at all — you may ship a **naive wrap** that answers exactly that
and stops. It unblocks the target for everyone. Two conditions, both hard:

1. **Say it is one, in the first paragraph of your README and in your catalog
   line.** A naive wrap that reads like a finished lift is the thing this whole
   brief exists to prevent.
2. **Claim nothing you did not earn.** If you retired no assertions, the census
   says so and reports zero. An honest zero is a fine result; a padded one poisons
   the catalog.

The idiomatic pass is then a *later replay that revises that module in place* —
which the one-module-per-sublibrary rule below already provides for. Ruled by Lars
2026-08-06: wrap naively, get unblocked, rub the Koru idioms on it afterwards.

An entry that buys one pillar by sacrificing another does not ship. Refusing that
trade is the whole craft.

### Modelling rules, learned the hard way

- **Bind at the NATIVE altitude, not the POSIX emulation.** `posix-socket` is a
  layer of emulation over lwIP over `uknetdev` — 27 allowlist lines of which 25
  link (two are phantoms) plus 29 `static inline`s, re-measured 2026-08-06; the
  "35 functions" once written here was a header declaration count. It is measured
  expensive:
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

**Later entries SUPERSEDE earlier ones where they disagree, and the catalog is
read newest-first for method.** This is not a menu of equally-valid house styles.
Earned the expensive way: the mirror lesson — that `@offsetOf` assertions prove a
transcription agrees with itself and say nothing about the C — was stated in
`blk`'s README and acted on by `pages`, and a third lift still repeated it,
because two entries describing different approaches read as a choice rather than
as one correcting the other. If your reading contradicts a shipped entry, you are
either superseding it (say so in your README, in a line naming the entry) or you
have missed why it did what it did.

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
- **[sched](unikraft/sched/README.md)** — `uksched`'s thread lifetime behind six
  states and 13 tors, with the asymmetry gate placed on *being scheduled*:
  `terminate` accepts only `<!ran>`, and `<ran!>` is minted on EVIDENCE — the
  entry shim raises a flag — rather than inferred from a yield. 22 of 112
  `UK_ASSERT`s retired, per site, including the two guarding a re-primed live
  thread and the one guarding a thread freed while the scheduler still holds it.
  Its `struct uk_sched` mirror is proven **structurally**, by walking the
  scheduler's own roster and finding the running thread on it, because every
  candidate witness symbol in `ukschedcoop` is a file static. Deliberately does
  not bind the fused `uk_sched_thread_create_fn*`: it would collapse three of
  the ordering rules the lift exists to lift.
- **[vmem](unikraft/vmem/README.md)** — `ukvmem` behind a 5-state ratchet, 12
  tors. Its two headline rules have NO assertion and their penalty is a dead
  machine: touching a reservation (`uk_vma_rsvd_ops.fault == NULL`) and writing
  through a read-only mapping both end in an unresolvable page fault, in debug
  and release alike. Both are phantom states with a negative test. Pillar 4
  applied to the committed half and REFUSED on the reservation half, which costs
  no memory. Two kernel constants no symbol exports — the page size and
  `UK_PAGING_VADDR_ANY` — are DERIVED BY BEHAVIOURAL PROBE rather than assumed;
  the console prints `0xbaadbaad80000000`. Census 20 retired / 16 not, per site.
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
Five cases, and they are not obvious:

1. **`lib/<name>/exportsyms.uk` exists** → that file IS the allowlist. Unikraft
   runs `objcopy --keep-global-symbols=<that file>` and localizes everything
   else. Only the listed symbols link.
2. **`exportsyms.uk` is absent** → `addprefix` over an empty list yields no flag
   at all (`support/build/Makefile.rules:1043`), objcopy localizes *nothing*, and
   **everything the library defines links.** Twenty libraries are in this state.
   An absent allowlist is the permissive case, not the empty one — do not read a
   missing file as "exports nothing."
3. **`static inline` in a header** → no symbol is emitted either way, **but the
   keyword is not the verdict.** Ask what the inline *closes over*, and there are
   **three** answers, not two:
   - **FREE** — it closes over nothing but exported symbols. Four of `ukvmem`'s
     five are `return uk_vma_map(…, &uk_vma_<kind>_ops, …)`: an exported function
     plus an exported data symbol. Emit the same call with the same arguments —
     no shim, no added frame, no ABI guess.
   - **MIRROR** — it reads or calls through **struct fields**. That is an offset
     question, not a linkability one, and three shipped lifts have already paid
     it and proved it (`pages` against six exported symbol addresses, `sched` by
     walking the roster, `lock` by canary probe). Costs a transcription and a
     proof; costs no shim and no new symbol. An **indirect call through a
     function-pointer field is in this bucket** — `dev->rx_one(…)` needs an
     offset, not a symbol.
   - **NO** — it closes over something that has no symbol *and* no offset: a
     Kconfig integer (`uk_vma_map_stack` sums
     `CONFIG_LIBUKVMEM_STACK_GUARD_PAGES_TOP/_BOTTOM`), a `static` in another
     compilation unit, or inline assembly (`ukpaging`'s `pt_read_base`,
     `pt_write_base`, `pte_write` are `mov`s to control registers — there is
     nothing to call, only something to re-emit).
   **Measure the body that survives your build, not the body in the file.** Every
   shipped lift sets `CONFIG_LIBUKDEBUG_ENABLE_ASSERT: 'n'`, so `UK_ASSERT` is
   `do {} while(0)` and whatever it names is not a dependency of your emitted
   code. Reading `uk_netdev_rx_one`'s asserts as dependencies is exactly how it
   got written off — see the `uknetdev` note below.
4. **A listed symbol may not exist.** `exportsyms.uk` is an allowlist consumed by
   `objcopy --keep-global-symbols`, which is a **filter** — naming a symbol that
   was never declared or defined is not an error and nothing warns. `uklock`
   lists `uk_rwlock_upgrade` and `uk_rwlock_downgrade`; the only occurrences of
   either name in the whole tree are those two lines. Grep for a definition
   before you count a symbol as surface. Measured 2026-08-06: **19 such lines
   across 8 libraries**, including two in a TAKEN slot each (`ukalloc`'s
   `uk_palloc_compat`/`uk_pfree_compat`, `uksched`'s `uk_sched_create`). Beware
   the inverse false positive: `ubsan`'s 34 handlers and `ukstore`'s two event
   symbols are built by `##` token-pasting and never appear literally — a name
   with no textual hit is a *candidate*, and you confirm it by checking the
   library for token pasting.
5. **A listed symbol may exist only as a `static inline`** — and then the
   allowlist line is **inert**, because the compilation unit emits no global for
   it and objcopy has nothing to keep. This is case 3 and case 4 colliding, and
   it is the one that most inflates a `linkable` count. **29 lines across 4
   libraries** are in this state. `ukring` is the extreme: 12 allowlist lines,
   **10 of them `static inline`**, so exactly `uk_ring_alloc` and `uk_ring_free`
   link and the entire ring API is offsets. `uklcpu` lists 29 and 16 are inert.
   `uknetdev` lists `uk_netdev_rxq_intr_enable`/`_disable`, both `static inline`
   at `netdev.h:395`.

### Measured shelf

Re-measured 2026-08-06 against `unikraft` HEAD **`3fdffba8`** (the fork), by
script over all **87** `lib/` directories — the previous table's `3fdffba8` was
correct but its `static inline` column was a raw `grep` and its `linkable` column
was an unfiltered line count. Both are replaced.

**What the columns are, because two of them used to lie:**

- **gate** — case 1 (`allowlist`) or case 2 (`open`).
- **allowlist** — lines in `exportsyms.uk`. Not a linkable count.
- **phantom** — case 4: allowlist lines with no definition anywhere in the tree.
- **inert** — case 5: allowlist lines whose only definition is a `static inline`.
- **links** — what you can actually call. For `allowlist`: allowlist − phantom −
  inert. For `open`: the non-`static` function definitions in the library's `.c`
  files, which is a *different measurement of a different thing* and is why the
  gate column exists.
- **inline F/M/A/N** — public-header `static inline`s split by case 3, against
  the asserts-off body: **F**ree, **M**irror, **A**sm, **N**o.
- **`UK_ASSERT`** — occurrences in the library's own `.c` and `.h`. The grep that
  IS the state machine; a high number is a promise of work, not of quality.
- **0.21.0** — whether the library exists in Unikraft `stable` 0.21.0 "Ijiraq".
  **Your `Kraftfile` says `version: stable` and builds against 0.21.0, not
  against this fork.** For every library below except `ukvsockdev` the two trees
  agree; where they do not, a lift that compiles against the fork will not link
  in the image. The only other drift measured: `ukconsole` has 17 allowlist lines
  in the fork and 7 in 0.21.0 (`uk_console_unregister` and the whole async
  callback family are fork-only), and `ukprint` 11 against 8. `ukfile-console`
  is likewise fork-only.

| C library | gate | allowlist | phantom | inert | **links** | inline F/M/A/N | `UK_ASSERT` | 0.21.0 | shape |
|---|---|---:|---:|---:|---:|---|---:|---|---|
| `uksched` | allowlist | 42 | 1 | 0 | **41** | 4F/22M/1N | 112 | yes | **TAKEN** (`unikraft/sched`) — threads; ordering + lifetime. The scheduler pointer itself is case 3 (`uk_sched_current`/`uk_thread_current` are both `static inline`) and every `struct uk_sched` callback is a `ukschedcoop` file static, so an address-witness proof is not available; the lift proves its mirror by walking the roster instead. **Corrected:** `uk_sched_create` is a phantom — 41, not 42. |
| `ukalloc` | allowlist | 25 | 2 | 0 | **23** | 1F/24M | 45 | yes | **TAKEN** (`unikraft/alloc` + `unikraft/pages`) — three replays landed rival readings and the merge shipped as TWO modules: bytes in `unikraft/alloc`, pages in `unikraft/pages`. Read both. **Corrected:** `uk_palloc_compat` and `uk_pfree_compat` are phantoms — 23, not 25. |
| `ukvmem` | allowlist | 20 | 0 | 0 | **20** | 4F/7M/1N | 128 | yes | **TAKEN** (`unikraft/vmem`) — mappings. The split that corrected this whole rule: the four `uk_vma_reserve*`/`map_anon`/`map_dma` inlines are FREE, and `uk_vma_map_stack` alone is NO, on two Kconfig guard-page integers. |
| `ukblkdev` | allowlist | 18 | 0 | 0 | **18** | 5M | 105 | yes | **TAKEN** (`unikraft/blk`) — the first lift; read it before you start. |
| `uklock` | allowlist | 15 | 2 | 0 | **13** | 13M/3A/1N | 30 | yes | **TAKEN** (`unikraft/lock`) — the rwlock. 13 link, but only **5** are rwlock verbs a lift can use: the mutex and semaphore halves export constructors and leave every verb `static inline`. The 3 A are the arm64 ticketlock (`ldaxr`/`stlxr`). |
| `uknetdev` | allowlist | 33 | 0 | 2 | **31** | 12M | 170 | yes | **OPEN, and newly so — see below.** Highest assert count in the tree. Every one of its 12 inlines is MIRROR; **none is NO**. |
| `ukstore` | allowlist | 39 | 0 | 0 | **39** | — | 28 | yes | Refcounted object registry: `obj_alloc → _obj_add → acquire ⇄ release`, plus an 11-type × 3-verb typed getter/setter matrix that is a comptime-codegen exercise rather than a wrapper. **Zero inlines** — the whole surface links. Nothing shipped has this shape. |
| `ukvsockdev` | allowlist | 21 | 0 | 0 | **21** | 7M | 39 | **no** | Device lifecycle *and* a per-connection lifecycle (`conn_request → conn_response → conn_shutdown`/`conn_reset`) *and* a buffer (`init → append → read → destroy`). Excellent shape — **and it does not exist in 0.21.0.** You cannot boot it with `version: stable`. Do not claim this slot without first proving you can build against the fork. |
| `uk9p` | allowlist | 46 | 0 | 0 | **46** | 14M | 21 | yes | Three nested resources with an explicit state enum each: device (`UK_9PDEV_CONNECTED`/`DISCONNECTING`), request (`UK_9PREQ_INITIALIZED → READY → SENT → RECEIVED`), and refcounted fids (`uk_9pfid_get`/`put`). `uk_9pdev_request` asserts `dev->state == UK_9PDEV_CONNECTED` at `9pdev.c:265`. The richest unclaimed ordering in the tree. |
| `ukpaging` | allowlist | 15 | 0 | 0 | **15** | 8F/3A | 140 | yes | `pt_init → pt_set_active → page_map/page_unmap → pt_free`, plus the `page_kmap`/`page_kunmap` pair. Second-highest assert count. The 3 A are control-register reads; the other 8 inlines are pure arithmetic and free. |
| `ukconsole` | allowlist | 17 | 0 | 0 | **17** | 2M | 26 | **partly** | `register → out/in → unregister` plus async callback register/unregister. **10 of the 17 are fork-only**; against 0.21.0 this is a 7-symbol library with no `unregister`, which deletes the asymmetry that makes it interesting. |
| `uklcpu` | allowlist | 29 | 0 | 16 | **13** | 20F/12M/3N | 25 | yes | SMP + interrupt-flag primitives. The `save_irqf`/`restore_irqf` pair is a real nesting discipline, but it is one of the 16 **inert** lines, and most of the rest is `cli`/`sti`. Poor target despite the headline 29. |
| `ukallocpool` | allowlist | 12 | 0 | 0 | **12** | — | 23 | yes | **The best small unclaimed target.** Two asserts in `uk_allocpool_free` (`pool.c:383,386`) are the whole challenge in miniature: a pool built by `uk_allocpool_init` may *never* be freed by `uk_allocpool_free` (only one built by `uk_allocpool_alloc` may), and every object `take`n must be `return`ed first. Two constructors, one destructor, and picking the wrong pair vanishes at `-DNDEBUG`. Zero inlines. |
| `ukmpi` | allowlist | 10 | 0 | 0 | **10** | — | 15 | yes | Mailbox. `uk_mbox_free` asserts `m->readpos == m->writepos` (`mbox.c:38`) — **drain before free** — and takes the allocator again, so the create/free allocator pairing is an unwritten rule too. `post`/`recv` × blocking/`_try`/`_to` is a clean exercise in branch payload vs. state. Zero inlines. |
| `ukintctlr` | allowlist | 11 | 0 | 0 | **11** | — | 21 | yes | Interrupts — an organ nothing shipped touches. `irq_alloc`/`irq_free` over a bitmap (leakable), `irq_register`/`irq_unregister` over handler slots, and `register` *unmasks* the line so `unregister` must re-mask. `uk_intctlr_init` before any of it, enforced by nothing: the read path is `uk_intctlr->ops->…` and a null there is a dead machine, which is the `ukvmem` shape. Zero inlines. |
| `uksglist` | allowlist | 11 | 0 | 0 | **11** | 2M | 8 | yes | `alloc → append… → free` with `split`/`join`/`clone`/`slice`. A build-then-use ordering over a segment array; the two inlines are `init`/`reset`. |
| `ukfs` | allowlist | 7 | 0 | 0 | **7** | 7F/21M | 35 | yes | Mount/unmount plus node refcounting. Only 7 symbols link; the real API is 28 inlines, 21 of which are MIRROR — so this is reachable but it is a **transcription job**, and the mirror is `struct uk_file` + `uk_fs_node`. |
| `ukfile` | **open** | — | 0 | 0 | **10** | 51M/3N | 9 | yes | **Correction to the old shelf, which called it "thin".** It is not thin — it is 54 inlines of which **51 are MIRROR**, i.e. reachable, and only 3 are NO. But every one of them is `struct uk_file`/`uk_pollq`/`uk_swrefcount` offsets, so a lift is almost entirely mirror and almost not at all calls. Reachable; expensive; honest to say so. |
| `uksparsebuf` | allowlist | 9 | 0 | 0 | **9** | 1F/21M/2N | 26 | yes | Sparse page-indexed buffer over an rb-tree. 21 MIRROR inlines over `struct uk_sparsebuf`; the ordering is `insert → fill/scoop → collapse → ref_release`. |
| `ukpod` | allowlist | 10 | 0 | 0 | **10** | 10F/1N | 4 | yes | Page-on-demand contexts: `eager_init_ctx → alloc → writeback → drop → free`. Ten of eleven inlines are FREE. Only 4 asserts — the ordering is real but the C never states it, which is the `ukvmem` case again. |
| `ukstreambuf` | allowlist | 7 | 0 | 0 | **7** | 1M | 8 | yes | Append-only formatting buffer: `init`/`alloc2 → strcpy/printf/memcpy → free`, with a "ended/truncated" state. Small and clean; modest payoff. |
| `ukrandom` | allowlist | 4 | 0 | 0 | **4** | — | 11 | yes | `init → fill_buffer`/`getrandom`, `reseed`. Init-before-use and nothing else. Honest, small, low ceiling. |
| `ukring` | allowlist | 12 | 0 | **10** | **2** | 9M/1N | 2 | yes | The case-5 extreme: 12 listed, 2 link. Its ordering rule is *which thread may call which verb* — the `_sc` (single-consumer) suffix is documented in a comment and enforced by nothing at all. Genuinely interesting shape, but the whole API is a mirror and the rule is about callers, not calls. |
| `ukfalloc` | allowlist | 2 | 0 | 0 | **2** | 1F/6M | 9 | yes | Frame allocator. Both exported symbols are stats internals; the real interface is `struct uk_falloc` function pointers. Mirror-only. `ukfallocbuddy` beside it exports 3 and carries **136** asserts — the shape is there, the surface is not. |
| `ukbitops` | **open** | — | 0 | 0 | **0** | 39F/8N | 0 | yes | Header-only. Nothing to link, no resource, no ordering. Named here so nobody measures it twice. |
| `isrlib` | **open** | — | 0 | 0 | **20** | — | 0 | yes | 20 symbols link (case 2), all `memcpy_isr`-style interrupt-safe libc. No resource, no ordering. Named here so nobody measures it twice. |

**Poor targets, said plainly, because the brief asks for it:** `ukbitops`,
`isrlib`, `ukrandom`, `ukstreambuf`, `ukcpio` (1 symbol), `ukargparse`, `ukbus`,
`ukboot`, `uklibparam`, `uktimeconv`, `uksp`, `ukgcov`, `ukpcpuvar`, `ukatomic`,
`ukpal`, `uklibid`, `ukreloc` and `ukrust` each have either no resource or no
ordering rule, and lifting them would produce a wrapper with nothing to retire.

**Rejected on altitude, not on measurement.** The largest allowlists in the tree
are `vfscore` (162 links), `nolibc` (112), `posix-vfs` (89), `fdt` (78),
`posix-process` (60), `posix-fdio` (46 via case 2), `posix-user` (38),
`posix-unixsocket` (36 via case 2), `posix-time` (27), `posix-socket` (25),
`posix-fdtab` (16). They are excluded by the brief's own **bind at the NATIVE
altitude** rule, not because they are small — they are the biggest thing here. If
you want one, argue against that rule explicitly rather than around it. (`fdt` is
the interesting edge: 78 links, 29 of its 30 inlines FREE, and it is a *parser*,
so it has no resource and no ordering at all.)

The remaining libraries measured and not tabled are in the full census below.
Nothing was dropped; a candidate absent from the shelf is present there with its
numbers.

**`uknetdev` — the trap has been re-measured, and the previous verdict was
WRONG.** The old text said the per-packet half "cannot be reached from a Koru
archive without a shim or an ABI guess", and told contestants not to promise the
transfers. That was written under the old rule, and it does not survive the new
one. `uk_netdev_rx_one`'s entire body, once `UK_ASSERT` is `do {} while(0)` and
`CONFIG_LIBUKNETDEV_STATS` is off — which is the config every shipped lift builds
— is two field reads and an indirect call:

```c
ret = dev->rx_one(dev, dev->_rx_queue[queue_id], pkt);
```

That is a **mirror**, in the same class `pages`, `sched` and `lock` already
built and proved. It is not a shim and it is not an ABI guess: the callee's
signature is the public `uk_netdev_rx_one_t` typedef. Measured on a booted probe
unikernel — a `main.c` that prints `offsetof`/`sizeof` and nothing else, over a
`Kraftfile` whose only additions are `CONFIG_LIBUKNETDEV: 'y'` and
`CONFIG_STACK_SIZE_PAGE_ORDER: '6'`; the resulting `.config` has
`LIBUKNETDEV_MAXNBQUEUES=1` and `STATS`, `DISPATCHERTHREADS`, `EINFO_LIBPARAM`
all unset, which are the defaults. Under a minute end to end:

```
PROBE uk_netdev sizeof=64
PROBE off tx_one=0   rx_one=8   _data=16   ops=24   _rx_queue=32   _tx_queue=40
PROBE MAXNBQUEUES=1
PROBE netdev_data sizeof=40 state_off=0
PROBE netbuf sizeof=96  buf=48 len=32 data=24 refcount=36
```

Three facts fall out and each one matters. **(1)** Every field the hot path needs
sits at offset ≤ 40, *ahead of every Kconfig-conditional member* — `_einfo`,
`scratch_pad`, `_stats` and `_stats_lock` are all at the tail
(`netdev_core.h:528-541`), so the mirror does not move when those flip. Only
`_tx_queue`'s offset depends on `CONFIG_LIBUKNETDEV_MAXNBQUEUES`, and that is one
number a probe prints. **(2)** `struct uk_netdev_data`'s `state` is at offset 0,
and `uk_netdev_state_get` is **exported** — so the mirror can be proved by an
exported-value witness, which is a stronger proof than `sched` could get. **(3)**
Netbuf allocation and release are fully exported (`uk_netbuf_alloc_buf`,
`uk_netbuf_prepare_buf`, `uk_netbuf_free`, `uk_netbuf_free_single`,
`uk_netbuf_append`); the refcount *helpers* are inline, but they are conveniences,
not the only road. The old note's "refcounted netbufs" was the right observation
attached to the wrong conclusion.

So: **`uknetdev`'s transfers ARE reachable, and this is the shelf's biggest
opening.** 170 asserts — the most of any library in the tree — over a state
machine the C writes down and deletes at `-DNDEBUG`. What a contestant owes is
the mirror proof, not an apology for attempting it. `lib/uknetdev` is
byte-identical between the fork and 0.21.0, so the probe above answers for both.

`ukblkdev` is what `uknetdev` looked like from a distance: the same explicit state
machine and nested queue sub-resource, and it exports its **whole** surface
including `uk_blkdev_queue_submit_one` and `uk_blkdev_queue_finish_reqs`, so the
lifecycle *and* the transfers are provable end to end. It is already taken. The
shelf above is what remains.

**One global-export subtlety, measured and found not to matter:**
`Makefile.rules:1043` also applies `EACHOLIB_EXPORTS` to every library that has
its own exports. The only setter in the tree is
`lib/syscall_shim/Makefile.uk:49`, gated on `CONFIG_LIBSYSCALL_SHIM`, which is
off in every image these lifts build. No native library's allowlist is widened by
it.

<details>
<summary><b>Full census — all 87 libraries at HEAD `3fdffba8`, nothing dropped</b></summary>

Mechanical columns only; the shelf above carries the shape readings. Reproduce by
re-running the case 1–5 checks; every number here came from a script, none from a
reading.

| C library | gate | allowlist | phantom | inert | **links** | inline F/M/A/N | `UK_ASSERT` | in 0.21.0 |
|---|---|---:|---:|---:|---:|---|---:|---|
| `9pfs` | allowlist | 1 | 0 | 0 | **1** | — | 7 | yes |
| `devfs` | allowlist | 9 | 0 | 0 | **9** | — | 13 | yes |
| `fdt` | allowlist | 78 | 0 | 0 | **78** | 29F/1M | 0 | yes |
| `isrlib` | open | — | 0 | 0 | **20** | — | 0 | yes |
| `nolibc` | allowlist | 112 | 0 | 0 | **112** | 2F | 1 | yes |
| `posix-environ` | allowlist | 9 | 0 | 0 | **9** | — | 0 | yes |
| `posix-eventfd` | open | — | 0 | 0 | **4** | — | 3 | yes |
| `posix-fd` | open | — | 0 | 0 | **0** | 6M | 0 | yes |
| `posix-fdio` | open | — | 0 | 0 | **46** | 1F | 20 | yes |
| `posix-fdtab` | open | — | 0 | 0 | **16** | — | 15 | yes |
| `posix-futex` | allowlist | 0 | 0 | 0 | **0** | — | 3 | yes |
| `posix-libdl` | allowlist | 7 | 0 | 0 | **7** | — | 0 | yes |
| `posix-mmap` | allowlist | 6 | 0 | 0 | **6** | — | 0 | yes |
| `posix-netlink` | allowlist | 0 | 0 | 0 | **0** | 3M | 7 | yes |
| `posix-pipe` | open | — | 0 | 0 | **3** | — | 12 | yes |
| `posix-poll` | open | — | 0 | 0 | **10** | 1N | 8 | yes |
| `posix-process` | allowlist | 60 | 0 | 0 | **60** | 2F | 170 | yes |
| `posix-socket` | allowlist | 27 | 2 | 0 | **25** | 28M/1N | 35 | yes |
| `posix-sysinfo` | allowlist | 10 | 0 | 0 | **10** | — | 0 | yes |
| `posix-time` | allowlist | 27 | 0 | 0 | **27** | — | 0 | yes |
| `posix-timerfd` | open | — | 0 | 0 | **7** | — | 6 | yes |
| `posix-tty` | open | — | 0 | 0 | **0** | — | 2 | yes |
| `posix-unixsocket` | open | — | 0 | 0 | **36** | — | 16 | yes |
| `posix-user` | allowlist | 38 | 0 | 0 | **38** | — | 11 | yes |
| `posix-vfs` | allowlist | 89 | 0 | 0 | **89** | 17F/2M | 51 | yes |
| `posix-vfs-fstab` | allowlist | 0 | 0 | 0 | **0** | — | 7 | yes |
| `ramfs` | allowlist | 0 | 0 | 0 | **0** | — | 1 | yes |
| `syscall_shim` | open | — | 0 | 0 | **5** | 2F/2M/2N | 19 | yes |
| `ubsan` | allowlist | 34 | 0 | 0 | **34** | — | 2 | yes |
| `uk9p` | allowlist | 46 | 0 | 0 | **46** | 14M | 21 | yes |
| `ukalloc` | allowlist | 25 | 2 | 0 | **23** | 1F/24M | 45 | yes |
| `ukallocbbuddy` | allowlist | 1 | 0 | 0 | **1** | — | 24 | yes |
| `ukallocpool` | allowlist | 12 | 0 | 0 | **12** | — | 23 | yes |
| `ukallocregion` | allowlist | 4 | 0 | 0 | **4** | — | 7 | yes |
| `ukallocstack` | allowlist | 1 | 0 | 0 | **1** | — | 12 | yes |
| `ukargparse` | allowlist | 4 | 0 | 0 | **4** | — | 7 | yes |
| `ukatomic` | open | — | 0 | 0 | **0** | — | 0 | yes |
| `ukbinfmt` | open | — | 0 | 0 | **3** | — | 18 | yes |
| `ukbitops` | open | — | 0 | 0 | **0** | 39F/8N | 0 | yes |
| `ukblkdev` | allowlist | 18 | 0 | 0 | **18** | 5M | 105 | yes |
| `ukboot` | allowlist | 5 | 0 | 0 | **5** | — | 16 | yes |
| `ukbus` | allowlist | 4 | 0 | 0 | **4** | — | 7 | yes |
| `ukconsole` | allowlist | 17 | 0 | 0 | **17** | 2M | 26 | yes |
| `ukcpio` | allowlist | 1 | 0 | 0 | **1** | 1F/1M | 2 | yes |
| `ukdebug` | allowlist | 4 | 0 | 0 | **4** | 1F/1M/2N | 20 | yes |
| `ukfalloc` | allowlist | 2 | 0 | 0 | **2** | 1F/6M | 9 | yes |
| `ukfallocbuddy` | allowlist | 3 | 0 | 0 | **3** | — | 136 | yes |
| `ukfile` | open | — | 0 | 0 | **10** | 51M/3N | 9 | yes |
| `ukfile-console` | allowlist | 1 | 0 | 0 | **1** | — | 14 | **no** |
| `ukfile-pseudo` | allowlist | 3 | 0 | 0 | **3** | — | 6 | yes |
| `ukfs` | allowlist | 7 | 0 | 0 | **7** | 7F/21M | 35 | yes |
| `ukfs-devfs` | allowlist | 1 | 0 | 0 | **1** | — | 0 | yes |
| `ukfs-ramfs` | allowlist | 0 | 0 | 0 | **0** | — | 18 | yes |
| `ukfs-virtiofs` | allowlist | 0 | 0 | 0 | **0** | — | 46 | yes |
| `ukgcov` | allowlist | 1 | 0 | 0 | **1** | — | 0 | yes |
| `ukintctlr` | allowlist | 11 | 0 | 0 | **11** | — | 21 | yes |
| `uklcpu` | allowlist | 29 | 0 | 16 | **13** | 20F/12M/3N | 25 | yes |
| `uklibid` | open | — | 0 | 0 | **3** | — | 1 | yes |
| `uklibparam` | allowlist | 1 | 0 | 0 | **1** | — | 15 | yes |
| `uklock` | allowlist | 15 | 2 | 0 | **13** | 13M/3A/1N | 30 | yes |
| `ukmmap` | allowlist | 5 | 0 | 0 | **5** | — | 0 | yes |
| `ukmpi` | allowlist | 10 | 0 | 0 | **10** | — | 15 | yes |
| `uknetdev` | allowlist | 33 | 0 | 2 | **31** | 12M | 170 | yes |
| `uknofault` | allowlist | 6 | 3 | 0 | **3** | — | 11 | yes |
| `ukofw` | allowlist | 14 | 1 | 1 | **12** | 1F | 8 | yes |
| `ukpaging` | allowlist | 15 | 0 | 0 | **15** | 8F/3A | 140 | yes |
| `ukpal` | open | — | 0 | 0 | **0** | — | 0 | yes |
| `ukpcpuvar` | allowlist | 3 | 0 | 0 | **3** | — | 0 | yes |
| `ukpm` | allowlist | 8 | 0 | 0 | **8** | 7F | 6 | yes |
| `ukpod` | allowlist | 10 | 0 | 0 | **10** | 10F/1N | 4 | yes |
| `ukprint` | allowlist | 11 | 2 | 0 | **9** | 13F | 13 | yes |
| `ukrandom` | allowlist | 4 | 0 | 0 | **4** | — | 11 | yes |
| `ukreloc` | open | — | 0 | 0 | **2** | 2F/1M | 1 | yes |
| `ukring` | allowlist | 12 | 0 | 10 | **2** | 9M/1N | 2 | yes |
| `ukrust` | open | — | 0 | 0 | **5** | — | 0 | yes |
| `uksched` | allowlist | 42 | 1 | 0 | **41** | 4F/22M/1N | 112 | yes |
| `ukschedcoop` | allowlist | 1 | 0 | 0 | **1** | — | 14 | yes |
| `uksglist` | allowlist | 11 | 0 | 0 | **11** | 2M | 8 | yes |
| `uksp` | allowlist | 2 | 0 | 0 | **2** | 1F | 0 | yes |
| `uksparsebuf` | allowlist | 9 | 0 | 0 | **9** | 1F/21M/2N | 26 | yes |
| `ukstore` | allowlist | 39 | 0 | 0 | **39** | — | 28 | yes |
| `ukstreambuf` | allowlist | 7 | 0 | 0 | **7** | 1M | 8 | yes |
| `uktest` | open | — | 0 | 0 | **4** | — | 6 | yes |
| `uktimeconv` | allowlist | 3 | 0 | 0 | **3** | 2F/4M | 1 | yes |
| `ukvmem` | allowlist | 20 | 0 | 0 | **20** | 4F/7M/1N | 128 | yes |
| `ukvsockdev` | allowlist | 21 | 0 | 0 | **21** | 7M | 39 | **no** |
| `vfscore` | allowlist | 168 | 6 | 0 | **162** | 3F/3M/1N | 78 | yes |

</details>

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

- 2026-08-06 — **the shelf re-measured against the corrected linkability rule,
  and `uknetdev` un-written-off.** The previous pass ruled that `static inline`
  is not a verdict and then said, in its own words, that the shelf's numbers were
  "now known to be measuring the wrong thing". They were. All **87** `lib/`
  directories at HEAD `3fdffba8` were re-measured by script rather than by
  reading, and the seven-row table became a 26-row shelf plus a full 87-row
  census, so a candidate absent from the shelf is present with its numbers rather
  than dropped.

  **Four things changed that a contestant will feel.**

  (1) **`uknetdev`'s transfers are reachable, and the brief was telling people
  the opposite.** With `UK_ASSERT` compiled out — which is the config every
  shipped lift builds — and `CONFIG_LIBUKNETDEV_STATS` off, the whole body of
  `uk_netdev_rx_one` is `dev->rx_one(dev, dev->_rx_queue[qid], pkt)`. That is
  offsets, not symbols: the same MIRROR instrument `pages`, `sched` and `lock`
  already built and proved. A probe unikernel settled it in twenty seconds —
  `sizeof(struct uk_netdev)` is 64, `rx_one` at 8, `_rx_queue` at 32, and every
  Kconfig-conditional member is at the tail, so the mirror does not move when they
  flip. `uk_netdev_state_get` is exported, so the mirror can be proved by value
  witness rather than by structure-walking, which is a stronger proof than
  `sched` could obtain. The old note's observation — refcounted netbufs — was
  true and led to the wrong conclusion; netbuf alloc and free are fully exported.

  (2) **A fifth linkability hazard: an allowlist line can name a `static
  inline`,** and then it is inert, because no global is emitted for objcopy to
  keep. **29 lines across 4 libraries.** `ukring` lists 12 and exactly 2 link;
  `uklcpu` lists 29 and 16 are inert. This is the hazard that most inflates a
  `linkable` count and it is invisible to both the case-3 and the case-4 check.

  (3) **The phantom hazard is not a `uklock` curiosity — it is 19 lines across 10
  libraries, two of them in TAKEN slots.** `ukalloc` is 23, not 25
  (`uk_palloc_compat`, `uk_pfree_compat`); `uksched` is 41, not 42
  (`uk_sched_create`). Both corrected in place. The inverse trap was measured
  too and is now written down: `ubsan`'s 34 handlers and `ukstore`'s two event
  symbols have no textual hit anywhere because they are built by `##` token
  pasting. A name with no hit is a candidate, not a verdict.

  (4) **Case 3 splits into three, not two.** FREE / MIRROR / NO, because
  "unreachable without a shim or a mirror" was banking two very different costs
  in one word, and three shipped lifts have paid the mirror one and proved it.
  Inline assembly is called out separately inside NO — `ukpaging`'s three
  control-register accessors are not a linkability problem, they are an
  instruction-emission problem, and no mirror helps.

  **And a version trap nobody had named.** The shelf measures our fork; every
  `Kraftfile` says `version: stable` and builds against **0.21.0 "Ijiraq"**. The
  two trees were diffed: they agree on every tabled library except that
  **`ukvsockdev` and `ukfile-console` do not exist in 0.21.0 at all**, and
  `ukconsole` has 17 allowlist lines in the fork against 7 in stable (the whole
  async family and `uk_console_unregister` are fork-only). `ukvsockdev` measured
  as one of the best unclaimed shapes in the tree — a device lifecycle, a
  connection lifecycle and a buffer — and a contestant would have built it and
  then found it unlinkable. It is on the shelf with that stated in its row.

  **Newly opened by the corrected rule:** `uknetdev` (transfers), `ukfile` (51
  of its 54 inlines are MIRROR, so "thin" was wrong — it is mirror-heavy, which
  is a different objection), `ukring` (reachable, but 10 of 12 lines are inert),
  `ukfs` and `uksparsebuf` (reachable, transcription-heavy). **Newly recommended
  on shape rather than on the rule:** `ukallocpool`, whose two `uk_allocpool_free`
  asserts are the entire challenge in miniature — a pool built by `init` may
  never be freed by `free`, and every object taken must be returned first;
  `ukmpi`, whose `uk_mbox_free` asserts the mailbox is drained; `ukintctlr`, an
  organ nothing shipped has touched, where the init ordering is enforced by
  nothing and the penalty is a dead machine; and `uk9p`, which has three nested
  resources with an explicit state enum each and is the richest unclaimed
  ordering in the tree.

  **One measurement caveat, stated because the column would otherwise lie.**
  Macro-generated `static inline`s are invisible to a name-based scan:
  `uk9p`'s `uk_9preq_read32`/`write32` family is produced by a `##` template at
  `9preq.h:310,379`, and the automated pass filed the eight helpers that call
  them as NO. They are MIRROR — buffer-cursor arithmetic over `struct uk_9preq` —
  and the row is corrected by hand to 14M/0N. If your own scan reports an
  unresolved callee, check for token pasting before believing it. — walk
- 2026-08-06 — the wave-3 pass, three edits all paid for by replays that had
  already shipped. (1) **The linkability rule's case 3 splits.** `static inline`
  was being read as a budget of unreachable surface; `ukvmem` showed the keyword
  is not the verdict and what the inline CLOSES OVER is. Four of its five are an
  exported call plus an exported data symbol and cost nothing to reconstruct; the
  fifth closes over Kconfig integers and is genuinely out of reach. This
  re-explains `uknetdev` too — its hot path is unreachable because it walks
  refcounted netbufs through struct fields, not because of the keyword — and it
  means **the shelf's numbers are now known to be measuring the wrong thing and
  need re-measuring against the corrected rule.** (2) **A fourth linkability
  hazard**: an allowlist can name symbols that do not exist. `uklock` lists
  `uk_rwlock_upgrade`/`downgrade`; the only hits in the tree are those two lines,
  because objcopy is a filter and naming a phantom is not an error. (3) **The
  catalog now states that later entries SUPERSEDE earlier ones**, because the
  mirror lesson was recorded twice and a third lift still repeated it — two
  entries describing different approaches read as a menu, not as a correction.
  Also landed this session and not a tuning: the worktree-alias trap, now under
  *Four traps*, and `koru.json`'s retirement in favour of `std/compiler:paths`.
  — walk
- 2026-08-06 — **naive-wrap lane opened, ruled by Lars.** Pillar 5 said a wrapper
  that removes no runtime check has not done the job, and that stays the bar. But
  where the open question is *reachability*, a naive wrap that answers it and
  stops is now shippable, on two hard conditions: it must SAY it is one in the
  README's first paragraph and its catalog line, and it must claim nothing it did
  not earn — an honest zero-assertions census is fine, a padded one is not. The
  idiomatic pass is a later replay revising that module in place, which the
  one-module-per-sublibrary rule already provides for. Rationale in his words:
  wrap naively, get unblocked, rub the Koru idioms on it afterwards. This trades
  depth-per-entry for breadth-of-shelf on purpose, and the honesty conditions are
  what stop it from becoming the wrapper-with-a-safety-badge the brief was
  written against. — walk

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
