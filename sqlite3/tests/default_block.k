// Test: libs/sqlite3:default { SQL } — the module's voice.
// Per-row `! row` iteration + {{var:hint}} scope interpolation, in
// continuation position (the site-local transform path).

import libs/sqlite3
import std/io

libs/sqlite3:open(path: ":memory:")
| db d |> libs/sqlite3:exec(conn: d, sql: "CREATE TABLE users (id INTEGER, name TEXT)")
    | ok |> libs/sqlite3:exec(conn: d, sql: "INSERT INTO users VALUES (1, 'Alice'), (2, 'Bob')")
        | ok |> libs/sqlite3:default(conn: d) {
                SELECT id FROM users ORDER BY id
            }
            ! row r |> libs/sqlite3:col.int(stmt: r, index: 0): id |> std/io:print.ln("id={{ id:d }}")
            | done d4 |> libs/sqlite3:close(conn: d4) |> std/io:print.ln("done")
            | err e |> libs/sqlite3:close(e.conn) |> std/io:print.ln("query error: {{ e.msg:s }}")
        | err e3 |> libs/sqlite3:close(conn: d) |> std/io:print.ln("Insert error: {{ e3.msg:s }}")
    | err e2 |> libs/sqlite3:close(conn: d) |> std/io:print.ln("Create error: {{ e2.msg:s }}")
| err _ |> std/io:print.ln("Open error")
