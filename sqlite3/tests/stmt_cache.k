// Test: the per-connection statement cache in libs/sqlite3:default.
// Two sites with byte-identical SQL: the first prepares and caches, the
// second is a guaranteed cache hit — same rows must come back, and the
// statement must be reset (not finalized) between calls or the second
// site would observe a dead statement.
// A third site with *different* SQL confirms the map keys on text, not
// on shape, and `close` finalizes every cached statement.

import libs/sqlite3
import std/io

libs/sqlite3:open(path: ":memory:")
| db d |> libs/sqlite3:exec(conn: d, sql: "CREATE TABLE t (id INTEGER)")
    | ok |> libs/sqlite3:exec(conn: d, sql: "INSERT INTO t VALUES (1), (2)")
        | ok |> libs/sqlite3:default(conn: d) {
                SELECT id FROM t ORDER BY id
            }
            ! row r |> libs/sqlite3:col.int(stmt: r, index: 0): id |> std/io:print.ln("a{{ id:d }}")
            | done d2 |> libs/sqlite3:default(conn: d2) {
                    SELECT id FROM t ORDER BY id
                }
                ! row r2 |> libs/sqlite3:col.int(stmt: r2, index: 0): id2 |> std/io:print.ln("b{{ id2:d }}")
                | done d3 |> libs/sqlite3:default(conn: d3) {
                        SELECT COUNT(*) FROM t
                    }
                    ! row r3 |> libs/sqlite3:col.int(stmt: r3, index: 0): n |> std/io:print.ln("count={{ n:d }}")
                    | done d4 |> libs/sqlite3:close(conn: d4) |> std/io:print.ln("done")
                    | err e3 |> libs/sqlite3:close(e3.conn) |> std/io:print.ln("count err: {{ e3.msg:s }}")
                | err e2 |> libs/sqlite3:close(e2.conn) |> std/io:print.ln("select2 err: {{ e2.msg:s }}")
            | err e |> libs/sqlite3:close(e.conn) |> std/io:print.ln("select err: {{ e.msg:s }}")
        | err _ |> libs/sqlite3:close(conn: d) |> std/io:print.ln("insert err")
    | err _ |> libs/sqlite3:close(conn: d) |> std/io:print.ln("create err")
| err _ |> std/io:print.ln("Open error")
