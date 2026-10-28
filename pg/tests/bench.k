// Koru-side perf: serial simple queries through the native driver.
// Each iteration: 'Q' send + DataRow + CommandComplete + ReadyForQuery
// drain — the full blocking roundtrip. Timed externally.

import koru/pg
import std/io

koru/pg:connect(host: "127.0.0.1", port: 5432, user: "benchmarkdbuser", database: "hello_world")
| err e |> std/io:print.ln("connect failed: {{ e:s }}")
| ok conn |> for(0..20000)
    ! each _ |> koru/pg:query(conn, sql: "SELECT id, randomNumber FROM world WHERE id = 7")
        | err e |> std/io:print.ln("query failed: {{ e:s }}")
        | ok _ |> koru/pg:row.next(conn): _
            |> koru/pg:row.next(conn): _
|> std/io:print.ln("done 20000 queries")
