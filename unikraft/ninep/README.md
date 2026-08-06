# `unikraft/ninep` — Unikraft's `uk9p` behind three nested obligations

**This is a full lift, not a naive wrap.** Fourteen tors, four handle types,
eleven phantom states, six negative tests, and a unikernel that mounts a host
directory over virtio-9p, reads a file, writes it back and unwinds three
resource lifetimes in order. 7 of `uk9p`'s 21 `UK_ASSERT`s are retired, per
site, below — and 14 are not, also per site.

Its contribution is the one thing the shelf said was open about this target:
**how obligations compose across a nesting.** `blk` has a device with a queue
and answers it by collapsing the sub-resource into the parent's state. That
works for one queue. It does not work for fids, of which there are many and each
of which carries data. This module answers it differently, and the answer is one
sentence:

> **The parent handle is CONSUMED by the child's constructor and RE-MINTED by
> the child's destructor.**

Applied at every level. While a child is live the parent has no name, so an
operation that would outlive its children is not a program that can be written.

---

## The shape

```
                       consumed by                re-minted by
  *Dev   <linked>   ──  version    ──▶ *Reply  ──  reply.release  ──▶ *Dev <negotiated>
  *Dev   <negotiated>── attach     ──▶ *Root   ──  session.end    ──▶ *Dev <drained>
  *Root  <attached> ──  walk       ──▶ *File   ──  file.close     ──▶ *Root <rooted>
```

| tor | needs | mints | C call |
|---|---|---|---|
| `probe` | — | — | `uk_9pdev_trans_get_default` |
| `connect` | — | `*Dev<linked!>` | `uk_9pdev_connect` |
| `version` | `*Dev<!linked>` | `*Reply<received!>` | `uk_9p_version` |
| `reply.release` | `*Reply<!received>` | `*Dev<negotiated!>` | `uk_9pdev_req_remove` |
| `attach` | `*Dev<!negotiated>` | `*Root<attached!>` | `uk_9p_attach` |
| `walk` | `*Root<!attached\|!rooted>` | `*File<walked!>` | `uk_9p_walk` |
| `file.open` | `*File<!walked>` | `*File<opened!>` | `uk_9p_lopen` |
| `file.read` | `*File<!opened\|!io>` | `*File<io!>` | `uk_9p_read` |
| `file.write` | `*File<!opened\|!io>` | `*File<io!>` | `uk_9p_write` |
| `file.close` | `*File<!walked\|!opened\|!io>` | `*Root<rooted!>` | `uk_9pfid_put` |
| `walk.skipped` | `*Root<!attached>` | `*Root<rooted!>` | **none** — the escape |
| `session.end` | `*Root<!rooted>` | `*Dev<drained!>` | `uk_9pfid_put` |
| `session.skipped` | `*Dev<!linked\|!negotiated>` | `*Dev<drained!>` | **none** — the escape |
| `disconnect` | `*Dev<!drained>` | — | `uk_9pdev_disconnect` |

### Which states came from a declared enum, and which I inferred

The brief asks for this split because a state the C *names* is stronger evidence
than one a lift infers. `uk9p` declares two enums.

| state | evidence |
|---|---|
| `linked`, `negotiated`, `drained` | **DECLARED.** `enum uk_9pdev_trans_state { UK_9PDEV_CONNECTED, UK_9PDEV_DISCONNECTING }`, `9pdev_core.h:152`. Asserted at `9pdev.c:265`, branched on for real at `9pdev.c:295`. Three phantom states over the C's one, because the C's `CONNECTED` covers the whole window and the 9P protocol does not. |
| `received` | **DECLARED, and the only member of `enum uk_9preq_state` a Koru caller can hold.** `9preq.h:121`. See *What does not link* — the other three are unreachable. |
| `attached`, `rooted`, `walked`, `opened`, `io` | **INFERRED.** `struct uk_9pfid` (`9pfid.h:52`) has a refcount, a qid, an iounit and a `was_removed` flag, and **no state field**. These five are the weakest-evidenced states in the module. They are grounded in the ordering `9p.c` and the 9P2000.L protocol impose — you cannot Tread a fid you have not Tlopen'd, you cannot Twalk from a fid you have not Tattach'd — but the C writes that ordering down nowhere. |

---

## Gate 2 — it boots, against a real 9P server

Reproduced clean. `version: stable` builds against **Unikraft 0.21.0 "Ijiraq"**
(`UK_VERSION=0 UK_SUBVERSION=21 UK_CODENAME=Ijiraq`), kraftkit 0.12.15, on
macOS/arm64 under QEMU TCG.

**The build directory has to be shaped so the namespace alias resolves.** Every
entry file declares `unikraft: {{ ENTRY }}/../..`, which means the directory two
levels above the entry file must be the one holding `ninep/`. Copying the tests
to a flat `/tmp/x` — which is what `blk`'s README still says — fails with
`KORU002 module not found`. Two levels of throwaway directory plus a symlinked
module tree is the cheapest fix:

```sh
W=<this worktree>
mkdir -p /tmp/ninep/uk/b/uild /tmp/ninep/share
for f in $W/unikraft/*; do ln -s "$f" /tmp/ninep/uk/; done
cp $W/unikraft/ninep/tests/{boot_session.kz,wrapper.zig,main.c} /tmp/ninep/uk/b/uild/
printf 'HOST PLANTED THIS FILE BEFORE BOOT -- read back by unikraft/ninep over virtio-9p.\n' \
    > /tmp/ninep/share/koru.txt
cd /tmp/ninep/uk/b/uild

koruc boot_session.kz unikraft gen        # -> Makefile.uk + Kraftfile
koruc boot_session.kz                     # -> output_emitted.zig
                                          #    (the host link then fails on the
                                          #     Unikraft symbols; that is expected)
zig build-lib wrapper.zig \
    -target x86_64-freestanding -O ReleaseSmall \
    -fno-stack-protector -femit-bin=libkoruapp.a
UK_CFLAGS="-std=gnu17" kraft build --arch x86_64 --plat qemu --no-prompt
```

**The exact qemu invocation.** The `-cpu` line is not optional — a sibling lift
lost a boot to leaving it out — and the two 9P lines are what make this test do
anything at all:

```sh
qemu-system-x86_64 -kernel .unikraft/build/koru_qemu-x86_64 \
  -cpu 'qemu64,+pdpe1gb,+rdrand,+rdseed,-vmx,-svm' \
  -m 64M -nographic -no-reboot -display none -parallel none \
  -fsdev local,id=fs0,path=/tmp/ninep/share,security_model=none \
  -device virtio-9p-pci,fsdev=fs0,mount_tag=korufs
```

Real console output, `\r` stripped, nothing else edited:

```
SeaBIOS (version rel-1.17.0-0-gb52ca86e094d-prebuilt.qemu.org)

iPXE (http://ipxe.org) 00:03.0 CA00 PCI2.10 PnP PMM+02FD1D10+02F31D10 CA00
Press Ctrl-B to configure iPXE (PCI 00:03.0)...

Booting from ROM..transport:      true
version:        9P2000.L, msize 520192
reply.release:  tag returned, was_last true
read  @0:      HOST PLANTED THIS FILE BEFORE BOOT -- read back by unikraft/ninep over virtio-9p.

write @0:      93 bytes accepted
read  @0:      KORU WROTE THIS OVER 9P -- uk_9p_write through unikraft/ninep, three nested obligations deep.
file.close:     fid put, was_last true
session.end:    root put, was_last true
disconnect:     rc 0
session.skipped: a mount opened and never attached to, said out loud
disconnect:     rc 0
```

And the write is on the host filesystem afterwards:

```
$ cat /tmp/ninep/share/koru.txt
KORU WROTE THIS OVER 9P -- uk_9p_write through unikraft/ninep, three nested obligations deep.
```

**What each line proves.**

- `transport: true` — a virtio-9p device registered a transport before `main`.
- `9P2000.L, msize 520192` — the version string came back through this module's
  **one** struct mirror, `struct uk_9p_str` (`9p_core.h:248`), and `version`
  refuses unless it matches what went in. `520192` is QEMU's answer, read back
  through `uk_9pdev_get_msize`; it is not a constant this lift knows.
- The three `was_last true` lines are the C's own refcount answers.
  `uk_9pdev_req_remove` and `uk_9pfid_put` return 1 only on the final reference.
  Three of them, in nesting order, is `9pdev.c:118`'s assertion — *every fid
  clunked before the connection is destroyed* — evaluated by the C itself, in an
  image where that assertion is compiled out (`CONFIG_LIBUKDEBUG_ENABLE_ASSERT
  is not set` in the built `.config`).
- The read/write/read triple is a real Tread, Twrite and Tread against a host
  directory, and the last one returns what the unikernel wrote.
- `session.skipped` is a second connection, versioned and never attached to,
  saying so in one greppable word. Without that word the same program is refused
  — `tests/negative_disconnect_without_session.kz`.

| | |
|---|---:|
| Koru freestanding static archive | 26,568 B |
| bootable unikernel image | 202,304 B |
| RAM used in the run above | 64 MB |

No boot-time number, per the brief. This is TCG with no KVM.

---

## The linkability verdict — MEASURED ON THE BUILT OBJECT

`lib/uk9p/exportsyms.uk` exists, so case 1 applies. The shelf records *46
allowlist, 0 phantom, 0 inert, **46 links***. Two of those numbers are right and
the headline is wrong, and there are two separate findings underneath it.

### 1. The count is 44, and the reason is a hazard the brief does not name

`exportsyms.uk` is 52 lines, 46 non-blank — but **44 distinct**.
`uk_9pdev_set_msize` and `uk_9pdev_get_msize` are **each listed twice**. objcopy
does not care; `--keep-global-symbols` is a filter and a repeated line is a
repeated filter. But a line count is not a symbol count.

This is a **sixth linkability hazard**, beside the brief's five: *an allowlist
can name the same symbol more than once.* It is invisible to the case-4 check
(the symbol exists) and to the case-5 check (it is not an inline), and it
inflates the count in exactly the same direction as both.

Not asserted — measured, on the object the build produced:

```
$ nm -g .unikraft/build/libuk9p.o | awk '$2=="T"{print $3}' | sort > nm.txt
$ grep . lib/uk9p/exportsyms.uk | sort -u > allow.txt
$ wc -l nm.txt allow.txt
      44 nm.txt
      44 allow.txt
$ diff nm.txt allow.txt && echo EXACT
EXACT
```

Case 4: **zero** phantoms — every one of the 44 has a real non-`static`
definition. Case 5: **zero** inert lines — none is a `static inline`.

### 2. The allowlist is not closed under the state machine it exposes

This is the finding that decided the module's altitude, and no column on the
shelf can carry it. Four real, non-`static`, externally-visible functions in
`uk9p`'s own `.c` files are **absent from `exportsyms.uk`** and therefore
localized by objcopy. From the same built object, `t` rather than `T`:

```
0000000000000000 t uk_9preq_init            9preq.c:47
0000000000000000 t uk_9preq_ready           9preq.c:87
0000000000000000 t uk_9pdev_req_to_freelist 9pdev.c:416
0000000000000000 t uk_9pdev_fid_release     9pdev.c:448
```

`uk_9preq_ready` is the one that matters. It is the **only** transition out of
`UK_9PREQ_INITIALIZED`, and `uk_9pdev_req_create` — which *is* exported — is the
only thing that produces that state. **The exported surface hands you a request
in a state you have no exported way to leave.** So the low-level path a header
reader designs first,

```
req_create → write32/writestr… → ready → uk_9pdev_request → waitreply
```

is unbuildable from a separately linked archive. It is unbuildable at the
`ready` step, not at the serializer step — and that distinction matters, because
the serializers are exactly the family the brief warned about: the `##`
token-pasted `uk_9preq_write32`/`read32` at `9preq.h:310` and `:379`. Those are
MIRROR, reachable at the price of a transcription over `struct uk_9preq`.
Reachable and useless, because the step after them is not there. **I checked for
token pasting before believing any unresolved name, and the general lesson held
in the other direction too: a name that resolves is not the same as a symbol
that links.**

So this lift binds the `uk_9p_*` layer, where `9p.c`'s `static inline
send_and_wait_zc` (`9p.c:62`) drives `ready → request → waitreply` from inside
the compilation unit that can still see the local symbol. That is not a
compromise on altitude: `uk_9p_attach`/`walk`/`lopen`/`read`/`write` **are** the
native 9P client API, and `9pfs`, the in-tree consumer, calls exactly these.

### 3. A symbol can link, be public, be named after the thing you want, and be the wrong half of it

`uk_9p_clunk` is on the allowlist. It is not a close.

- `uk_9p_clunk(dev, fid)` sends Tclunk and returns. The fid stays on
  `dev->_fid_mgmt.fid_active_list`, still allocated, still counted by
  `9pdev.c:118`, and now naming a fid the **server** has forgotten.
- `uk_9pfid_put(fid)` drops the reference and, on the last one, calls
  `uk_9pdev_fid_release` (`9pfid.c:64`), which clunks *and* takes the fid off
  the active list (`9pdev.c:468`).

This module exposes `uk_9pfid_put` and does not expose `uk_9p_clunk`.

---

## The assert census — per site

21 `UK_ASSERT` in `lib/uk9p` (plus one `UK_BUGON`). **7 retired, 14 not.** The
sites are byte-identical between our fork and 0.21.0 — only `9p.c` differs
between the trees, and `9p.c` contains no assertions.

### Retired — 7

| site | assertion | how |
|---|---|---|
| `9pdev.c:118` | `uk_list_empty(&fid_mgmt->fid_active_list)` | **The headline, and the only cross-resource rule in the library.** `disconnect` accepts only `<!drained>`; `<drained!>` is minted only by `session.end`; `session.end` accepts only `<!rooted>`; `<rooted!>` is minted only by `file.close` or `walk.skipped`. The active list cannot be non-empty at disconnect, because the `*Dev` handle does not exist until the last fid has gone back. Pinned by `tests/negative_disconnect_with_file_open.kz`. |
| `9pdev.c:215` | `trans` | The transport comes from `uk_9pdev_trans_get_default()` inside `connect`. A NULL is the named `absent` arm with a reason, not an assertion, and a caller never supplies one. |
| `9pdev.c:216` | `device_identifier` | The mount tag is a Koru `string` copied into the handle's own NUL-terminated buffer. There is no spelling for a null one. |
| `9pdev.c:264` | `dev` | `*Dev` is minted only by `connect`'s `ok` arm, from a checked `uk_9pdev_connect` return. |
| `9pdev.c:265` | `dev->state == UK_9PDEV_CONNECTED` | **The declared-enum one.** `uk_9pdev_disconnect` ends with `uk_free(dev->a, dev)` (`9pdev.c:279`), so a second call reads `dev->state` out of freed storage — with asserts off, a plain use-after-free followed by `_fid_mgmt_cleanup` walking two list heads the allocator has overwritten. Here the handle is consumed and a second `disconnect` is `KORU030: Use-after-discharge`. |
| `9pdev.c:287` | `dev` (in `uk_9pdev_request`) | **Transitively.** This lift never calls `uk_9pdev_request` directly; every `uk_9p_*` verb does, with the pointer `connect` minted. The condition is structurally guaranteed for every call path a Koru program can create. |
| `9pdev.c:331` | `dev` (in `uk_9pdev_req_create`) | **Transitively**, same reason. |

### Not retired — 14, with the reason

| site | assertion | why not |
|---|---|---|
| `9pdev.c:246` | `dev->max_msize != 0` | A transport-side invariant set by the driver's own `connect`. Nothing a Koru caller can influence. |
| `9pdev.c:288` | `req` (in `uk_9pdev_request`) | Internal to `9p.c`'s own null-checked path; no Koru surface reaches it. |
| `9pdev.c:358` | `req->_dev == dev` | Freelist invariant, internal to `uk_9pdev_req_create`. |
| `9preq.c:94` | `req` (in `uk_9preq_ready`) | `uk_9preq_ready` does not link. Unreachable surface. |
| `9preq.c:143` | `req` (in `uk_9preq_receive_cb`) | Transport-side callback; the virtio driver calls it, not this lift. |
| `9pdev_trans.c:46–52` (**7 sites**) | `trans`, `trans->name`, `trans->ops`, `->connect`, `->disconnect`, `->request`, `trans->a` | Driver registration, not application surface. Same class `blk` filed `uk_blkdev_drv_unregister` under. A lift of `uk_9pdev_trans_register` would be a lift of the *driver* side, which is a different module and not this one. |
| `9pdev_trans.c:83` | `trans` (in `uk_9pdev_trans_set_default`) | `set_default` is not lifted, so the assertion is unspellable rather than retired. Not the same thing, and it is filed here on purpose. |
| `9p_core.h:350` | `stat` (in `uk_9p_stat_init`) | `uk_9p_stat` is not lifted; see *Where I refused to ratchet*. |

Not counted above: **`UK_BUGON(req->recv.offset != UK_9P_HEADER_SIZE)`**
(`9preq.c:223`, inside `uk_9preq_error`). Not retired — it guards against
deserializing from a request before checking it for an error, which happens
entirely inside `9p.c`.

### Real state branches — 1 of 5

The brief asks specifically about branches the C actually keeps in release, as
opposed to assertions it deletes. There are five, all on a declared enum.

| site | branch | retired? |
|---|---|---|
| `9pdev.c:295` | `if (dev->state != UK_9PDEV_CONNECTED) return -EIO` | **YES.** This is a live compare-and-branch on **every 9P message**, in every build, guarding a mistake that has no spelling here: after `disconnect` there is no handle, and before `connect` there is none either. |
| `9pdev.c:290` | `if (req->state != UK_9PREQ_READY)` | no — `9p.c` internal |
| `9preq.c:96` | `if (req->state != UK_9PREQ_INITIALIZED)` | no — `uk_9preq_ready` does not link |
| `9preq.c:146` | `if (req->state != UK_9PREQ_SENT)` | no — transport-side |
| `9preq.c:214` | `if (req->state != UK_9PREQ_RECEIVED)` | no — `uk_9preq_error` is not lifted directly |

### Rules with NO assertion and NO branch, lifted anyway

This is the `unikraft/vmem` category — real ordering rules whose penalty is not
a check — and for `uk9p` it is where most of the value is.

- **Tversion must precede Tattach.** The 9P2000 protocol's rule, because
  Tversion resets the connection and invalidates every fid. `lib/uk9p` has no
  opinion: `uk_9p_attach` builds a Tattach out of whatever state the device is
  in. Worse, the device *looks* ready — `uk_9pdev_connect` sets `dev->msize =
  dev->max_msize` (`9pdev.c:247`) precisely so nothing downstream reads as
  uninitialized. Against a lenient server the connection then runs at a message
  size the two ends never agreed on, and the failure is a truncated read, later,
  on a large file. Pinned by `tests/negative_attach_before_version.kz`.
- **`uk_9p_version`'s request must be removed.** It is the only exported
  `uk_9p_*` verb that does not remove its own request — compare `uk_9p_attach`
  at `9p.c:179` and `uk_9p_walk` at `9p.c:272`. Forget it and the tag stays set
  in a 65,536-entry bitmap (`9p_core.h:373`) that nothing else reclaims, and at
  disconnect the C's entire response is `uk_pr_err("Tag %d still has references
  on cleanup.")` (`9pdev.c:195`) — a message about a start-up mistake delivered
  at shutdown, in a build with logging on. Pinned by
  `tests/negative_reply_leaked.kz`.
- **`uk_9p_read`'s `dev->msize - 11` underflow.** In 0.21.0 — the tree this image
  builds against — `uk_9p_read` is `count = MIN(count, dev->msize - 11)` at
  `9p.c:446` with no guard, so an `msize` of 11 or less wraps the subtraction to
  a gigantic unsigned count. Our fork added `if (dev->msize <=
  UK_9P_RREAD_OVERHEAD) return -EINVAL;` (`9p.c:458`); **stable did not.** This
  lift refuses the same condition in `file.open`, once per file rather than once
  per read, so it holds on both trees.

---

## Gate 3 — the negatives, and the exact diagnostic each produced

All six run through the **full pipeline** (`koruc <file>`, not `--check`);
phantom validation fires in the emit pass. Every diagnostic below was copied
from a real run, not predicted.

| test | crosses | diagnostic |
|---|---|---|
| `negative_disconnect_with_file_open.kz` | **all three levels** | `error[KORU030]: Use-after-discharge: binding 'mount' was already discharged and cannot be used` |
| `negative_disconnect_without_session.kz` | Dev | `error[KORU030]: Phantom state mismatch: expected 'unikraft.ninep:drained' but got 'unikraft.ninep:linked!' for argument 'dev'` |
| `negative_attach_before_version.kz` | Dev ⊃ Reply | `error[KORU030]: Phantom state mismatch: expected 'unikraft.ninep:negotiated' but got 'unikraft.ninep:linked!' for argument 'dev'` |
| `negative_read_after_close.kz` | File | `error[KORU030]: Use-after-discharge: binding 'fh' was already discharged and cannot be used` |
| `negative_reply_leaked.kz` | Dev ⊃ Reply | `error[KORU030]: Resource 'reply' obligation <received!> was not discharged. Call: reply.release` |
| `negative_file_never_closed.kz` | Root ⊃ File | `error[KORU030]: Resource 'node' obligation <walked!> was not discharged. Call: file.close` |

The headline is the first row, and it is worth being precise about *why* it is
a use-after-discharge rather than a state mismatch. Nothing checked
`dev->state`. `attach` **consumed** the `*Dev`, and the only tors that produce
one are `reply.release` and `session.end`. At the moment a `*File` exists, the
binding `mount` has been discharged and naming it is not a state error at all.
**That is the composition rule doing the work, in one diagnostic.**

The last two rows are the property that makes the rule self-enforcing rather
than advisory. `unikraft/alloc` deliberately does not claim "forgetting to free
is a compile error", because a dropped `<live!>` has one unattended terminal
disposer and the compiler silently inserts it. **This module has no terminal
disposer at any level** — every destructor here mints a live obligation on the
parent — so there is nothing for auto-discharge to elect, and a leak at *any* of
the three depths is reported. There is no fourth case where something is
silently inserted.

### One control I ran, and why

The brief's worktree-alias trap says an existing module resolves *silently* to
the main checkout. Rather than assume the `~std/compiler:paths` block was
working, I deleted it from a copy of a passing test and re-ran:

```
$ koruc --check neg_noalias.kz
error[KORU002]: module not found: 'unikraft/ninep'
```

`unikraft/ninep` does not exist in main, so the absence of the block is loud
here — which is the *new-module* failure mode, and it confirms that with the
block present, koruc is reading this worktree's `index.kz` and not another one.

---

## Where I refused to ratchet

Stated as loudly as the ratchets, because the brief asks for the refusals.

1. **`uk_9pfid_get` is not lifted at all.** It is exported, it is half of the
   "refcounted fids" the shelf row advertises, and taking a second reference is
   a legitimate thing to do. It is refused because **a phantom state cannot
   count** — `unikraft/lock` made the same call about `nactive` and N concurrent
   readers, and I am following it rather than re-deriving it. Minting `<held2!>`
   would be a lie about what is proven. What this module models is the reference
   `uk_9pdev_fid_create` opens and `uk_9pfid_put` closes. One handle here means
   one reference.
2. **No ratchet between `walk` and `file.close`.** Walking to a fid and clunking
   it without opening it is how 9P asks "does this path exist", and `uk_9p_walk`
   sends a real Twalk, so the fid *was* used. `file.close` accepts `<!walked>`
   directly. The asymmetry gate on this level sits where the C's own cleanup
   assertion is — between `attach` and `session.end` — not on every fid.
3. **`uk_9pdev_set_msize`/`_get_msize` are not exposed as a settable pair.**
   `uk_9p_version` already calls `set_msize` with the server's answer
   (`9p.c:134` in our fork, `9p.c:120` in 0.21.0); this module reads the result
   back through the getter and returns it as payload. A second, caller-driven
   setter over the same field is precisely how you reach the `dev->msize - 11`
   underflow above. Unspellable rather than checked.
4. **Sixteen other `uk_9p_*` verbs are not lifted** — `flush`, `create`,
   `lcreate`, `remove`, `open` (the 9P2000 one, as opposed to `lopen`), `stat`,
   `wstat`, `fsync`, `readdir`, `getattr`, `setattr`, `renameat`, `rename`,
   `link`, `readlink`, `symlink`. Every one links. They are ordinary verbs on a
   `<!opened|!io>` file and they add no state. Four of them (`stat`, `getattr`,
   `readlink`, `version`) hand back a live `struct uk_9preq *` and would each
   need the `Reply` obligation; the shape is proven once by `version`, and
   repeating it is transcription, not contribution. Adding them is a
   *revision to this module*, per the one-module-per-sublibrary rule.

---

## The cost of the composition rule, stated plainly

**Two files cannot be open on one tree at the same time.** 9P allows it; this
lift does not. `walk` consumes the `*Root`, so while a `*File` is live the tree
has no name.

The alternative was considered and rejected. Make the root **ambient** — every
file tor takes both a `*Root` and a `*File`, the root is never consumed, and N
files can be live. It buys concurrency and it costs the entire contribution:
with the root nameable throughout, `session.end` and `disconnect` become
callable while files are open, and `9pdev.c:118` — the one cross-resource rule
`uk9p` actually writes down — goes back to being uncheckable, because **a
phantom state cannot count live children, so an ambient parent cannot know it
has none.**

That is the conflict the brief asked about, and this is the ruling: **strict
LIFO containment, because it is what makes the assertion structural.** What it
costs in practice is small — `walk → read → close → walk → read → close` is
legal and covers what a unikernel does with a 9P mount, since `walk` accepts
`<!attached|!rooted>`.

The same trade applies one level up and one level down, and it is why
`uk_9p_walk`'s multi-element path is not offered: a deeper path is a chain of
walks, and under LIFO containment a chain has to unwind.

---

## Claims I deliberately do not make

- **No boot-time number.** TCG, no KVM. The brief forbids it and there is
  nothing here to base one on.
- **Not "faster than C".** The per-message state check at `9pdev.c:295` is a real
  branch that a C build keeps, so removing it is a real saving — but it is one
  compare on a path dominated by a virtqueue round trip, and there is no
  three-way benchmark. Not asserted.
- **Not "all fids are clunked before disconnect, in general."** Only for the LIFO
  nesting the type system tracks. Two files open at once is unspellable here, so
  the general question never arises — that is a *restriction*, not a proof about
  the unrestricted case. A future revision that admits sibling fids must
  re-answer it.
- **String provenance is not tracked, and I designed around that rather than
  claiming it.** `uk_9preq_readstr` (`9preq.h:411`) sets `val->data = (char
  *)req->recv.buf + req->recv.offset` — the version string **points into the
  request's receive buffer**, which `reply.release` returns to the freelist.
  Handing that pointer out as a Koru `string` would be a use-after-free this
  module *cannot* make a compile error, because Koru tracks obligations on
  handles and not provenance on strings. So `version` copies the bytes into the
  `*Dev`'s own storage, which outlives every fid and every request on the
  connection. If a later revision lifts `uk_9p_stat` or `uk_9p_readlink`, it
  inherits this hole and must solve it the same way.
- **No claim about concurrency.** One flow, one thread. If two threads shared a
  `*Dev`, the phantom states would say nothing; `uk9p`'s spinlocks would be
  doing all the work, and this module neither helps nor hinders.
- **No claim about a fid the transport still holds.** `uk_9pdev_req_lookup`
  calls `uk_9preq_get`, so a transport can hold a reference this lift does not
  know about. `was_last` *reports* the C's answer; nothing gates on it, and
  nothing here would catch a transport that never dropped its reference.
- **No ABI claim beyond one struct.** `struct uk_9pdev`, `struct uk_9preq` and
  `struct uk_9pfid` are `opaque {}` here and never dereferenced, so this module
  makes no claim about their layouts — which matters, because `struct uk_9pdev`'s
  `xmit_wq` exists only `#if CONFIG_LIBUKSCHED` (`9pdev_core.h:178`) and both its
  management sub-structs embed a `__spinlock` that is **size zero** without
  `CONFIG_HAVE_SMP`. That is the trap `unikraft/lock` measured the expensive way,
  and the strongest form of not falling into it is not needing the mirror. The
  one mirror that could not be avoided, `struct uk_9p_str`, has two
  unconditional scalar members and is **proved at run time** by the version
  echo, not asserted with `@offsetOf` alone.
- **Only virtio-9p was booted.** `drivers/xen/9pfront` registers the same
  transport interface and nothing here is virtio-specific, but I did not run it
  and do not claim it.
- **No short-write loop.** `uk_9p_write` may accept fewer bytes than offered;
  `file.write` reports the count and does not retry. Looping on the caller's
  behalf would turn a partial write into a silent whole one.

---

## What the toolchain got wrong

Nothing. No repro to pin.

Three things cost time and are ordinary API facts rather than defects, recorded
because the next contestant will hit them:

- **Punning is mandatory and enforced.** `reply.release(reply: v.reply)` is
  `PARSE005: redundant explicit label`. But `disconnect(mount)` where the
  parameter is `dev` is `PARSE006: an explicit label is required`. Both
  directions are checked.
- **A single-branch tor carrying a record payload must be a bare return.**
  `| ok { dev: *Dev<negotiated!>, was_last: bool }` is `PARSE003`; the form is
  `-> { dev: *Dev<negotiated!>, was_last: bool }`, which is what
  `330_096_obligation_in_record_field` uses.
- **The obligation diagnostic names the branch arm's OUTPUT FIELD, not the flow's
  binding.** `negative_reply_leaked.kz` binds the arm as `v` and the error says
  `Resource 'reply'`. Worth knowing before writing an expectation against a
  record-carrying branch.

Also worth recording, and not a Koru issue: **`blk`'s README build recipe no
longer works as written.** It says to copy the tests to a flat `/tmp/blk`, and
since the `~std/compiler:paths` block landed in every entry file, `{{ ENTRY
}}/../..` from a flat directory does not point at a module tree. The recipe at
the top of this file is the shape that does.

---

## Files

| | |
|---|---|
| `index.kz` | the lift — 14 tors, 4 handles, 11 states, one struct mirror |
| `tests/boot_session.kz` | the gate-2 artifact: a full 9P session against QEMU's server |
| `tests/negative_*.kz` | six misuses that fail to compile, one per nesting boundary |
| `tests/wrapper.zig` | C-ABI seam: `koru_main` calls each emitted flow |
| `tests/main.c` | Unikraft's boot path calls `main`; `main` calls `koru_main` |
