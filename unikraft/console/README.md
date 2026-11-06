# unikraft/console — Unikraft's console registry (`ukconsole`), lifted

**This is not a naive wrap.** It is a *provider-side* lift: the Koru program
authors a console device — a `struct uk_console_async` whose `ops` call back
into functions in this module — and the lifecycle is a three-state ratchet
with an asymmetry gate on `discard`, four negative tests that refuse to
compile, and a mirror proven by four behavioural witnesses on the booted
machine, not by transcription-faith. Census below: 19 of 26 assertion sites
retired, the rest named and reasoned.

`lib/ukconsole` is the registry between Unikraft's print/input paths and its
console drivers. A driver fills a `struct uk_console` — name, ops, flags,
device class — and calls `uk_console_register`; `uk_console_unregister`
takes it back down (fork-only, see below). The async half lets a driver
register callbacks the framework fires on IN/OUT events. It carries **26
assertion sites** (25 `UK_ASSERT` + 1 `UK_CRASH`), and `UK_ASSERT` expands
to `do {} while(0)` whenever `CONFIG_LIBUKDEBUG_ENABLE_ASSERT` is off —
which is the config this lift builds, and every image anyone ships.

```koru
~import unikraft/console

~unikraft/console:new.async(name: "koru-sess0")
| ok c |> unikraft/console:register(dev: c)
    | ok r |> unikraft/console:write(r.dev, text: "session banner\n")
        | ok w |> unikraft/console:emerg(w.dev, text: "!")
            | ok e |> unikraft/console:unregister(e.dev)
                | ok u |> unikraft/console:discard(dev: u)
```

The caller never sees a `struct uk_console`, never supplies an ops table,
never names a callback signature — and cannot spell a call out of order.

## This lift requires the fork — `unikraft:tree`, not `version: stable`

`uk_console_unregister` and the whole async family
(`async_register_callback`, `async_unregister_callback`,
`async_in_handle`, `async_out_handle`) exist **only in the korulang
unikraft fork** — against upstream `stable` (0.21.0) `exportsyms.uk` has 7
lines and this module's ratchet would have no `unregister` at all, which
deletes the lifecycle's exit edge and half its witnesses.

So the image builds against the fork, and that is declared, not patched:
`unikraft/index.kz` gained a `tree` declaration —

```koru
unikraft:tree(path: "/Users/larsde/src/unikraft")
```

— which emits `source:` into the Kraftfile in place of `version: stable`.
Absent `tree` nothing changes for the shipped modules. This is the first
lift to carry the requirement, and it is stated in the manifest the build
actually reads, not in prose.

**Provenance:** `github.com/COCPORN/unikraft` (upstream `unikraft/unikraft`)
@ `3fdffba8` — `lib/ukconsole`, BSD 3-clause (`COPYING.md`). The lift is a
derivation of that tree: same calls, same order, phantom states in place
of asserts-on.

## The machine the C writes down — `dev->id` is the state field

`struct uk_console.id` is `__U16_MAX` while unregistered, a small slot
once `uk_console_register` assigns one, `__U16_MAX` again after
`uk_console_unregister`. The C asserts on it:

- `unregister` guards `dev->id < UK_CONSOLE_MAX_DEVS` (console.c:388) —
  unregistering a never-registered device is an assert violation.
- `register` debug-asserts the device is not already on the list
  (console.c:292) — double-register is forbidden, and the check only
  exists in asserts-on builds.
- Everything else asserts `dev`/`dev->ops` non-null — i.e. "must be
  initialised" — because ops is only set by `uk_console_init`.

The ratchet transcribes exactly that, no more:

```
    new / new.async   mints <idle!>           (mirror init — no C call)
    register          needs <!idle|!retired>   mints <live!>     uk_console_register
    write/read/emerg  need <!live>   mint <live!>              *_direct calls
    subscribe/pump    need <!live>   mint <live!>              async callback family
    unsubscribe       need <!live>   mint <live!>              async_unregister_callback
    unregister        needs <!live>            mints <retired!>  uk_console_unregister
    discard           needs <!retired>                          free
    abandon           needs <!idle>                             free — NAMED ESCAPE
    forget            needs <!stuck>                            free — refused-arm exit
```

Three states, one cycle (`register ⇄ unregister` — the C genuinely allows
re-registration; id returns to `U16_MAX` and a re-add is legal), plus the
named escapes.

## The asymmetry sits on `discard`

A console device's purpose *is* being registered — there is no
"acquire → use → release" use-phase to gate on, because registration is
the use. So `discard` accepts only `<!retired>`: a device that was live
once and came back down. `new(); discard();` is not a program. The
deliberate drop is the greppable `console:abandon` — "did we build
console devices we never registered" is a search, not an audit. This is
the same shape as `net:traffic.skipped` — the escape is named so the
question is answerable.

## Why the use tors gate on `<live>`, and where the C is looser than the lift

The C's `*_direct` family asserts only `dev && dev->ops` — technically
callable on an unregistered device. The callers of the direct path are
the framework and the driver *while the device is registered*; I/O on a
device the registry doesn't know is not a pattern ukconsole exists for.
So `write`, `read`, `emerg`, `subscribe`, `unsubscribe` and `pump`
consume and remint `<live!>`, which also keeps the obligation linear —
one owner, one exit through `unregister`. The difference from the C is
stated here, in the open: Koru is stricter on this seam than the C is,
and that strictness is the point of the lift, not an accident.

`read`'s refusal is the C's *real branch*, not a state: `in` is NULL by
construction on this lift's devices (write-only consoles), and
`uk_console_in_direct` answers `-EIO` — exercised in the boot log below.

## Subscriptions carry no obligation, deliberately

The callback registry is a resource the C itself tracks:
`uk_console_unregister` frees every pending callback through
`console_async_release_cb` (console.c:367), so nothing a caller can do
leaks. `subscribe` returns no handle — the (handler, cookie, event)
triple is the identity the C dedups on — and `unsubscribe`'s `-ENOENT`
is a real branch, not a state. There is nothing for a phantom to say
here that the C does not already enforce, and per the brief's own rule —
"not everything deserves a ratchet" — none was invented.

## The mirror, and how it is proven before it is trusted

`uk_console_init`/`uk_console_async_init` are `static inline` — the
brief's NO-symbol case — so `new` re-emits them over a mirrored
`struct uk_console_async` (the superset: `cons` is its first member, so
every `uk_console *` handed to the C is containerof-safe, sync device or
not). The lift always allocates the async-sized struct; `new.async` only
differs in the flags word, which is what makes `subscribe`/`pump` legal.

The offsets are proven by behaviour on the booted machine, not by
`@offsetOf` agreeing with itself:

| | |
|---|---|
| **W1** | `register` reads `dev->id` through the mirror and requires it to have become a real slot (< `CONFIG_LIBUKCONSOLE_DEVICES_MAXCOUNT`), then calls the *exported* `uk_console_get(id)` and requires it to return **this device pointer**. That one lookup exercises the `id` field, the `_list` link, and the registry's own indexing — a wrong offset loses the device. |
| **W2** | `write`/`emerg` route through `ops->out` — the mirrored ops pointer — and the bytes land in this module's capture trampoline, returned by `drain`. A wrong `ops` offset is a wild indirect call, not a silent miss. |
| **W3** | `unregister` requires `dev->id == __U16_MAX` through the mirror afterwards — the same field at a *different* value than W1, so the offset cannot agree by accident. |
| **W4** | `pump` dispatches through `_cb_list` and `_cb_list_lock` in the `uk_console_async` tail — the subscribed counter incremented, so the list-head and lock offsets are exercised end to end. |

`struct uk_console_ops` is wholly ours — we author it, the C only reads
it — so it needs no witness beyond W2's call-through.

The `@sizeOf`/`@offsetOf` comptime checks in `index.kz` remain, in the
same role net's keep: they pin the *transcription*, and the witnesses
pin the *C*.

## Assert census — 26 sites

| class | sites | where |
|---|---:|---|
| retired | 19 | `*_direct` `dev && dev->ops` ×3 (console.c:147,163,180) — device exists and carries ops by construction; `register` :286,:287,:292 — ops by construction, double-register unspellable under `<live>`; `unregister` :387,:388 — only `<live>` reaches the tor; `async_register_callback` :429–431 and `async_unregister_callback` :473–475 — dev/ops by construction, handler is the lift's own trampoline, never null; `uk_console_init` :87–89 and `uk_console_async_init` :120–121 — fields and flags set by construction |
| not lifted — unbound surface | 4 | `uk_console_in`'s registry-iteration assert (:107) and the three `*_direct_all` asserts (:200,:229,:258) — those functions are not bound by this lift; their asserts guard call sites Koru cannot reach |
| not lifted — runtime checks that remain | 2 | `UK_CRASH` on the 17th registered device (:342) and the `id < MAX_DEVS` assert beneath it (:350) — a capacity guard, not an ordering rule; it fires on count, not on sequence. The lift cannot retire it and does not pretend to: it is the one place the C will still halt the machine |

Zero `UK_BUGON`s in the library. One `UK_CRASH`, named above — ungated,
fires in every build, and it is a capacity bound, not an ordering rule.

## Negative tests (gate 3)

All four are declared `//~ compile_fail(backend)` +
`//~ error[KORU030]: Phantom state mismatch` and verified to refuse with
exactly that diagnostic:

| test | refuses | what the C does instead |
|---|---|---|
| `negative_unregister_before_register.k` | `expected 'live' but got 'idle!'` | asserts `dev->id < MAX` (console.c:388) — gone at NDEBUG |
| `negative_double_register.k` | `expected 'idle\|retired' but got 'live!'` | debug-only dedup assert (:292) — gone at NDEBUG |
| `negative_discard_without_use.k` | `expected 'retired' but got 'idle!'` | nothing — `create(); free();` compiles and runs |
| `negative_discard_while_live.k` | `expected 'retired' but got 'live!'` | nothing — the C would free a registered device's storage |

## Build and boot — reproduction

```sh
cd unikraft/console/tests

# manifests (Kraftfile + Makefile.uk) — emits `source:` for the fork
~/src/koru/zig-out/bin/koruc boot_console.k unikraft gen

# freestanding archive
zig build-lib wrapper.zig \
    -target x86_64-freestanding -O ReleaseSmall \
    -fno-stack-protector -femit-bin=libkoruapp.a

# image (the fork tree, per `unikraft:tree`)
UK_CFLAGS="-std=gnu17" kraft build --arch x86_64 --plat qemu --no-prompt

# boot
qemu-system-x86_64 -kernel .unikraft/build/koru_qemu-x86_64 \
    -cpu 'qemu64,+pdpe1gb,+rdrand,+rdseed,-vmx,-svm' \
    -m 32M -nographic -no-reboot -display none -parallel none
```

Real console output, this session:

```
Booting from ROM..consoles before: 2
registered con2
out_direct wrote 15 bytes
emerg wrote 7 bytes
captured: session banner
emerg!

async IN fired 1 callback(s)
read refused errno -5 (expected -EIO: no in op)
consoles after: 2 — CONSOLE LIFT OK
```

`con2` is the device this program authored — `uk_console_get(2)`
returned our pointer (W1). The 22 captured bytes went through the
mirrored ops pointer into `capOut` (W2). `id` returned to `U16_MAX`
(W3). The async callback fired through the mirrored `_cb_list`/lock
(W4). `consoles after: 2` — the registry count returned to its
pre-registration value, so the unregister took.

## What this lift deliberately is not

- **Not the consumer half.** `uk_console_out`/`in`/`emerg_out` — the
  broadcast path every console print already takes — are bound nowhere;
  the shipped unikernel's own console does that job. Binding them would
  wrap a function with no ordering and nothing to retire.
- **No `*_direct_all` surface.** Three exported functions looping until
  `len` is consumed; their asserts are the same `dev && dev->ops` the
  direct singles carry, so nothing new is provable by binding them —
  they are reachability exercises, not obligations. Named under "not
  lifted" above.
- **No invented capacity wall.** `UK_CONSOLE_MAX_DEVS` (16 by Kconfig)
  is a count limit the C enforces with `UK_CRASH`; a phantom state cannot
  model "the 17th registration", and pretending otherwise would be
  dishonest. It is the one runtime check left standing, and it is named.
