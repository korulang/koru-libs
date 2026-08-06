# unikraft/blk — Unikraft's block layer, with the assertions kept

`lib/ukblkdev` is Unikraft's block device API: 18 exported functions around a
four-state device machine with a request queue hanging off it. The ordering
between those states is written down 105 times as `UK_ASSERT`, and `UK_ASSERT`
expands to `do {} while(0)` whenever `CONFIG_LIBUKDEBUG_ENABLE_ASSERT` is off —
which is every image anyone ships.

This module transcribes that ordering into phantom obligations. The programs the
assertions were written to catch do not compile, and the emitted code carries no
check at all.

```koru
~import unikraft/blk

~unikraft/blk:get(id: 0)
| device disk |> unikraft/blk:configure(disk.dev)
    | ok cfg |> unikraft/blk:queue.open(dev: cfg, transfer: 1)
        | ok armed |> unikraft/blk:start(dev: armed)
            | ok run |> unikraft/blk:read(dev: run, sector: 0, sectors: 1)
                | data first |> …
```

---

## Why this target and not `uknetdev`

The brief names `uknetdev` the exemplar. I took its smaller sibling on purpose,
and the reason is a measurement, not a preference:

**`uknetdev`'s hot path is not linkable.** `uk_netdev_rx_one` and
`uk_netdev_tx_one` are `static inline` (`netdev.h:476`, `:546`) and produce no
symbol — `nm` on a built kernel with `LIBUKNETDEV=y` finds neither. A Koru lift
compiles to a freestanding Zig archive that is linked into the image afterwards,
so it can only reach symbols in `exportsyms.uk`. Binding netdev's per-packet
path would need either a C shim (an added call frame, against pillar 2) or a
hand-mirrored `struct uk_netdev` layout to reach `dev->rx_one` (an ABI guess on
the hottest path in the library). Neither is a thing to ship first.

`ukblkdev` exports its whole surface — `uk_blkdev_queue_submit_one` and
`uk_blkdev_queue_finish_reqs` are real `T` symbols — so the entire lifecycle,
transfers included, is provable end to end with nothing added. Same explicit
state machine, same nested queue sub-resource, same teardown ordering, and a
boot demo that reads a real sector, writes one, and shows the bytes.

Measured, `unikraft` HEAD `3fdffba8`:

| | `uknetdev` | `ukblkdev` |
|---|---:|---:|
| `UK_ASSERT` in the library | 170 | 105 |
| exported symbols | 33 | 18 |
| I/O path exported | **no** (`static inline`) | **yes** |

---

## The ratchet

One handle, eight states, one direction. Every arrow is one exported C call.

```
    get          mints  <attached!>                        uk_blkdev_get
    configure    needs  <!attached>   mints <configured!>  uk_blkdev_configure
    queue.open   needs  <!configured> mints <armed!>       uk_blkdev_queue_configure
    start        needs  <!armed>      mints <running!>     uk_blkdev_start
    read/write/  needs  <!running|!used>
    flush                             mints <used!>        uk_blkdev_queue_submit_one
    stop         needs  <!used>       mints <stopped!>     uk_blkdev_stop
    queue.close  needs  <!stopped>    mints <drained!>     uk_blkdev_queue_unconfigure
    release      needs  <!drained>                         uk_blkdev_unconfigure
```

Failure arms hand the handle back in the state that names the C cleanup still
owed, so the correct continuation is the only one that type-checks:

| tor | failure arm | why that state |
|---|---|---|
| `configure` | `<stuck!>` | nothing ran on the C side; only `abandon` accepts it |
| `queue.open` | `<drained!>` | device CONFIGURED with no queue — exactly what `queue.close` produces, so `release` is next |
| `start` | `<stopped!>` | device CONFIGURED with a live queue — exactly what `stop` produces, so `queue.close` is next |
| `read`/`write`/`flush` | `failed` → `<used!>` | the device errored; tear down or retry |
| `read`/`write`/`flush` | `rejected` → `<running!>` | the call never reached the device |
| `stop`/`queue.close`/`release` | `<stuck!>` | the driver refused; only `abandon` accepts it |

Two of those reuse a state the happy path already has. That is what keeps the
count at eight instead of fourteen, and it is faithful: a failed `start` really
does leave the device in the shape `stop` produces.

### The asymmetry (pillar 4)

`stop` accepts **only** `<!used>`, and `<used!>` is minted only by a transfer.
So this does not compile:

```koru
| ok run |> unikraft/blk:stop(dev: run)
```

You cannot spin a disk up, arm a virtqueue and tear it all down without ever
touching it. This is the block twin of gzip's `fed` gate (`gzip/index.kz:258` —
`finish` accepts only `<!fed>`, reachable only through `push`) and of
`2104_14_open_tx_commit_close/db.kz`, where `close` takes `<!active>` and not
`<!connected>`.

At the acquisition end the same rule holds: `get` mints `<attached!>` and the
only tor accepting `<!attached>` is `configure`. There is deliberately no
`blk:drop`. `get(); release();` is not a program that exists.

The escape hatch is explicit, named and greppable: **`blk:io.skipped`** mints
`<used!>` and runs no C call. A health check that only wants to know the device
starts says so in a word, and `grep -r "blk:io.skipped"` answers "which programs
bring up a disk and read nothing". The pair `negative_stop_without_transfer.kz`
/ `io_skipped_health_check.kz` is the proof that the gate costs the honest
program nothing.

### Where the ratchet is deliberately *not* applied

- **`count`** and the geometry take and mint nothing. Knowing how many disks
  there are constrains nothing about what you may do next.
- **The staging buffer is not a second obligation.** It is owned by the device
  handle, allocated at `queue.open`, freed at `queue.close`. `read`'s `bytes` is
  a *borrow* of it, valid until the next transfer or teardown — the same idiom
  as gzip's `finish` lending its output buffer until `release`. One live
  obligation per device, never two.
- **The failure arms on the transfer path consume rather than escalate.** A
  failed read hands back `<used!>` and nothing else changes. The brief's rule is
  that obligation-on-failure scales inversely with resource frequency; a device
  is rare (a failed `configure` gets a whole recovery state), a transfer is not
  (a failed read gets an errno and a reason).

The one place that costs something, stated plainly: `rejected` hands back
`<running!>` and **not** `<used!>`, because a transfer the lift refused before
submitting never touched the device and must not satisfy the gate. So an
oversize read spends the `used` you had earned. That is deliberate; the
alternative is a hole in the asymmetry.

---

## Which `UK_ASSERT`s this lift makes unnecessary

`lib/ukblkdev` carries 105 `UK_ASSERT`s: 90 in `blkdev.c`, 12 in `blkdev.h`, 3 in
`blkdev_driver.h`. Nineteen of them are about ordering. Here is every one, and
what happened to it.

### Lifted — the program that would trip it does not compile

| `blkdev.c` | assertion | what makes it unreachable |
|---|---|---|
| 368 | `start`: `state == CONFIGURED` | `start` consumes `<!armed>`, minted only by `queue.open`. No start-before-configure, no double start. |
| 391 | `submit_one`: `state == RUNNING` | `read`/`write`/`flush` take `<!running\|!used>`, unreachable before `start` and after `stop`. |
| 392 | `submit_one`: `_queue[id]` live | `<running!>` is reachable only through `queue.open`. |
| 405 | `finish_reqs`: `state == RUNNING` | same window. |
| 406 | `finish_reqs`: `_queue[id]` live | same. |
| 476 | `stop`: `state == RUNNING` | `stop` consumes `<!used>`; nothing mints `<used!>` outside the running window, and it is consumed once. |
| 502 | `queue_unconfigure`: `state == CONFIGURED` | `queue.close` takes `<!stopped>`, minted only by `stop`. |
| 503 | `queue_unconfigure`: `_queue[id]` live | `<stopped!>` is reachable only through `queue.open` → `start` → transfer → `stop`. |
| 550 | `unconfigure`: `state == CONFIGURED` | `release` takes `<!drained>`. |
| 551–552 | `unconfigure`: **loop** — every `_queue[q]` NULL | `<drained!>` is minted only by `queue.close`. The C runs this once per queue on every unconfigure; here it is the shape of the chain. |
| 297, 316, 390, 404, 445, 501 | `queue_id < CONFIG_LIBUKBLKDEV_MAXNBQUEUES` (×6) | the lift never takes a queue id from a caller; `QUEUE` is the constant 0 and `MAXNBQUEUES` is ≥ 1 by Kconfig. |

Twelve state/queue-liveness assertions plus six bounds checks.

The null-pointer family — `UK_ASSERT(dev)` (13), `UK_ASSERT(dev->_data)` (13),
`UK_ASSERT(dev->dev_ops)` (8) and friends, 45 in all — is also structurally
satisfied: `get` returns the `| missing` arm when `uk_blkdev_get` yields NULL,
so no null device pointer ever enters the chain, and Koru's `*Device` cannot be
null. I count these separately because they are hygiene, not ordering.

### Real runtime branches, not assertions — 2 of 3 become dead code

`ukblkdev` enforces three ordering rules with real `if`s that survive into
release builds:

| `blkdev.c` | branch | status |
|---|---|---|
| 324 | `queue_configure`: `state != CONFIGURED` → `-EINVAL` | **unreachable.** `queue.open` consumes `<!configured>`. |
| 328 | `queue_configure`: queue already live → `-EBUSY` | **unreachable.** `queue.open` consumes its input and mints `<armed!>`; it cannot be called twice on one handle. |
| 190 | `configure`: `nb_queues > max_queues` → `-EINVAL` | **not lifted.** A value comparison against a device-reported number; phantom states are symbolic, not value-dependent. It surfaces as `configure`'s `refused` arm. |

That is the ratio the brief points at, for this library: **19 ordering
assertions and 3 real branches**, of which 18 assertions and 2 branches become
things you cannot write.

### Not lifted, and why

- **`uk_blkdev_capabilities`: `state >= UK_BLKDEV_RUNNING`** (`blkdev.h:239`).
  This lift reads the geometry at `get`, before the C says you may. It has to:
  the sector size is what sizes a transfer, and a transfer must be sized before
  `queue.open`, which is before `start`. Both in-tree drivers populate
  `capabilities` before they register the device — virtio-blk in
  `virtio_blkdev_feature_negotiate` (`virtio_blk.c:951`, from `add_dev`) and xen
  blkfront in `blkfront_xb_get_capabilities` (`blkfront_xs.c:174`, from
  `blkfront_xb_init`) — so the field is final by the time any caller can hold
  the device. A driver that filled it later would hand out zeroes, so a zero
  sector size is **refused** at `get` rather than propagated.
- **The interrupt toggle pair** — `uk_blkdev_queue_intr_enable` /
  `_disable` and their 10 assertions (`blkdev.h:277-281`, `:305-309`). Both are
  `static inline` and absent from `exportsyms.uk`, so a separately-compiled
  archive cannot call them at all. This is the brief's "paired toggle" shape and
  it is the main thing I left on the table. See *The upstream deadlock*.
- **`uk_blkdev_drv_unregister`: `state == UNCONFIGURED`** (`blkdev.c:529`).
  Driver-side registration, not application surface.
- **`uk_blkdev_configure`'s `nb_queues` bound and this lift's own range checks**
  (`read` past the end of the device, transfer larger than the staging buffer).
  All value-dependent. They are runtime `rejected` arms with a `reason`, and
  they say so.

---

## Gate 2 — it boots

Full recipe, run clean in an empty directory. Traps and their evidence:
`/Users/larsde/src/koru/examples/unikraft/BUILD.md`.

```sh
cp tests/{boot_lifecycle.kz,wrapper.zig,main.c,mkdisk.py} /tmp/blk && cd /tmp/blk

koruc boot_lifecycle.kz unikraft gen        # -> Makefile.uk + Kraftfile
koruc boot_lifecycle.kz                     # -> output_emitted.zig
                                            #    (the host link then fails on the
                                            #     Unikraft symbols; that is expected)
zig build-lib wrapper.zig \
    -target x86_64-freestanding -O ReleaseSmall \
    -fno-stack-protector -femit-bin=libkoruapp.a
UK_CFLAGS="-std=gnu17" kraft build --arch x86_64 --plat qemu --no-prompt

python3 mkdisk.py disk.img
qemu-system-x86_64 -kernel .unikraft/build/koru_qemu-x86_64 \
  -cpu 'qemu64,+pdpe1gb,+rdrand,+rdseed,-vmx,-svm' \
  -m 64M -nographic -no-reboot -display none -parallel none \
  -drive file=disk.img,format=raw,if=none,id=d0 \
  -device virtio-blk-pci,drive=d0
```

Real console output, `\r` stripped, sector text elided in the middle only:

```
SeaBIOS (version rel-1.17.0-0-gb52ca86e094d-prebuilt.qemu.org)

iPXE (http://ipxe.org) 00:03.0 CA00 PCI2.10 PnP PMM+02FD1D10+02F31D10 CA00
Press Ctrl-B to configure iPXE (PCI 00:03.0)...

Booting from ROM..blk0: 64 sectors x 512 B, max 2032 sectors/req
read  s0: KORU DISK SECTOR ZERO -- planted by the host, read back by unikraft/blk from a real virtio-blk device. -------- … (512 B total)
read  s1: KORU WROTE SECTOR ONE THROUGH unikraft/blk -- submit_one + finish_reqs, no sync_io, no interrupt. ============ … (512 B total)
lifecycle complete
```

`s0` is what the host planted. `s1` is what the unikernel wrote and then read
back, and it is on the host file afterwards:

```
$ dd if=disk.img bs=512 skip=1 count=1 | head -c 98
KORU WROTE SECTOR ONE THROUGH unikraft/blk -- submit_one + finish_reqs, no sync_io, no interrupt.
```

The chain exercised: `get → configure → queue.open → start → read → write →
flush → read → stop → queue.close → release`. The second `read` is what proves
`<!running|!used>` re-entry.

| | |
|---|---:|
| Koru freestanding static archive | 20,568 B |
| bootable unikernel image | 194,048 B |
| baseline (`examples/unikraft/hello.kz`, no blkdev) | 164,544 B |

No boot-time number. Everything here is QEMU TCG on arm64 with no KVM, and this
project does not have a boot-time claim to make.

### Pillar 2 — what the lifting costs at runtime

Nothing. `objdump` of `koru_main` in the built image, first instructions:

```
000000000010fa98 <koru_main>:
  10fa98:  push   %rbp
  ...
  10faac:  xor    %edi,%edi
  10faae:  call   115704 <uk_blkdev_get>
  10fab3:  test   %rax,%rax
  10fab6:  je     10fbf5 <koru_main+0x15d>
```

The whole flow inlines into one function, and the ukblkdev calls come out in
source order — `uk_blkdev_get`, `malloc`, `uk_blkdev_configure`,
`uk_blkdev_queue_get_info`, `memalign`, `uk_blkdev_queue_configure`,
`uk_blkdev_start`, … — interleaved only with the `memcpy`/`fputs` pairs that are
the caller's own `print.ln`s. There is no state variable, no state comparison,
no dispatch table. `test %rax,%rax` is the NULL check `uk_blkdev_get` genuinely
needs — the `| missing` arm.

In the emitted Zig, every occurrence of a phantom state name is a comment or a
local variable the *flow* chose to call `drained`. The states have no runtime
representation.

### The honest claim, and the one I am not making

Koru dissolves Unikraft's asserts-on / asserts-off tradeoff for the ordering
rules above: assert-on guarantees at assert-off cost. That is what the
disassembly shows.

It is **not** "faster than C". The per-call state check is a `UK_ASSERT` and
already compiles out in release. Demonstrating the dissolution properly needs a
three-way benchmark — asserts-on C, asserts-off C, proven Koru — which does not
exist. I did not build it.

---

## Gate 3 — four misuses that fail to compile

Phantom validation fires in the **emit** pass, not in `--check`. Every one of
these passes `koruc --check` and is refused by `koruc <file>`. Diagnostics are
verbatim.

**`negative_stop_without_transfer.kz`** — the asymmetry. Bring a disk up, tear
it down, never touch it.

```
$ koruc --check negative_stop_without_transfer.kz
✓ Shape checking passed

$ koruc negative_stop_without_transfer.kz
error[KORU030]: Phantom state mismatch: expected 'unikraft.blk:used' but got 'unikraft.blk:running!' for argument 'dev'
  --> negative_stop_without_transfer.kz:27:0
❌ Compiler coordination error: Phantom semantic validation failed
```

The C cannot object to this program. `uk_blkdev_stop`'s guard is
`UK_ASSERT(state == UK_BLKDEV_RUNNING)`, which is *satisfied* — the device
really is running — and compiled out anyway.

**`negative_read_after_stop.kz`** — a transfer on a stopped device.

```
error[KORU030]: Phantom state mismatch: expected '!unikraft.blk:running|!unikraft.blk:used' but got 'unikraft.blk:stopped!' for argument 'dev'
```

**`negative_release_skips_queue_close.kz`** — unconfigure with the queue still
live; the C's loop assertion at `blkdev.c:551-552`.

```
error[KORU030]: Phantom state mismatch: expected 'unikraft.blk:drained' but got 'unikraft.blk:stopped!' for argument 'dev'
```

**`negative_device_never_discharged.kz`** — take a device and walk away.

```
error[KORU030]: Resource 'dev' obligation <attached!> was not discharged. Call: configure
❌ Compiler coordination error: Auto-discharge failed (multiple disposal options or no disposal event)
```

And the control, `io_skipped_health_check.kz`: the same chain as the first
negative with `blk:io.skipped` in it, compiling clean through the emit pass.

---

## The upstream deadlock

`uk_blkdev_sync_io` is exported, does exactly what this lift's transfer path
does, and **deadlocks on the second request of any program**. This lift does not
use it.

The chain: `virtio_blkdev_recv_done` (`virtio_blk.c:469`) disables the queue
interrupt on entry and clears `VTBLK_INTR_EN`.
`virtio_blkdev_complete_reqs` (`:448`) re-arms it only if the application
previously set `VTBLK_INTR_USR_EN`, which only `uk_blkdev_queue_intr_enable`
does — and that is `static inline` (`blkdev.h:274`) and absent from
`exportsyms.uk`. So exactly one interrupt fires, ever. `sync_io` submits, blocks
on its semaphore, and nothing ever ups it again.

**Localised before attributing.** The symptom first appeared in the Koru boot
demo, which hung after printing sector 0. The same three transfers written
straight in C, in the same image, hang at the same point:

```
CTRL read0 rc=0 'KORU DISK SECTOR ZERO --'
CTRL submitting write...
        <hangs>
```

Rewritten as `uk_blkdev_queue_submit_one` + a poll on `uk_blkdev_queue_finish_reqs`,
with a counter on the queue event callback:

```
POLL read0  submit=0x3 ok=1   done after 0 spins, result=0 events=1
POLL write1 submit=0x3 ok=1   done after 1 spins, result=0 events=1
POLL read1  submit=0x3 ok=1   done after 1 spins, result=0 events=1
POLL read1 got 'C-CONTROL-WROTE-SECTOR-1'
```

`events` never passes 1: one interrupt, then none. Nothing about Koru is
involved.

So `blk:read`/`write`/`flush` submit and reap over the two exported queue calls,
and the queue is configured with a **null** event callback (legal —
`blkdev.c:231`; makes `uk_blkdev_drv_queue_event` a no-op,
`blkdev_driver.h:93`). Nothing runs in interrupt context, so there is no
reentrancy on the virtqueue. Three consequences, all good: the image does not
need `CONFIG_LIBUKBLKDEV_SYNC_IO_BLOCKED_WAITING` and therefore drags in neither
`LIBUKSCHED` nor `LIBUKLOCK`; the assertions lifted are the same ones one layer
down (`blkdev.c:391/392/405/406` instead of `:448/449`); and the wait is a busy
poll.

The poll is unbounded, exactly as `uk_blkdev_sync_io`'s `uk_semaphore_down` is.
A timeout would be a policy the C does not have and an arm that lies about what
happened. It does bail loudly if `finish_reqs` itself returns an error.

One incidental correctness note: Unikraft's own `uk_blkdev_status_successful` is
`(status & 0x1)`, which reads TRUE for any odd negative errno — `-EIO` is `-5`
and `-5 & 1 == 1`. This lift checks the sign first.

---

## The one place ukblkdev cannot be bound

`struct uk_blkdev.capabilities` (`blkdev_core.h:295`) holds the geometry, and
the only accessor is `static inline`. `uk_blkdev_get_info` returns `max_queues`
and nothing else. So a separately-compiled archive must know where the field
sits.

The lift mirrors the public prefix of `struct uk_blkdev` and `struct
uk_blkdev_cap` as Zig `extern struct`s, with `comptime` offset assertions that
turn a layout change into a compile error rather than silent corruption. The
same is done for `struct uk_blkreq`, which the lift allocates and fills itself.
Every offset was **measured**, not derived: a C probe compiled by Unikraft's own
build with the real headers, printing `offsetof`, booted in the same image:

```
LAYOUT sizeof(uk_blkdev)=96 off(submit_one)=0 off(finish_reqs)=8 off(_data)=16 off(capabilities)=24 off(dev_ops)=64
LAYOUT sizeof(cap)=40 off(sectors)=0 off(ssize)=8 off(mode)=16 off(maxspr)=24 off(ioalign)=32
LAYOUT sizeof(queue_conf)=24 maxnbq=1
BLKREQ size=56 op=0 start=8 nb=16 buf=24 cb=32 cookie=40 state=48 result=52
```

This is the honest cost of binding at the native altitude from outside the
build. It is stated here rather than hidden because a wrong offset here reads
garbage geometry, and the comptime block is what makes that loud.

---

## What the toolchain got wrong

Three defects surfaced by writing this. None is worked around inside the lift;
`index.kz` is untouched by all three.

### 1. An empty `Source` block emits invalid Zig

```koru
~import unikraft
~unikraft:image(name: "koru") { }
```

```
backend_output_emitted.zig:126:102: error: expected expression, found ','
        _ = koru_unikraft.image_event.handler(.{ .name = "koru", .source = __koru_ast.Source{ .text =
                                                                                                     ^
```

`src/emitter_helpers.zig:7650-7670` writes `.text = \n`, then one `\\`-prefixed
Zig multiline-string line per line of the block body, then `, .scope = …`. An
empty body produces zero lines and the field is left with no initializer. It
wants an empty-string literal for the empty case.

Anything with a `Source` parameter and an optional body hits this — it is not
specific to `unikraft:image`. Worked around in the demo by giving the block a
real body (`-DKORU_UNIKRAFT_BLK=1`), which is documented at the site.

### 2. `import <alias>/<child>` silently imports `<alias>` too, and importing both double-emits it

`~import unikraft/blk` alone makes `~unikraft:image(…)` resolve and the
`unikraft gen` command register — with no `~import unikraft` line anywhere.
Writing that line as well registers the module twice, and the comptime backend
fails:

```
backend_output_emitted.zig:8526:11: error: duplicate struct member name 'std'
backend_output_emitted.zig:8581:15: error: duplicate struct member name 'unikraft_event'
backend_output_emitted.zig:8726:15: error: duplicate struct member name 'image_event'
backend_output_emitted.zig:8744:15: error: duplicate struct member name 'kconfig_event'
```

Controls run, because the first place this appeared was my own module:

| program | result |
|---|---|
| `~import unikraft/blk` alone, calling `~unikraft:image` | **compiles** — the parent is in scope unasked |
| no unikraft import at all, calling `~unikraft:image` | `error[KORU040]: unknown tor 'unikraft:image'` |
| `~import unikraft` + `~import unikraft/_probe` (a two-line trivial child) | **duplicates** — nothing to do with `blk` |
| `~import unikraft` + `~import p/sub` (unrelated child, local `koru.json` alias) | compiles |
| `~import p` + `~import p/sub` (generic parent + child, both trivial) | compiles |
| `~import p/sub` alone, calling `~p:top()` | **compiles** — the implicit load is generic |

So the implicit parent load is general behaviour; the duplicate-member failure
is what happens when the implicitly-loaded parent also declares comptime tors
and you name it explicitly. `boot_lifecycle.kz` therefore has no
`~import unikraft` line, with the reason written at the top of the file. The
silent half is arguably the worse one: an import you did not write is in scope.

### 3. `print.ln` truncates a `string` at the first NUL

The write primitive on freestanding is `fputs` (confirmed in the disassembly of
`koru_main`), so a `string` carrying binary data is cut at the first zero byte —
and the trailing newline `print.ln` appends after the payload goes with it. A
512-byte sector read whose content was 43 bytes plus padding printed 43 bytes
and then ran into the next line:

```
read  s1: koru wrote this sector through unikraft/blklifecycle complete
```

Silent truncation of a slice whose length is known. `boot_lifecycle.kz` writes a
full 512-byte payload so the console shows the whole transfer, which is a better
demo anyway — but the truncation is a real defect and this is where it was
found.

---

## What I left out

- **Multi-queue.** `CONFIG_LIBUKBLKDEV_MAXNBQUEUES` defaults to 1 and virtio-blk
  reports `max_queues=1`, so the lift models one request queue and never asks
  the caller for a queue id. Modelling N queues means N sub-obligations on one
  device, and the interesting part — what happens when you close queue 1 and
  forget queue 0 — is exactly the `unconfigure` loop assertion, which is already
  lifted by the single-queue chain. I would want to design that against a device
  that actually has more than one.
- **The interrupt toggle** (`queue_intr_enable`/`disable`). Not exposed by
  Unikraft; see *The upstream deadlock*. This is the "paired toggle" obligation
  shape the brief lists, and it is the one I could not write.
- **Asynchronous I/O.** `submit_one` without waiting — a transfer in flight is a
  genuine obligation (the request buffer must outlive the device's use of it)
  and it is the natural next state to add. The current transfer path submits and
  reaps in one tor, so there is no in-flight state to hold.
- **The three-way benchmark** that would let anyone say "assert-on guarantees at
  assert-off cost" with numbers.
- **A merged `configure`.** `configure` + `queue.open` could be one tor, and
  `queue.close` + `release` its mirror, making four more assertions
  structurally impossible instead of type-checked. I kept them apart because the
  queue has its own failure mode (`-EBUSY`) and its own teardown ordering rule,
  and because keeping it visible is what makes release-before-queue-close a
  compile error rather than something my library merely happens not to do.

---

## Files

| | |
|---|---|
| `index.kz` | the lift |
| `tests/boot_lifecycle.kz` | gate 2 — the full chain, in a unikernel, against a real disk |
| `tests/io_skipped_health_check.kz` | the named escape from the asymmetry gate |
| `tests/negative_stop_without_transfer.kz` | gate 3 — the asymmetry |
| `tests/negative_read_after_stop.kz` | gate 3 — use after teardown |
| `tests/negative_release_skips_queue_close.kz` | gate 3 — teardown out of order |
| `tests/negative_device_never_discharged.kz` | gate 3 — leak |
| `tests/wrapper.zig`, `tests/main.c` | the C-ABI seam, from `koru/examples/unikraft` |
| `tests/mkdisk.py` | the 32 KB virtio-blk backing file the demo expects |

Measured against `unikraft` HEAD `3fdffba8`, kraftkit 0.12.15, Unikraft 0.21.0
"Ijiraq", zig 0.15.2, on macOS/arm64.
