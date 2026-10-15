// Test: libs/sqlite3 { DDL } with no `! row` branch — statement
// semantics: stepped through, `| done` on SQLITE_DONE.

import libs/sqlite3
import std/io

libs/sqlite3:open(path: ":memory:")
| db d |> libs/sqlite3(conn: d) {
        CREATE TABLE t (id INTEGER)
    }
    | done d2 |> libs/sqlite3(conn: d2) {
            INSERT INTO t VALUES (7)
        }
        | done d3 |> libs/sqlite3(conn: d3) {
                SELECT id FROM t
            }
            ! row r |> libs/sqlite3:col.int(stmt: r, index: 0): id |> std/io:print.ln("id={{ id:d }}")
            | done d4 |> libs/sqlite3:close(conn: d4) |> std/io:print.ln("done")
            | err e |> libs/sqlite3:close(e.conn) |> std/io:print.ln("select err: {{ e.msg:s }}")
        | err e2 |> libs/sqlite3:close(e2.conn) |> std/io:print.ln("insert err: {{ e2.msg:s }}")
    | err e1 |> libs/sqlite3:close(e1.conn) |> std/io:print.ln("create err: {{ e1.msg:s }}")
| err _ |> std/io:print.ln("Open error")
