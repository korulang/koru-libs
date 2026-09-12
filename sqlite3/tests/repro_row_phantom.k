// Terminal-path row access: `| row` carries BOTH obligations on the same
// object — `stmt` (lifetime, needs finalize/next) and `row` (the live row
// borrow col.* reads). next(r.conn, r.stmt, r.row) consumes both per step.

import libs/sqlite3
import std/io

libs/sqlite3:open(path: ":memory:")
| db d |> libs/sqlite3:exec(conn: d, sql: "CREATE TABLE t (id INTEGER, name TEXT)")
    | ok |> libs/sqlite3:exec(conn: d, sql: "INSERT INTO t VALUES (1, 'alice'), (2, 'bob')")
        | ok |> libs/sqlite3:query(conn: d) {
                SELECT name FROM t ORDER BY id
            }
            | row r |> libs/sqlite3:col.text(stmt: r.row, index: 0): name
                |> std/io:print.ln("row0={{ name:s }}")
                |> libs/sqlite3:next(r.conn, r.stmt, r.row)
                    | row r2 |> libs/sqlite3:col.text(stmt: r2.row, index: 0): n2
                        |> std/io:print.ln("row1={{ n2:s }}")
                        |> libs/sqlite3:next(r2.conn, r2.stmt, r2.row)
                            | row _ |> std/io:print.ln("unexpected third row")
                            | done d4 |> libs/sqlite3:close(conn: d4) |> std/io:print.ln("done")
                            | err e |> libs/sqlite3:close(e.conn) |> std/io:print.ln("next err: {{ e.msg:s }}")
                    | done d3 |> libs/sqlite3:close(conn: d3) |> std/io:print.ln("done after one")
                    | err e2 |> libs/sqlite3:close(e2.conn) |> std/io:print.ln("next err: {{ e2.msg:s }}")
            | empty d3 |> libs/sqlite3:close(conn: d3) |> std/io:print.ln("empty")
            | err e |> libs/sqlite3:close(e.conn) |> std/io:print.ln("query err: {{ e.msg:s }}")
        | err _ |> libs/sqlite3:close(conn: d) |> std/io:print.ln("insert err")
    | err _ |> libs/sqlite3:close(conn: d) |> std/io:print.ln("create err")
| err _ |> std/io:print.ln("Open error")
