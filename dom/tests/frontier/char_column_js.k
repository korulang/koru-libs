// P2a — char[32] column only, insert at root (690_052 minus the chain).
import std/io
import std/store
std/store:new(rows, capacity: 16) { id: i64, label: char[32] }
std/store:insert(rows) { id: 1, label: "hello" }
std/store:rule(rows)
! row e |> std/io:print.ln("row {{ e.id:d }} {{ e.label:s }}")
