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

Before choosing, read the catalog: every directory under `unikraft/` with an
`index.kz` is a shipped or in-flight lift. Read their READMEs and their tests.
Bring something not already there.

Measured shelf — resource-bearing surface, public functions per library
(`unikraft` HEAD `3fdffba8`):

| C library | fns | Koru module | shape |
|---|---:|---|---|
| `uksched` | 79 | `unikraft/sched` | threads; ordering + lifetime |
| `ukfile` | 75 | `unikraft/file` | handles; open/close family |
| `uknetdev` | 61 | `unikraft/net` | **the exemplar target** — explicit state machine, per-packet netbufs |
| `ukalloc` | 52 | `unikraft/alloc` | symmetric pair; a good test of *not* over-modelling |
| `ukblkdev` | 36 | `unikraft/blk` | netdev-shaped, smaller |
| `ukvmem` | 32 | `unikraft/vmem` | mappings |
| `uklock` | 30 | `unikraft/lock` | classic acquire/release on every path |

**Naming: drop the `uk` prefix and the transliteration.** The C library is
`uknetdev`; the Koru module is `unikraft/net`, imported as `import unikraft/net`.
`unikraft` is a platform namespace beside `std`, not a shelf under `koru` — a
caller is naming the operating system they are inside, not a third-party
dependency they picked. If the DX pillar means anything it means a consumer never
types `uknetdev`.

`uknetdev` + `netbuf` together carry every obligation shape you will ever need —
ratchet, nested sub-resource (queues), paired toggle (`rxq_intr_enable/disable`),
**refcount** (`uk_netbuf_ref`, where "discharge exactly once" stops being true),
ownership transfer (`tx_one` consumes the buffer), chain/unchain. If you take it,
you are writing the template; scope to a slice and say what you left.

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

And one that is ours, not Unikraft's: **Koru's print puts a 65,536-byte buffer on
the stack**, which is exactly Unikraft's default 64 KB boot stack
(`STACK_SIZE_PAGE_ORDER=4`). `koru/unikraft:kconfig` emits order 6 for you; if you
hand-roll a Kraftfile, carry it.

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
3. List `unikraft/*/` and read what is there. Dedup.
4. Pick a target from the shelf. Grep it for `UK_ASSERT` and state branches
   before you design anything — that grep IS the state machine.
5. Build. Ground every Koru construct in a passing test.
6. Boot it. Run the gates. Write the writeup. Stop — do not start a second.

---

**Catalog upkeep**: a shipped lift is a directory under `unikraft/<name>/`
with `index.kz`, `tests/`, and `README.md`. The catalog is the repo.

## Tending log

- 2026-08-06 — planted. Split from `LIFT_CHALLENGE` because gate 2 (`koruc run`)
  cannot prove a unikernel, and because Unikraft's unit is a sublibrary, not a
  library. Carries the obligation-asymmetry rule, the `invalid!` shape, and the
  four build traps from the session that first booted Koru on Unikraft.
