# unikraft/net — Unikraft's network layer, lifecycle *and* transfers

**This is not a naive wrap.** The lift's whole surface — bring-up and the
per-packet path — goes through phantom obligations, the `struct uk_netdev` mirror
that the transfers need is proved at run time by four independent witnesses
before the first indirect call, and the census below reports **23 of 170**
`UK_ASSERT`s retired per site, with the other 147 named and reasoned.

`lib/uknetdev` carries **170 `UK_ASSERT`s — the most of any library in the
Unikraft tree** — around a five-state device machine (INVALID → UNPROBED →
UNCONFIGURED → CONFIGURED → RUNNING) with an rx queue, a tx queue, and a packet
buffer whose ownership moves between caller and driver on every transfer.
`UK_ASSERT` expands to `do {} while(0)` whenever `CONFIG_LIBUKDEBUG_ENABLE_ASSERT`
is off, which is every image anyone ships.

```koru
~import unikraft/net

~unikraft/net:get(id: 0)
| link a |> unikraft/net:probe(a.dev)
    | ok p |> unikraft/net:configure(dev: p)
        | ok c |> unikraft/net:queues.open(c.dev)
            | ok q |> unikraft/net:start(dev: q)
                | ok r |> unikraft/net:tx(dev: r, to: "ff:ff:ff:ff:ff:ff",
                                          ethertype: 34997, payload: "…")
```

The caller never sees a `struct uk_netdev *`, never names a queue id, never asks
what its own MAC address is, and cannot spell a call out of order.

---

## This entry supersedes the shelf row it was written under

The `uknetdev` shelf row said the transfers were reachable and asked a contestant
to prove the mirror. It is proved, and one thing the row could not know is
corrected here: **`uknetdev` has no teardown at all.** All 33 lines of
`exportsyms.uk` are acquire, configure, query or transfer — there is no
`uk_netdev_stop`, no `unconfigure`, no application-side `unregister`. That is not
a footnote; it is the shape of the lift. `unikraft/blk`'s ratchet ends in three
teardown calls, and this one ends in a tor that makes **no C call at all**.

It also corrects `unikraft/blk`'s README, which wrote `uknetdev` off in 2026-08-06
with "binding netdev's per-packet path would need either a C shim … or a
hand-mirrored `struct uk_netdev` layout … Neither is a thing to ship first." The
second half was the right instrument, not the disqualifier: three lifts have paid
the mirror cost since, and here it is paid with a stronger proof than any of them
got. `blk`'s reading was correct *for a first lift* and is wrong as a verdict on
the target.

---

## The ratchet

One device handle, seven states, one direction. Every arrow is one exported C
call except the last, which is deliberately none.

```
    get          mints <found!>                          uk_netdev_get
    probe        needs <!found>       mints <probed!>     uk_netdev_probe
    configure    needs <!probed>      mints <configured!> uk_netdev_configure
    queues.open  needs <!configured>  mints <armed!>      uk_netdev_rxq_configure
                                                        + uk_netdev_txq_configure
    promiscuous  needs <!armed>       mints <armed!>      uk_netdev_promiscuous_set
    start        needs <!armed>       mints <running!>    uk_netdev_start
    tx / rx      needs <!running|!carried>
                                      mints <carried!>    dev->tx_one / dev->rx_one
    park         needs <!carried>                         (nothing — see below)
```

And one packet obligation, minted only by a receive:

```
    rx           mints <received!> on the packet          (the netbuf rx_one gave)
    packet.drop  needs <!received>                        uk_netbuf_free
```

Failure arms hand the device handle back in the state that names what is legal
next. There is exactly **one** such state — `<stuck!>` — and that is faithful
rather than lazy: with no teardown, every bring-up failure has the same recovery.
`net:abandon` is it.

| tor | failure arm | state |
|---|---|---|
| `probe` / `configure` / `queues.open` / `start` | `refused` | `<stuck!>` — only `abandon` accepts it |
| `promiscuous.set` | `unsupported` | `<armed!>` — the driver has no setter, so **nothing happened** |
| `promiscuous.set` | `refused` | `<stuck!>` |
| `tx` | `dropped` | `<carried!>` — the frame reached the device and was refused |
| `tx` | `rejected` | `<running!>` — the call never reached the device |
| `rx` | `empty` / `failed` | `<carried!>` — the queue was polled |

`rejected` hands back `<running!>` and **not** `<carried!>` on purpose: a frame
the lift refused before submitting never touched the wire, so it must not satisfy
the asymmetry gate. The cost is real and deliberate — a malformed destination
address spends nothing, and a program that only ever calls `tx` with a bad MAC
still cannot `park`.

### The asymmetry (pillar 4), and why it is sharper here than on a disk

`park` accepts **only** `<!carried>`, and `<carried!>` is minted only by a
transfer. So this does not compile:

```koru
| ok r |> unikraft/net:park(dev: r)
```

You cannot probe a NIC, negotiate its features, allocate a receive ring of
`nb_max` buffers, arm two virtqueues and then walk away without moving a frame.
This is the network twin of gzip's `fed` gate (`gzip/index.kz:258` — `finish`
accepts only `<!fed>`, minted only by `push`) and of
`2104_14_open_tx_commit_close/db.kz`, where `close` takes `<!active>` and not
`<!connected>`.

It bites harder than `blk`'s because the resource is never given back. A disk you
spin up and never read gets `uk_blkdev_stop`/`unconfigure` and the memory returns.
An interface you bring up and never use keeps its ring — `nb_max` netbufs, 256 of
them on QEMU virtio-net — for the life of the machine, because **nothing frees
it**. There is no C call that could.

At the acquisition end the same rule holds: `get` mints `<found!>` and the only
tor accepting `<!found>` is `probe`. There is deliberately no `net:drop`.
`get(); park();` is not a program that exists — see
`tests/negative_device_never_discharged.kz`.

The escape is explicit, named and greppable: **`net:traffic.skipped`** mints
`<carried!>` and runs no C call. `grep -r "net:traffic.skipped"` answers "which
programs bring up a NIC and move no traffic". The pair
`tests/negative_park_without_traffic.kz` / `tests/boot_link_check.kz` is the proof
that the gate costs the honest program nothing — the second one boots.

---

## Where the obligation line is drawn: packet versus device

The brief warns that obligation-on-failure scales inversely with resource
frequency, and says `uknetdev` is the first target with both a rare resource and
a hot one. Here is the line, and every reason for it comes from the C rather than
from taste.

**The device is rare and gets the ratchet.** Seven states, every failure arm
carrying a recovery state, four run-time witnesses on the mirror before the hot
path is touched. All of it runs once per interface per boot.

**A transmitted packet is not an obligation at all.** `uk_netdev_tx_one`'s
contract (`netdev.h:531`) is that *the driver* frees the netbuf once the device
is done with it. Ownership transfers inside one call, so `tx` takes `bytes`:
it allocates the netbuf, writes the Ethernet header and the payload, submits, and
the driver frees. On the one path where the driver hands the frame back —
`-ENOSPC`, where `virtio_net.c:503-506` removes its own prepended header and
leaves the netbuf intact — **this lift frees it and returns `| dropped` with a
reason.** That is the brief's "a failure on a hot resource should consume", and
it is not a lie about the C: the driver declined to make a drop policy, and
making one silently retry behind the caller's back would be worse than making it
loud. The per-packet path gains zero states and zero calls.

**A received packet is an obligation, because nothing else can be true.**
`rx_one` hands out a netbuf the caller must give back with `uk_netbuf_free`, and
the caller holds it for as long as it is reading the payload. No single call can
contain that. `<received!>` is the only leakable thing in this module.

**The asymmetry gate is deliberately NOT applied to the received packet.** `rx`
returns the handle and the decoded frame in the *same arm*, so "received but
never looked at" is not a state a program can reach; a `<read!>` state between
`<received!>` and `drop` would guard nothing and would put a call on the hottest
path in the library. That is the brief's own *not everything deserves a ratchet*
rule, applied where it belongs: **the ratchet is the device's, the packet carries
an obligation and no ceremony.**

### What the compiler actually does with the packet obligation, measured

It does **not** produce an error for a forgotten `packet.drop`. It inserts the
call. A program that receives a frame, prints the payload and never drops it
emits, at `output_emitted.zig:91`:

```zig
_ = koru_unikraft.koru_net.packet_drop_event.handler(.{ .pkt = f.pkt });
```

`<received!>` has exactly one disposal tor, so auto-discharge succeeds. That is
the right outcome and it is a *stronger* claim than a compile error would be:
**a received netbuf cannot leak, and the honest program is not asked to say so.**
The negative I first wrote for this was therefore wrong and was deleted;
`tests/negative_tx_after_park.kz` replaced it, testing the thing that genuinely
cannot be auto-repaired — use after discharge.

The device obligation behaves differently and correctly: `<found!>` and
`<running!>` have no disposal tor at all, so neither can be auto-discharged.

### Where the ratchet is deliberately not applied

- **`count`, and the geometry in `configure`'s payload** (MTU, hardware address,
  maximum payload) take and mint nothing. Reading them constrains nothing about
  what may happen next, and handing them out is what lets `tx` take bytes.
- **The Ethernet header is not a resource.** `tx` writes it, `rx` decodes it,
  neither creates state.
- **The receive ring is not an obligation.** It is owned by the device for the
  device's whole life, which is the machine's whole life.

---

## Which `UK_ASSERT`s this lift makes unnecessary

`lib/uknetdev` carries exactly **170** `UK_ASSERT`s: 101 in `netdev.c`, 24 in
`netdev.h`, 20 in `netbuf.c`, 14 in `netbuf.h`, 8 in `stats.c`, 3 in
`netdev_driver.h`. Every one is accounted for below and the four buckets sum to
170.

### Lifted — ordering. The program that would trip it does not compile. (9)

| site | assertion | what makes it unreachable |
|---|---|---|
| `netdev.c:253` | `probe`: `state == UNPROBED` | `probe` consumes `<!found>`, minted only by `get`. No probe-before-get, **no double probe** — and on virtio the probe callback is feature negotiation. |
| `netdev.c:271` | `info_get`: `state >= UNCONFIGURED` | `info_get` runs only inside `configure`, which takes `<!probed>`. |
| `netdev.h:484` | **`rx_one`: `state == RUNNING`** | `rx` takes `<!running\|!carried>`, unreachable before `start`. The headline: an assertion in the per-packet path. |
| `netdev.h:485` | `rx_one`: `_rx_queue[qid]` live and not `PTRISERR` | `<armed!>` is minted only by `queues.open`, which reads the slot back and refuses if it is null. |
| `netdev.h:554` | **`tx_one`: `state == RUNNING`** | `tx` takes `<!running\|!carried>`. |
| `netdev.h:555` | `tx_one`: `_tx_queue[qid]` live and not `PTRISERR` | same as `:485`, via the derived transmit slot. |
| `netdev.c:642` | `hwaddr_get`: `CONFIGURED \|\| RUNNING` | called only inside `configure` and `tx`, both past `<!probed>`. |
| `netdev.c:676` | `promiscuous_set`: `CONFIGURED \|\| RUNNING` | `promiscuous.set` takes `<!armed>`, reachable only through `configure`. |
| `netdev.c:695` | `mtu_get`: `CONFIGURED \|\| RUNNING` | called only inside `configure`. |

### Lifted — bounds, because no caller ever supplies a queue id. (6)

`netdev.c:362`, `:376`, `:524`, `:573` and `netdev.h:483`, `:553`, all
`queue_id < CONFIG_LIBUKNETDEV_MAXNBQUEUES`. The lift uses the constant 0 and
*derives* `MAXNBQUEUES` at run time (see the mirror proof), so it also knows the
bound rather than assuming it.

### Lifted — argument preconditions the lift owns instead of the caller. (8)

| site | assertion | why |
|---|---|---|
| `netdev.c:526` | `rxq_configure`: `rx_conf->alloc_rxpkts` | the lift always supplies its own receive-buffer allocator; a caller cannot omit it. |
| `netdev.h:482` | `rx_one`: `dev->rx_one` | `get` returns `\| missing` when the mirrored `rx_one` reads null. |
| `netdev.h:552` | `tx_one`: `dev->tx_one` | same. |
| `netdev.h:487` | `rx_one`: `pkt` | the lift owns that pointer; it is a local. |
| `netdev.h:557` | `tx_one`: `pkt` | same. |
| `netbuf.c:131` | `alloc_buf`: `buflen > 0` | the lift computes both operands from the device's own geometry. |
| `netbuf.c:132` | `alloc_buf`: `headroom <= buflen` | same. |
| `netbuf.c:285` | `free`: `!m->prev` | only `rx`'s chain head ever reaches `packet.drop`. |

**23 assertions retired**, per site, of which the two that matter most are the
per-packet state checks at `netdev.h:484` and `:554`.

### Structurally satisfied — null and liveness hygiene. (54)

The `UK_ASSERT(dev)` / `UK_ASSERT(dev->_data)` / `UK_ASSERT(dev->ops)` family on
the fourteen API functions this lift calls: `netdev.c` 224–225, 232–233, 240–241,
250–252, 267–270, 359–361/363, 373–375/377, 390–394, 520–523/525, 568–572,
596–599, 635–637, 669–671, 687–690 (50), plus `netdev.h:481`, `:551` and
`netbuf.c:166`, `:284`. `get` returns `| missing` when `uk_netdev_get` yields NULL
or when `_data` reads null through the mirror, and a Koru `*Device` cannot be
null. Counted separately from the 23 because they are hygiene, not ordering —
this is the distinction `unikraft/blk`'s README drew and it is the right one.

### Not lifted, with reasons. (93)

| where | count | why not |
|---|---:|---|
| `netdev.c` `uk_netdev_drv_register` + the `_data` check in `uk_netdev_get` | 16 | driver registration, not application surface. |
| `netdev.c` `uk_netdev_einfo_get` | 3 | **not bound.** The extended-info interface hands out driver-provided IP configuration strings; it is a network-stack concern and this lift stops at the frame. |
| `netdev.c` `_dispatcher` / `_create_event_handler` / `_destroy_event_handler`, and `:528` | 8 | libuknetdev's internal event-handler machinery. Most are `CONFIG_LIBUKNETDEV_DISPATCHERTHREADS`-only and compile out entirely in this config. |
| `netdev.c` `uk_netdev_hwaddr_set` | 5 | **not bound.** virtio-net's ops table (`virtio_net.c:1411`) has no `hwaddr_set`, so the only arm this hardware can produce is `-ENOTSUP`, and the assertion at `:624` would be lifted by exactly the same argument as `:642`. Left out rather than shipped unexercised. |
| `netdev.c` `uk_netdev_promiscuous_get` | 5 | **not bound.** A pure query with no effect on what is legal next; the setter is bound and its assertion is lifted. |
| `netdev.c` `uk_netdev_mtu_set` | 4 | **not bound.** virtio-net has no `mtu_set` either. |
| `netdev.h` `uk_netdev_rxq_intr_enable` / `_disable` | 12 | **INERT — case 5 of the brief's linkability rule.** Both are listed in `exportsyms.uk` *and* `static inline` (`netdev.h:395`, `:424`), so the compilation unit emits no global and objcopy has nothing to keep. A separately-linked archive cannot call them at any price. This is the paired-toggle obligation shape and it is the main thing left on the table — see *What I left out*. |
| `netdev_driver.h` `uk_netdev_drv_rx_event` | 3 | driver-side. |
| `stats.c` | 8 | `CONFIG_LIBUKNETDEV_STATS` is off in every image these lifts build; the whole file compiles out. |
| `netbuf.h` | 14 | `static inline` helpers this lift does not call: `get_priv`, `ref`, `ref_single`, `refcount_single_get`, `headroom`, `tailroom`, `header`. Reachable (they are MIRROR), simply not needed. |
| `netbuf.c` `sglist_append`, `init_indir`, `disconnect`, `connect`, `append`, `free_single` | 15 | chain and scatter-gather surface this lift does not expose. See *What I left out* on netbuf chains. |

**9 + 6 + 8 + 54 + 93 = 170.**

### Real runtime branches, not assertions

`uknetdev` also enforces ordering with real `if`s that survive `-DNDEBUG`. Four
of the six become dead code:

| `netdev.c` | branch | status |
|---|---|---|
| 396 | `configure`: `state != UNCONFIGURED` → `-EINVAL` | **unreachable.** `configure` consumes `<!probed>`. |
| 532 | `rxq_configure`: `state != CONFIGURED` → `-EINVAL` | **unreachable.** `queues.open` consumes `<!configured>`. |
| 575 | `txq_configure`: `state != CONFIGURED` → `-EINVAL` | **unreachable**, same call. |
| 601 | `start`: `state != CONFIGURED` → `-EINVAL` | **unreachable.** `start` consumes `<!armed>`. |
| 537 / 580 | `rxq_configure` / `txq_configure`: queue already live → `-EBUSY` | **unreachable.** `queues.open` consumes its input and mints `<armed!>`; it cannot run twice on one handle. |
| 400 / 402 | `configure`: `nb_rx_queues > max_rx_queues` → `-EINVAL` | **not lifted.** A value comparison against a device-reported number; phantom states are symbolic, not value-dependent. It surfaces as `configure`'s `refused` arm. |

---

## The mirror, and how it is proved before it is used

`uk_netdev_rx_one` and `uk_netdev_tx_one` are `static inline` (`netdev.h:476`,
`:546`) and emit no symbol. With `UK_ASSERT` compiled out and
`CONFIG_LIBUKNETDEV_STATS` off — the config this lift builds — the entire body of
`uk_netdev_rx_one` is

```c
ret = dev->rx_one(dev, dev->_rx_queue[queue_id], pkt);
```

which is offsets, not symbols: the MIRROR case. Four witnesses run before the
first indirect call, and each one refuses loudly rather than degrading.

**W1 — value witness, at three different values.** `uk_netdev_state_get` is
exported and returns `dev->_data->state`. `get` reads the state through the
mirror and requires it to equal the accessor **and** to be `UNPROBED`; `probe`
requires the same agreement at `UNCONFIGURED`; `start` at `RUNNING`. Agreement at
three distinct values is not something a wrong offset produces. This pins `_data`
at 16 and `state` at 0 — and `state` is the *first* member of
`struct uk_netdev_data`, ahead of the Kconfig-sized `rxq_handler[]` array, so the
witness needs no Kconfig knowledge.

**W2 — call-through witness.** `configure` reads `ops->mtu_get` through the
mirror, **calls it**, and requires the answer to equal the exported
`uk_netdev_mtu_get`. That pins `ops` at 24 and `mtu_get` at 32 within
`struct uk_netdev_ops`.

**W3 — derivation, not assumption, of the one Kconfig offset.** `_tx_queue` sits
at `32 + 8 × CONFIG_LIBUKNETDEV_MAXNBQUEUES`, and that integer has no symbol —
exactly the case-3 **NO** hazard the brief warns about. `queues.open` does not
assume it. It configures the rx queue, confirms the word at offset 32 turned
non-null, configures the tx queue, then scans forward for the first word that is
now non-null. `_rx_queue[1..]` are all still null because only queue 0 was
configured, so the first hit **is** `_tx_queue[0]`, and its distance from
`_rx_queue[0]` **is** `MAXNBQUEUES`. The scan stops at the first hit, so nothing
past the transmit slot is ever read; if the answer is not in 1..16 the tor
refuses. This is `unikraft/vmem`'s behavioural-probe instrument applied to a
struct offset.

**W4 — declaration order from a proven anchor, and this one is a derivation, not
an observation.** `tx_one` and `rx_one` are the two pointers declared before
`_data` (`netdev_core.h:509-520`) and nothing Kconfig-conditional precedes them.
With `_data` pinned at 16 by W1 and `ops` at 24 by W2, offsets 0 and 8 are the
only places two pointers can be. There is **no exported accessor for either**, so
no stronger witness exists; the behavioural backstop is that a wrong pointer here
jumps through a heap address and triple-faults, and the image boots and moves
frames. Stated as a derivation because it is one.

Every field this lift touches sits at offset ≤ 40, **ahead of every
Kconfig-conditional member** of `struct uk_netdev` (`_einfo`, `scratch_pad`,
`_stats`, `_stats_lock` are all at the tail, `netdev_core.h:528-541`), so the
mirror does not move when those flip.

### The probe

Every offset in `index.kz` was measured, not derived from reading. A `main.c` that
prints `offsetof`/`sizeof` and nothing else, compiled by Unikraft's own build with
the real headers and booted in QEMU:

```
PROBE uk_netdev sizeof=64
PROBE off tx_one=0 rx_one=8 _data=16 ops=24 _rx_queue=32 _tx_queue=40
PROBE MAXNBQUEUES=1
PROBE netdev_data sizeof=40 state_off=0 id_off=24 drvname_off=32
PROBE netbuf sizeof=96 buf=48 buflen=56 len=32 data=24 refcount=36 next=0 flags=16 priv=40 dtor=72 a=80 b=88
PROBE ops sizeof=136 mtu_get=32 promiscuous_get=56 rxq_intr_enable=0
PROBE info sizeof=20 max_rx=0 max_tx=2 inqp=4 max_mtu=8 enc_tx=10 enc_rx=12 ioalign=14 feat=16
PROBE rxqconf sizeof=40 cb=0 cookie=8 a=16 alloc=24 argp=32
PROBE txqconf sizeof=8
PROBE qinfo sizeof=12
PROBE conf sizeof=6 nbrx=0 nbtx=2 lro=4
PROBE states INVALID=0 UNPROBED=1 UNCONFIGURED=2 CONFIGURED=3 RUNNING=4
```

The `.config` that produced it has `LIBUKNETDEV_MAXNBQUEUES=1` and `STATS`,
`DISPATCHERTHREADS`, `EINFO_LIBPARAM` all unset, which are the defaults.
`lib/uknetdev` is byte-identical between the fork at `3fdffba8` and 0.21.0
"Ijiraq", so the probe answers for both.

**The `comptime` offset assertions in `index.kz` are not the proof.** They pin the
Zig mirror to these measured numbers and turn a silent layout change into a
compile error; agreeing with themselves says nothing about the C. W1–W4 are what
say something about the C, and they run on the booted machine.

---

## The linkability verdict

`lib/uknetdev/exportsyms.uk` exists — case 1 — with **33 lines**.

- **31 link.** Zero phantoms: every one of the 33 names has a definition in the
  tree, checked by grep.
- **2 are INERT — case 5.** `uk_netdev_rxq_intr_enable` and
  `uk_netdev_rxq_intr_disable` are listed *and* `static inline`
  (`netdev.h:395`, `:424`), so no global is emitted and objcopy has nothing to
  keep. A separately-linked archive cannot reach them.
- **12 public-header `static inline`s, all MIRROR, none NO.** The two above plus
  `uk_netdev_rx_one` / `uk_netdev_tx_one` (`struct uk_netdev` offsets), seven
  netbuf helpers (`struct uk_netbuf` offsets) and one driver-side
  `uk_netdev_drv_rx_event`. Nothing in this library closes
  over a Kconfig integer in a way a probe cannot answer — `MAXNBQUEUES` is the
  only one, and W3 derives it.

This lift binds 18 of the 31 linkable symbols and both of the transfer inlines.
The 13 it does not bind are named in the census table above.

---

## Gate 2 — it boots, and a frame crosses the wire

Two artifacts. Run each in its own empty directory. Traps and their evidence:
`/Users/larsde/src/koru/examples/unikraft/BUILD.md`.

```sh
cp tests/{boot_wire.kz,wrapper.zig,main.c} <builddir> && cd <builddir>

koruc boot_wire.kz unikraft gen        # -> Makefile.uk + Kraftfile
koruc boot_wire.kz                     # -> output_emitted.zig
                                       #    (the HOST link then fails on the
                                       #     Unikraft symbols; that is expected)
zig build-lib wrapper.zig \
    -target x86_64-freestanding -O ReleaseSmall \
    -fno-stack-protector -femit-bin=libkoruapp.a
UK_CFLAGS="-std=gnu17" kraft build --arch x86_64 --plat qemu --no-prompt
```

**The exact qemu invocation. Both the `-cpu` string and both hub ports are
load-bearing** — without the second NIC there is nothing for the frame to arrive
on, and the program prints `nic1 unavailable`:

```sh
qemu-system-x86_64 -kernel .unikraft/build/koru_qemu-x86_64 \
  -cpu 'qemu64,+pdpe1gb,+rdrand,+rdseed,-vmx,-svm' \
  -m 64M -nographic -no-reboot -display none -parallel none \
  -netdev hubport,id=h0,hubid=0 -device virtio-net-pci,netdev=h0 \
  -netdev hubport,id=h1,hubid=0 -device virtio-net-pci,netdev=h1 \
  -object filter-dump,id=d0,netdev=h0,file=tx0.pcap
```

QEMU prints `warning: hub 0 is not connected to host network` and that is
correct: the hub connects the two guest interfaces to each other and to nothing
else, which is exactly the point — no host stack, no protocol, no assumption
about what anything outside does.

Real console output, `\r` stripped, firmware banner elided:

```
Booting from ROM..netdevs: 2
nic0: virtio-net index 0
nic0: mtu 1500 hwaddr 52:54:00:12:34:56 max payload 1500
nic0: running
nic1: virtio-net index 1
nic1: mtu 1500 hwaddr 52:54:00:12:34:57
nic1: running
nic0: tx 112 bytes
nic1: rx from 52:54:00:12:34:56 to ff:ff:ff:ff:ff:ff type 34997
nic1: payload KORU SENT THIS FRAME THROUGH unikraft/net -- dev->tx_one, mirror proven by four witnesses, no shim
wire complete
```

`nic1` received what `nic0` sent — the source MAC is nic0's own, filled in by the
lift, and the payload is byte-for-byte the string in `boot_wire.kz`. The
host-side pcap holds the same frame and nothing else:

```
$ python3 -c "…"   # decode tx0.pcap
frame caplen 112 origlen 112
  dst ff:ff:ff:ff:ff:ff src 52:54:00:12:34:56 type 0x88b5
  payload: KORU SENT THIS FRAME THROUGH unikraft/net -- dev->tx_one, mirror proven by four witnesses, no shim
```

The chain exercised: `get → probe → configure → queues.open → start` twice, then
`tx` on nic0, `rx` on nic1, `packet.drop`, `park`, `park`.

The second artifact, `tests/boot_link_check.kz`, is the control for the asymmetry
gate and boots with a single NIC:

```sh
qemu-system-x86_64 -kernel .unikraft/build/koru_qemu-x86_64 \
  -cpu 'qemu64,+pdpe1gb,+rdrand,+rdseed,-vmx,-svm' \
  -m 64M -nographic -no-reboot -display none -parallel none \
  -netdev hubport,id=h0,hubid=0 -device virtio-net-pci,netdev=h0
```

```
Booting from ROM..nic0: virtio-net index 0
nic0: mtu 1500 hwaddr 52:54:00:12:34:56
nic0: promiscuous not supported by this driver
link check passed, no traffic sent
```

That output is `promiscuous.set`'s `| unsupported` arm firing on real hardware —
virtio-net's ops table has `promiscuous_get` and no setter — followed by
`traffic.skipped` and `park`. It is the only place either tor runs.

| | |
|---|---:|
| Koru freestanding static archive (`boot_wire`) | 28,872 B |
| bootable unikernel image (`boot_wire`) | 206,456 B |
| baseline (`koru/examples/unikraft/hello.kz`, no netdev) | 164,544 B |
| RAM floor, two NICs, boots and completes | **4 MB** |
| RAM floor, fails | 3 MB (`Failed to set up virtqueue 0: -12`) |

No boot-time number. Everything here is QEMU TCG with no KVM, and this project
does not have a boot-time claim to make.

### Pillar 2 — what the lifting costs at run time

Nothing. `koru_main` in the built image is 1,876 instructions with the whole flow
inlined into it, and it contains **exactly two indirect calls** — `dev->tx_one`
and `dev->rx_one`, the two mirror calls, which are the same two indirect calls
`uk_netdev_tx_one`/`rx_one` would have made. Everything else is a direct call, in
source order:

```
uk_netdev_count → get_event → probe_event → configure_event → queues_open_event
→ start_event → (all five again for nic1) → uk_netbuf_alloc_buf
→ uk_netdev_hwaddr_get → *INDIRECT*  (tx_one) → *INDIRECT*  (rx_one)
→ writeMac → uk_netbuf_free → free → free
```

interleaved only with the `memcpy`/`fputs` pairs that are the caller's own
`print.ln`s. There is no state variable, no state comparison and no dispatch
table anywhere in it. In the emitted Zig every occurrence of a phantom state name
is a comment or a local variable the *flow* chose to call `running`.

One thing the lift does that the C cannot: `uk_netdev_rx_one` re-reads
`dev->_rx_queue[queue_id]` on every packet because its API takes a queue id. This
lift reads the slot once, at `queues.open`, and caches the pointer — which is
sound **only** because uknetdev has no queue teardown and no exported call clears
the slot. That is a consequence of the no-teardown finding, not a cleverness.

### The honest claim, and the one I am not making

Koru dissolves Unikraft's asserts-on / asserts-off tradeoff for the 23 assertions
above: assert-on guarantees at assert-off cost. That is what the disassembly
shows.

It is **not** "faster than C". The per-packet state checks at `netdev.h:484` and
`:554` are `UK_ASSERT`s and already compile out in release. Demonstrating the
dissolution properly needs a three-way benchmark — asserts-on C, asserts-off C,
proven Koru — which does not exist. I did not build it.

---

## Gate 3 — five misuses that fail to compile

Phantom validation fires in the **emit** pass, not in `--check`. Every one of
these passes `koruc --check` and is refused by `koruc <file>`. Diagnostics are
verbatim.

**`tests/negative_park_without_traffic.kz`** — the asymmetry. Bring an interface
up, walk away, never move a frame.

```
$ koruc --check negative_park_without_traffic.kz
✓ Shape checking passed

$ koruc negative_park_without_traffic.kz
error[KORU030]: Phantom state mismatch: expected 'unikraft.net:carried' but got 'unikraft.net:running!' for argument 'dev'
❌ Compiler coordination error: Phantom semantic validation failed
```

The C cannot object to this program, and could not be made to: there is no
teardown call to put a guard on.

**`tests/negative_start_before_queues.kz`** — start a device whose queues were
never configured.

```
error[KORU030]: Phantom state mismatch: expected 'unikraft.net:armed' but got 'unikraft.net:configured!' for argument 'dev'
```

The C **starts**. `uk_netdev_start`'s guard is `state != UK_NETDEV_CONFIGURED`
(`netdev.c:601`) and this device *is* CONFIGURED — the check passes, the device
goes RUNNING with both queue slots null, and the first transfer walks a null
pointer into the driver. The assertion that would have caught it
(`netdev.h:485`) is `do {} while(0)`.

**`tests/negative_configure_before_probe.kz`** — configure a device that was
never probed.

```
error[KORU030]: Phantom state mismatch: expected 'unikraft.net:probed' but got 'unikraft.net:found!' for argument 'dev'
```

**`tests/negative_tx_after_park.kz`** — transmit through a handle already let go
of. A different KORU030:

```
error[KORU030]: Use-after-discharge: binding 's.dev' was already discharged and cannot be used
```

**`tests/negative_device_never_discharged.kz`** — take a device and walk away.

```
error[KORU030]: Resource 'dev' obligation <found!> was not discharged. Call: probe
❌ Compiler coordination error: Auto-discharge failed (multiple disposal options or no disposal event)
```

And the control, `tests/boot_link_check.kz`: the same chain as the first negative
with `net:traffic.skipped` in it, compiling clean through the emit pass **and
booting**.

---

## The trap that cost a boot: a smaller ring loses every frame, silently

`queues.open` takes **no descriptor-count parameter**, and that is a decision with
a measurement behind it. Same booted image, same program, only the requested
count changed:

| requested | result |
|---|---|
| 64 descriptors | `tx` returns `UK_NETDEV_STATUS_SUCCESS`, and **nothing leaves the guest**. The host-side pcap holds zero packets; the peer interface receives nothing. |
| the device's own `nb_max` | the frame arrives on the peer, byte for byte. |

The mechanism, read rather than guessed. This tree's only virtio-pci transport is
`drivers/virtio/pci/virtio_pci.c`, whose `vpci_legacy_vq_setup` (`:152`) writes
`VIRTIO_PCI_QUEUE_SEL` and `VIRTIO_PCI_QUEUE_PFN` and **no queue size** — in
legacy virtio that register is read-only. So the guest lays out a 64-entry vring
where the host is reading a 256-entry one, and the avail ring the guest updates is
at an offset the host never looks at. `virtio_net.c:832` has a guard for exactly
this — it forces `nr_desc = max_desc` — but only when `VIRTIO_F_VERSION_1` is
*unset*, and `:1049` sets that bit whenever the host offers it, over a transport
that is legacy anyway. The guard never fires.

I did not patch Unikraft. The lift's answer is a parameter that does not exist —
the same move `unikraft/pages` makes with `num_pages`. **A knob whose wrong
setting is undetectable is worse than no knob.** The ring is the device's own
`nb_max`, read from `rxq_info_get`/`txq_info_get`.

What that costs: the receive ring is `nb_max` netbufs of `nb_encap_rx + 1522`
bytes each, allocated at `queues.open` and never freed, because uknetdev has no
call that frees them. On QEMU virtio-net that is 256 buffers per interface, and it
is why the RAM floor is 4 MB for two NICs rather than the 2 MB a Koru unikernel
with no devices needs.

---

## What the toolchain got wrong

Two things surfaced by writing this. Neither is worked around inside the lift;
`index.kz` is untouched by both.

### 1. A Koru binding whose name is a Zig primitive emits invalid Zig

Pinned with a control, eight lines:

```koru
// lib.kz
~pub tor answer { } -> u32
~proc answer|zig { return 42; }
```

```koru
// prim.k
import lib
import std/io

lib:answer(): u1 |> std/io:print.ln("answer {{ u1:d }}")
```

```
$ koruc --check prim.k
✓ Shape checking passed

$ koruc prim.k
Error: output_emitted.zig:32:15: error: name shadows primitive 'u1'
```

The emitter writes `const u1 = …` for the binding without `@"…"` escaping. The
control is the identical program with the binding renamed `held`, which compiles
and prints `answer 42`. Every Zig primitive name is affected — `u1`…`u65535`,
`i32`, `f64`, `bool`, `void`, `type`, `anyerror` — and all of them are legal Koru
identifiers. It only fires for a tor that *returns* a value, because a void tor
emits no `const`.

Found because `traffic.skipped(dev: r1): u1` is a perfectly reasonable thing to
write. The boot test uses `hold0`/`hold1` instead, with the reason at the site.

### 2. `tests/wrapper.zig` runs `flow0` and only `flow0`

Not a compiler defect — a property of the shared C-ABI seam every lift copies —
but it fails silently and it cost a build. A program with two top-level flows
emits both, links both, and runs the first. The archive dead-strips from 28,872
to 3,560 bytes and the unikernel boots printing only what the first flow printed.
`boot_wire.kz` therefore chains `count` into `get` rather than standing it beside,
with the reason at the site. Worth a wall: the wrapper could call every `flowN`,
or the emitter could refuse an entry file whose later flows are unreachable from
the declared entry point.

Two defects `unikraft/blk` pinned are still live and were re-hit here: an empty
`Source` block emits invalid Zig (worked around by giving `~unikraft:image` a real
body), and `~import unikraft/blk` silently imports `unikraft` too while naming
both duplicates it (so `boot_wire.kz` has no `~import unikraft` line). Both are
documented at their sites.

---

## What I left out — claims I am deliberately not making

- **The interrupt toggle.** `uk_netdev_rxq_intr_enable` / `_disable` and their 12
  assertions. Both are INERT (listed *and* `static inline`), so a
  separately-linked archive cannot call them at any price. This is the brief's
  paired-toggle obligation shape and it is the one I could not write. The lift
  polls instead, which is the mode `virtio_netdev_recv` is written for — it
  asserts interrupts are OFF at `virtio_net.c:683`.
- **Multi-queue.** `CONFIG_LIBUKNETDEV_MAXNBQUEUES` defaults to 1 and virtio-net
  reports one pair, so the lift configures queue 0 for rx and queue 0 for tx and
  never asks for a queue id. It *derives* `MAXNBQUEUES` rather than assuming it,
  but it does not model N queues. Doing so means N sub-obligations on one device,
  and I would want a device that actually has more than one before designing it.
- **Zero-copy transmit.** `tx` copies the payload into a fresh netbuf. A caller
  that already has a netbuf — the natural shape for forwarding a received frame
  straight back out — cannot express that, because the tx netbuf is deliberately
  not an obligation. `tx.forward { pkt: *Packet<!received> }` is the obvious next
  tor and I did not write it: an rx netbuf's headroom is `nb_encap_rx` and tx
  needs `nb_encap_tx`, and I have not proved those are interchangeable on any
  driver but virtio.
- **Netbuf chains.** `uk_netbuf_connect` / `append` / `disconnect` and
  scatter-gather transmit are not exposed. `rx`'s `payload` is the head buffer's
  data only; with `VIRTIO_NET_F_MRG_RXBUF` a large frame can arrive as a chain and
  this lift would show the caller the first segment. `packet.drop` calls
  `uk_netbuf_free`, which walks and frees the whole chain, so nothing leaks — but
  a jumbo frame would be under-reported. The demo's frames are 112 bytes and never
  chain. **This is the sharpest limitation in the module.**
- **`hwaddr_set`, `promiscuous_get`, `mtu_set`, `einfo_get`.** Bound by nobody
  here; the first three have no virtio-net implementation, and `einfo_get` is a
  network-stack concern.
- **The three-way benchmark** that would let anyone say "assert-on guarantees at
  assert-off cost" with numbers.
- **Any claim about `promiscuous.set` succeeding.** Its `| ok` arm has never run
  on any hardware I have. The `| unsupported` arm is booted and shown above.
- **Any boot-time number**, per the brief.

---

## Files

| | |
|---|---|
| `index.kz` | the lift |
| `tests/boot_wire.kz` | gate 2 — both lifecycles, a frame from nic0 to nic1, in a unikernel |
| `tests/boot_link_check.kz` | gate 2 — the named escape and `promiscuous.set`'s `unsupported` arm, booted; the control for the asymmetry negative |
| `tests/negative_park_without_traffic.kz` | gate 3 — the asymmetry |
| `tests/negative_start_before_queues.kz` | gate 3 — start before the queues exist |
| `tests/negative_configure_before_probe.kz` | gate 3 — configure before probe |
| `tests/negative_tx_after_park.kz` | gate 3 — use after discharge |
| `tests/negative_device_never_discharged.kz` | gate 3 — leak |
| `tests/wrapper.zig`, `tests/main.c` | the C-ABI seam, from `koru/examples/unikraft` |

Measured against `unikraft` HEAD `3fdffba8` (`lib/uknetdev` byte-identical to
0.21.0 "Ijiraq"), kraftkit 0.12.15, Unikraft 0.21.0, zig 0.15.2, koruc 0.1.7,
qemu 10.x, on macOS/arm64.
