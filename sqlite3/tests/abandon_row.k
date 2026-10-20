import libs/sqlite3
import std/io

libs/sqlite3:open(path: ":memory:")
| db d |> libs/sqlite3:exec(conn: d, sql: "CREATE TABLE t (id INTEGER)")
    | ok |> libs/sqlite3:exec(conn: d, sql: "INSERT INTO t VALUES (1)")
        | ok |> libs/sqlite3:query(conn: d) { SELECT id FROM t }
            | row r |> libs/sqlite3:scol.int(stmt: r, index: 0): i
                |> std/io:print.ln("got {{ i:d }}")
                |> libs/sqlite3:finalize.stmt(stmt: r): c
                |> libs/sqlite3:close(conn: c)
                |> std/io:print.ln("abandoned clean")
            | empty d3 |> libs/sqlite3:close(conn: d3) |> std/io:print.ln("empty")
            | err e |> libs/sqlite3:close(e.conn) |> std/io:print.ln("err")
        | err _ |> libs/sqlite3:close(conn: d) |> std/io:print.ln("insert err")
    | err _ |> libs/sqlite3:close(conn: d) |> std/io:print.ln("create err")
| err _ |> std/io:print.ln("Open error")
