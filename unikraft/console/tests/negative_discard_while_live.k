//~ compile_fail(backend)
//~ error[KORU030]: Phantom state mismatch
// NEGATIVE: discard a still-registered device. `discard` accepts only
// <!retired> — unregister must run first.
std/compiler:paths {
    unikraft: {{ ENTRY }}/../..
}

import unikraft/console
import std/io

unikraft/console:new(name: "x")
| ok c |> unikraft/console:register(dev: c)
    | ok r |> unikraft/console:discard(r.dev)
    | refused f |> unikraft/console:forget(f.dev)
| refused n |> std/io:print.ln("{{ n:s }}")
