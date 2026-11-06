//~ compile_fail(backend)
//~ error[KORU030]: Phantom state mismatch
// NEGATIVE (pillar 4): discard a device that was never registered. `discard`
// accepts only <!retired>; `new(); discard();` is not a program. The escape
// is the named `console:abandon`.
std/compiler:paths {
    unikraft: {{ ENTRY }}/../..
}

import unikraft/console
import std/io

unikraft/console:new(name: "x")
| ok c |> unikraft/console:discard(dev: c)
| refused n |> std/io:print.ln("{{ n:s }}")
