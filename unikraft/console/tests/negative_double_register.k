//~ compile_fail(backend)
//~ error[KORU030]: Phantom state mismatch
// NEGATIVE: register a device already live. console.c:292's debug-only
// dedup assert is the C's guard, deleted in release; <live> cannot reach
// `register` again.
std/compiler:paths {
    unikraft: {{ ENTRY }}/../..
}

import unikraft/console
import std/io

unikraft/console:new(name: "x")
| ok c |> unikraft/console:register(dev: c)
    | refused f0 |> unikraft/console:forget(f0.dev)
    | ok r |> unikraft/console:register(r.dev)
        | refused f1 |> unikraft/console:forget(f1.dev)
        | ok r2 |> unikraft/console:unregister(r2.dev)
            | refused f2 |> unikraft/console:forget(f2.dev)
            | ok u |> unikraft/console:discard(dev: u)
    |> std/io:print.ln("done")
| refused n |> std/io:print.ln("{{ n:s }}")
