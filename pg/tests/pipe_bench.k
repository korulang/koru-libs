// Pipelined prepared queries through the native driver — the lever the
// spike proved at ~50K q/s. prepare once; each batch: B+E appended
// x64, one 'S' flush, row.next drains every DataRow to 'Z'.

import koru/pg
import std/io

koru/pg:connect(host: "127.0.0.1", port: 5432, user: "benchmarkdbuser", database: "hello_world")
| err e |> std/io:print.ln("connect failed: {{ e:s }}")
| ok conn |> koru/pg:prepare(conn, name: "s1", sql: "SELECT id, randomNumber FROM world WHERE id = $1")
    | err e |> std/io:print.ln("prepare failed: {{ e:s }}")
    | ok _ |> for(0..313)
        ! each _ |> for(0..64)
            ! each _ |> koru/pg:bind.exec(conn, stmt: "s1", param: "7")
        |> koru/pg:send.pending(conn)
            | err e |> std/io:print.ln("send failed: {{ e:s }}")
            | ok _ |> koru/pg:row.next(conn): _
                |> for(0..65) // drain 64 rows + C frames + Z
                    ! each _ |> koru/pg:row.next(conn): _
|> std/io:print.ln("done ~20032 pipelined queries")
