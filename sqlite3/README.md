# @korulang/sqlite3

SQLite3 lifted into Koru with phantom obligations — the compiler will not let you
forget to close a connection, or read a column from a statement that isn't on a row.

This package is the LIFT challenge's exemplar. Everything below is transcribed from
`index.kz` and the passing tests in `tests/`; nothing here is written from memory.

## Installation

```bash
koruc app.k i
```

In your program:

```koru
std/package:requires.npm { "@korulang/sqlite3": "^0.0.1" }
```

## Requirements

SQLite3 development libraries on your system:

- macOS: `brew install sqlite3` (usually pre-installed)
- Ubuntu/Debian: `apt install libsqlite3-dev`
- Fedora: `dnf install sqlite-devel`

## Usage

Open, execute, close — the shape from `tests/chained_exec.kz`, which passes:

```koru
import koru/sqlite3
import std/io

koru/sqlite3:open(path: ":memory:")
| db d |> koru/sqlite3:exec(conn: d, sql: "CREATE TABLE users (id INTEGER, name TEXT)")
    | ok |> koru/sqlite3:exec(conn: d, sql: "INSERT INTO users VALUES (1, 'Alice')")
        | ok |> koru/sqlite3:close(conn: d) |> std/io:print.ln("Done!")
        | err e |> koru/sqlite3:close(conn: d) |> std/io:print.ln("Insert error: {{ e.msg:s }}")
    | err e |> koru/sqlite3:close(conn: d) |> std/io:print.ln("Create error: {{ e.msg:s }}")
| err _ |> std/io:print.ln("Open error")
```

Every arm closes the connection. That is not politeness — omit one and the program
does not build.

Inside the repo the tests import `libs/sqlite3` (a repo-local alias). A consumer
uses `koru/sqlite3`, which resolves to the installed `koru-libs`.

## API

Read the phantom states carefully; the polarity is the whole design.

### Connection

| Tor | Signature | Arms |
|---|---|---|
| `open` | `{ path: string }` | `\| db *Connection<opened!>` · `\| err { code, msg }` |
| `close` | `{ conn: *Connection<!opened> }` | — |
| `exec` | `{ conn: *Connection<opened>, sql: string }` | `\| ok` · `\| err { code, msg }` |

`open` **mints** `opened!`. `close` **discharges** it (`<!opened>`). `exec` takes a
**bare** `<opened>` — it borrows the connection and does not consume the obligation,
so you still owe exactly one `close` afterwards.

### Rows

| Tor | Signature | Arms |
|---|---|---|
| `query.literal` | `{ conn: *Connection<!opened>, sql: string }` | `! row` · `\| done *Connection<opened!>` · `\| err { conn, code, msg }` |
| `next` | `{ conn: *Connection<!opened>, stmt: *Statement<!prepared> }` | `\| row { conn, stmt }` · `\| done` · `\| err` |
| `release.row` | `{ stmt: *Statement<!row> }` | — |

Note that every arm — including `err` — hands the connection back as
`*Connection<opened!>`. A failed query does not invalidate the connection; you still
owe the close.

### Columns

| Tor | Signature | Returns |
|---|---|---|
| `col.int` | `{ stmt: *Statement<row>, index: i32 }` | `i64` |
| `col.text` | `{ stmt: *Statement<row>, index: i32 }` | `string` |
| `col.real` | `{ stmt: *Statement<row>, index: i32 }` | `f64` |

The column readers take `*Statement<row>` — a **borrow of the row state**, not
`<prepared!>`. You cannot read a column off a statement that is not currently
positioned on a row, and reading does not consume the row.

### Finalizers

| Tor | Signature |
|---|---|
| `finalize.stmt` | `{ stmt: *Statement<!prepared> }` |
| `finalize.text` | `{ text: string<!text> }` |

`finalize.text` is worth a second look: the obligation is on a **string**. Text
columns are borrowed from the statement and are only valid until the next step, so
the borrow is tracked in the type rather than left to the reader's memory.

## Status

`tests/basic.kz` and `tests/chained_exec.kz` pass and run end-to-end.

`tests/query_parameterized.kz` is **red**, and its header says why: the inlined
`! row` effect-branch body references the bare `Statement` type, which is out of
scope at the inline site. Row iteration via `! row` is therefore documented here
but not yet demonstrated running — do not copy it as a working shape until that
codegen gap closes.

## Phantom obligations

- `*Connection<opened!>` — open, and one `close` is owed
- `*Statement<prepared!>` — prepared, finalization owed
- `*Statement<row>` — positioned on a row; borrowed by the column readers
- `string<!text>` — borrowed text, valid only until the next step

## License

MIT
