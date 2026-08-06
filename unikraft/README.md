# @korulang/unikraft

Declare a Unikraft unikernel from the Koru program that runs in it.

```koru
import std/io
import koru/unikraft

koru/unikraft:image(name: "koru") {
    APPKORU_CFLAGS-y += -DKORU_UNIKERNEL=1
}

koru/unikraft:kconfig {
    CONFIG_OPTIMIZE_SIZE: 'y'
    CONFIG_OPTIMIZE_DEADELIM: 'y'
}

std/io:print.blk {
    Hello from pure Koru, inside a unikernel it declared itself
}
```

```
$ koruc app.k unikraft gen
✓ Makefile.uk (appkoru)
✓ Kraftfile (1 kconfig block(s))
```

Same move `koru/docker:image` makes for a Dockerfile: the build manifest of a
foreign toolchain is generated from the program, not hand-maintained beside it.

## Tors

| Tor | Emits | Description |
|-----|-------|-------------|
| `image` | `Makefile.uk` | `addlib` registration + both prefixed variables, derived from `name` |
| `kconfig` | `Kraftfile` | Kconfig deltas, one `CONFIG_X: 'y'` per line |

## Why `image` derives instead of passing a block through

A Unikraft library registers with `$(eval $(call addlib,<name>))` and then feeds
sources through variables named after the **same** name, uppercased and
prefixed. A wrong prefix is not an error — `addlib` succeeds, nothing attaches,
and the image links Unikraft's weak `main`, boots, prints nothing, and exits
zero. One name in, three correct lines out, and that failure mode unreachable.

## Why `image`/`kconfig` and not `app`/`config`

A first cut lived in `std/` as `app` and `config`. Each block compiled alone;
**both in one program did not** — `app` is a reserved default import alias
(koru's `config.zig` seeds `app -> {{ ENTRY }}`) and `config` collides with the
existing `std/build:config` comptime tor. `image` also lines this module up with
`koru/docker:image`.

## The stack line you didn't write

`Kraftfile` always carries `CONFIG_STACK_SIZE_PAGE_ORDER: '6'`. Unikraft's
default is order 4 — 16 pages, exactly 64 KB — and `std/io`'s format buffer is
65,536 bytes, so any Koru program that prints overflows the entire boot stack
and traps. Order 6 costs zero image bytes. Supply your own line of the same name
to override it.

## Tests

`tests/gen_image.k` — both blocks in one program (the shape that failed under
the old names), generating both manifests.

## Measured

The image built from these generated manifests, booted under QEMU:

| | |
|---|---:|
| Koru freestanding static archive | 3,214 B |
| bootable unikernel image | 164,544 B |
| RAM floor | 2 MB |

`LIBSYSCALL_SHIM` and `LIBVFSCORE` are both unset — no Linux ABI, no syscall
shim. Koru calls into nolibc as a function in the same address space.

Full seam, exact commands, and the traps that cost hours: `koru/examples/unikraft/BUILD.md`.
