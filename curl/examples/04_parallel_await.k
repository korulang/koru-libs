// Three downloads at once, blocking until they all land.
//
// One thread. libcurl multiplexes the three transfers over their sockets;
// `await` pumps until nothing is left running, firing an arm each time a
// transfer moves or finishes.
//
// The obligation chain is the whole story. `multi.new` issues an EMPTY batch —
// and empty has no disposer, so a batch you build must be used. `multi.add`
// moves it to `open`; `multi.start` accepts only `open`, so a batch with no
// transfers cannot be started. `await` converts the promise back into a batch
// that must be closed. Skip a step and it does not compile.

import koru/curl
import std/io

koru/curl:multi.new(): m0 |> koru/curl:multi.add(m: m0, url: "https://httpbin.org/bytes/120000"): m1 |> koru/curl:multi.add(m: m1, url: "https://httpbin.org/bytes/240000"): m2 |> koru/curl:multi.add(m: m2, url: "https://httpbin.org/bytes/360000"): m3 |> koru/curl:multi.start(m: m3)
| started p |> koru/curl:await(p)
    ! progress pr |> std/io:print.ln("  #{{ pr.index:d }} {{ pr.percent:d }}%")
    ! finished r |> std/io:print.ln("✓ {{ r.status:d }} — {{ r.body.len:d }} bytes") |> koru/curl:close(resp: r)
    | done b |> koru/curl:multi.close(m: b) |> std/io:print.ln("batch closed")
| failed e |> std/io:print.ln("could not start: {{ e.msg:s }}")
