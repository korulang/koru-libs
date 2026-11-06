//~ compile_fail(backend)
//~ error[KORU030]: Phantom state mismatch
// NEGATIVE: unregister a device that was never registered. The C asserts
// dev->id < UK_CONSOLE_MAX_DEVS (console.c:388) — retired here: only <!live>
// reaches `unregister`.
std/compiler:paths {
    unikraft: {{ ENTRY }}/../..
}

import unikraft/console
import std/io

unikraft/console:new(name: "x")
| ok c |> unikraft/console:unregister(dev: c)
    | refused f |> unikraft/console:forget(f.dev)
    | ok u |> unikraft/console:discard(dev: u)
    |> std/io:print.ln("done")
| refused n |> std/io:print.ln("{{ n:s }}")
