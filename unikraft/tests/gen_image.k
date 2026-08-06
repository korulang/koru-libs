// Both blocks in one program — the shape that failed as `std/unikraft:app` +
// `std/unikraft:config` (each compiled alone; together they did not, because
// `app` is a reserved import alias and `config` collides with std/build:config).
//
//   koruc gen_image.k unikraft gen   ->  Makefile.uk + Kraftfile

import std/io
import koru/unikraft

koru/unikraft:image(name: "koru") {
    APPKORU_CFLAGS-y += -DKORU_UNIKERNEL=1
}

koru/unikraft:kconfig {
    CONFIG_OPTIMIZE_SIZE: 'y'
    CONFIG_OPTIMIZE_DEADELIM: 'y'
    CONFIG_OPTIMIZE_NOOMITFP: 'n'
    CONFIG_DEBUG_SYMBOLS_LVL1: 'y'
    CONFIG_LIBVGACONS: 'n'
    CONFIG_LIBUKBOOT_BANNER_NONE: 'y'
    CONFIG_LIBUKDEBUG_ENABLE_ASSERT: 'n'
}

std/io:print.blk {
    Hello from pure Koru, inside a unikernel it declared itself
}
