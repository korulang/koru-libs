// Test: connect / simple query / streaming rows / zero-copy cols.
// Against docker pg-dev (trust auth): SELECT one world row.
// Run: koruc tests/first_query.k && ./a.out

import koru/pg
import std/io

koru/pg:connect(host: "127.0.0.1", port: 5432, user: "benchmarkdbuser", database: "hello_world")
| err e |> std/io:print.ln("connect failed: {{ e:s }}")
| ok conn |> koru/pg:query(conn, sql: "SELECT id, randomNumber FROM world WHERE id = 42")
    | err e |> std/io:print.ln("query failed: {{ e:s }}")
    | ok _ |> koru/pg:row.next(conn): has
        |> if(has)
            | then |> koru/pg:col.bytes(conn, i: 0): v0
                |> koru/pg:col.bytes(conn, i: 1): v1
                |> std/io:print.ln("row: {{ v0:s }} {{ v1:s }}")
                |> koru/pg:disconnect(conn)
            | else |> std/io:print.ln("no rows") |> koru/pg:disconnect(conn)
