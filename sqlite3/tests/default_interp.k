// Test: libs/sqlite3 { SQL with {{var:hint}} } — interpolation
// binds a literal into the prepared statement (scope-bound
// vars ride the same splice path; scope typing is the pending core gap).

import libs/sqlite3
import std/io

libs/sqlite3:open(path: ":memory:")
| db d |> libs/sqlite3:exec(conn: d, sql: "CREATE TABLE users (id INTEGER, name TEXT)")
    | ok |> libs/sqlite3:exec(conn: d, sql: "INSERT INTO users VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Carol')")
        | ok |> libs/sqlite3(conn: d) {
                SELECT name FROM users WHERE id = {{ 2:d }}
            }
            ! row r |> libs/sqlite3:col.text(stmt: r, index: 0): nm |> std/io:print.ln("name={{ nm:s }}")
            | done d4 |> libs/sqlite3:close(conn: d4) |> std/io:print.ln("done")
            | err e |> libs/sqlite3:close(e.conn) |> std/io:print.ln("query error: {{ e.msg:s }}")
        | err e3 |> libs/sqlite3:close(conn: d) |> std/io:print.ln("Insert error: {{ e3.msg:s }}")
    | err e4 |> libs/sqlite3:close(conn: d) |> std/io:print.ln("Create error: {{ e4.msg:s }}")
| err _ |> std/io:print.ln("Open error")
