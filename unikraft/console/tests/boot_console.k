// POSITIVE, and the gate-2 artifact: the ukconsole lifecycle driven from Koru
// inside a unikernel — a console device authored in this program, registered
// with the C registry, written and emergency-written through its own ops
// trampolines, subscribed to async events, pumped, unsubscribed, unregistered
// and discarded.
//
//   new.async -> register -> write -> emerg -> subscribe -> pump
//             -> unsubscribe -> read (expects the -EIO arm) -> unregister
//             -> discard
//
// Every arrow is a phantom transition the compiler checked before this program
// existed; the four witnesses in ../index.kz ran before the device served a
// byte.
//
// Build and boot: see ../README.md.

// `~import unikraft` is DELIBERATELY ABSENT (see unikraft/net's note).
std/compiler:paths {
    unikraft: {{ ENTRY }}/../..
}

import unikraft/console
import std/io
import std/io

unikraft:tree(path: "/Users/larsde/src/unikraft")

unikraft:image(name: "koru") {
    APPKORU_CFLAGS-y += -DKORU_UNIKRAFT_CONSOLE=1
}

unikraft:kconfig {
    CONFIG_OPTIMIZE_SIZE: 'y'
    CONFIG_OPTIMIZE_DEADELIM: 'y'
    CONFIG_LIBUKBOOT_BANNER_NONE: 'y'
    CONFIG_LIBUKDEBUG_ENABLE_ASSERT: 'n'
    CONFIG_LIBUKCONSOLE: 'y'
    CONFIG_LIBUKALLOC: 'y'
    CONFIG_LIBUKALLOCBBUDDY: 'y'
}

unikraft/console:count(): n |> std/io:print.ln("consoles before: {{ n:d }}")
|> unikraft/console:new.async(name: "koru-sess0")
| refused nx |> std/io:print.ln("new refused: {{ nx:s }}")
| ok c |> unikraft/console:register(dev: c)
    | refused f |> std/io:print.ln("register refused: {{ f.reason:s }}")
        |> unikraft/console:forget(f.dev)
    | ok r |> std/io:print.ln("registered con{{ r.id:d }}")
        |> unikraft/console:write(r.dev, text: "session banner\n")
        | err e0 |> std/io:print.ln("write errno {{ e0.errno:d }}")
            |> unikraft/console:unregister(e0.dev)
            | refused w0 |> unikraft/console:forget(w0.dev)
            | ok u0 |> unikraft/console:discard(dev: u0)
        | ok w |> std/io:print.ln("out_direct wrote {{ w.written:d }} bytes")
            |> unikraft/console:emerg(w.dev, text: "emerg!\n")
            | err e1 |> std/io:print.ln("emerg errno {{ e1.errno:d }}")
                |> unikraft/console:unregister(e1.dev)
                | refused w1 |> unikraft/console:forget(w1.dev)
                | ok u1 |> unikraft/console:discard(dev: u1)
            | ok e |> std/io:print.ln("emerg wrote {{ e.written:d }} bytes")
                |> unikraft/console:drain(e.dev): d
                |> std/io:print.ln("captured: {{ d.data:s }}")
                |> unikraft/console:subscribe(d.dev, event: 1)
                | refused s1 |> std/io:print.ln("subscribe refused {{ s1.errno:d }}")
                    |> unikraft/console:unregister(s1.dev)
                    | refused w2 |> unikraft/console:forget(w2.dev)
                    | ok u2 |> unikraft/console:discard(dev: u2)
                | ok s |> unikraft/console:pump(dev: s, event: 1): p
                    |> std/io:print.ln("async IN fired {{ p.fired:d }} callback(s)")
                    |> unikraft/console:unsubscribe(p.dev, event: 1)
                    | missing m |> std/io:print.ln("unsubscribe missing {{ m.errno:d }}")
                        |> unikraft/console:unregister(m.dev)
                        | refused w3 |> unikraft/console:forget(w3.dev)
                        | ok u3 |> unikraft/console:discard(dev: u3)
                    | ok x |> unikraft/console:read(dev: x)
                        | ok rd |> std/io:print.ln("read: {{ rd.data:s }}")
                            |> unikraft/console:unregister(rd.dev)
                            | refused w4 |> unikraft/console:forget(w4.dev)
                            | ok u4 |> unikraft/console:discard(dev: u4)
                            |> unikraft/console:count(): n3
                            |> std/io:print.ln("consoles after: {{ n3:d }} — CONSOLE LIFT OK")
                        | err e2 |> std/io:print.ln("read refused errno {{ e2.errno:d }} (expected -EIO: no in op)")
                            |> unikraft/console:unregister(e2.dev)
                            | refused w5 |> unikraft/console:forget(w5.dev)
                            | ok u5 |> unikraft/console:discard(dev: u5)
                            |> unikraft/console:count(): n4
                            |> std/io:print.ln("consoles after: {{ n4:d }} — CONSOLE LIFT OK")
