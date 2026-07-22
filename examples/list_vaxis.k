// Rung 1 — a static multi-row list painted into the vaxis surface, NO store.
//
// The store session owns reactive state + query; this proves the *render*
// side independently: a for-each walking a plain std/list and firing one
// write-at per row, each at its own y (the loop index drives the row).
//
// Rows are i64 today — std/list is i64-only (koru_std/list.kz), the same
// typed-element gap the store is climbing. Each element is fmt'd into a row,
// so the string *content* rejoins for free once typed elements land.
//
//   for-each ─> get(i) ─> fmt row ─> write-at(y = base + i) ─> render
//
// Build & run (needs a real terminal — q to quit):
//   koruc run examples/list_vaxis.k

import std/io
import std/fmt
import std/list
import koru/vaxis

koru/vaxis:run(title: "list")
! draw _ |> std/list:new(i64)
    | list xs |> std/list:push(xs, v: 10)
        |> std/list:push(xs, v: 20)
        |> std/list:push(xs, v: 30)
        |> std/list:len(xs): n
        |> for(0..n)
            ! each i |> std/list:get(xs, i)
                | item v |> std/fmt:ln("row {{ i:d }}: {{ v:d }}"): l |> koru/vaxis:write-at(x: 2, y: @as(u16, @intCast(2 + i)), l.text)
                | out-of-bounds |> _
            | done |> koru/vaxis:render() |> std/list:free(xs)
    | err _ |> _
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
