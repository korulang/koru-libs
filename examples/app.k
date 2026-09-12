// Example: Using koru-libs packages together
//
// This example uses sqlite3 for data and could deploy via docker.
// Run from ~/src/koru-libs/examples with: koruc app.kz

import std/io
import koru/sqlite3

// Simple sqlite3 test
koru/sqlite3:open(path: ":memory:")
| db d |> koru/sqlite3:exec(conn: d, sql: "CREATE TABLE test (id INTEGER, name TEXT)")
    | ok |> koru/sqlite3:exec(conn: d, sql: "INSERT INTO test VALUES (1, 'hello')")
        | ok |> koru/sqlite3:close(conn: d)
            |> std/io:print.ln("sqlite3 works!")
        | err e |> std/io:print.ln("Insert failed: {{ e.msg:s }}")
    | err e |> std/io:print.ln("Create table failed: {{ e.msg:s }}")
| err e |> std/io:print.ln("Open failed: {{ e.msg:s }}")
