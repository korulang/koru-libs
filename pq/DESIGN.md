# `@korulang/postgres` — Design Document

A first-class PostgreSQL client for Koru. Not a thin wrapper around libpq — a
**semantic redesign** that uses Koru's phantom type system to make an entire
class of database bugs impossible at compile time.

---

## Philosophy

The libpq C API is a product of the 1990s. It is correct and battle-tested, but
its ergonomics belong to a different era:

- Transaction state is a runtime query (`PQtransactionStatus`), not a type
- Forgetting `PQclear` is a memory leak with no compiler feedback
- `PQexecParams` takes 7 arguments, several of which are nullable pointer arrays
- COPY mode is a trap: issue one wrong call and the connection is stuck
- The large object API is entirely index-based with no lifecycle guarantees

We do not simply wrap this. We **redesign the user-facing API** with Koru
ergonomics, using phantom obligations to encode what libpq only expresses in
documentation. The C layer is an implementation detail.

The goal: a PostgreSQL client where the **type of the connection** tells you
what you can do with it, and **auto-discharge** ensures resources are always
cleaned up.

---

## The Connection State Machine

This is the heart of the design. The connection carries a phantom state that
tracks exactly what mode it is in:

```
[connected]        — connected, idle, ready for queries
[in_tx]            — inside a BEGIN/COMMIT transaction
[in_failed_tx]     — inside a transaction that has errored (only ROLLBACK valid)
[copy_in]          — COPY FROM STDIN mode active
[copy_out]         — COPY TO STDOUT mode active
[pipeline]         — pipeline mode active
```

State transitions are enforced by the type system:

- `begin` consumes `[connected]`, produces `[in_tx]`
- `commit` consumes `[in_tx]`, produces `[connected]`
- `rollback` consumes `[in_tx | in_failed_tx]`, produces `[connected]`
- A query that fails inside a transaction transitions to `[in_failed_tx]`
- Only `rollback` is valid on `[in_failed_tx]`
- `copy_from` / `copy_to` consume `[in_tx]`, produce `[copy_in]` / `[copy_out]`

The `[connected]` obligation is born at `connect` and discharged at `disconnect`.
Auto-discharge ensures disconnect is called even if the flow exits early.

---

## Result Lifecycle

Every query returns a `*Result<result!>` obligation. It **must** be cleared —
either explicitly or via auto-discharge. The result is accessed by name, not by
column index.

Accessing a column by name that does not exist in the result is a compile-time
error when the query is known at compile time (via a comptime transform), and a
branch with a clear error at runtime otherwise.

---

## Large Objects

Large objects require a transaction to be active. The handle has its own
lifecycle nested inside the transaction:

- `lo_open` takes `[in_tx]`, returns `(*Conn[in_tx], *Lo<lo_open!>)`
- Both obligations must be discharged: the LO handle before committing

---

## Cancel

The cancel object has its own lifecycle independent of the connection:

- `cancel_create` creates a `*Cancel<cancel!>` obligation
- `cancel_finish` discharges it
- This separation allows cancellation from a different thread or context

---

## API Groups

### 1. Connection
The primary connection lifecycle. We expose two connection styles:

- **Simple**: `connect(url)` — single connection string, the common case
- **Parameterized**: `connect_params(host, port, dbname, user, password, ...)` — for when you need control

Connection pooling is out of scope for this library — that lives at a higher
level. We model a single connection honestly.

#### Future: `koru.pq:config` abstract event

The right pattern for library configuration is an abstract event the library
consumes, satisfied by user code via assignment:

```
~koru.pq:config = config {
    "connection": "host=localhost port=5432 ...",
}
```

Composing with the environment:

```
~koru.pq:config = std.env:get("DATABASE_URL")
| str url |> config { "connection": url }
```

The library provides sensible defaults; user code overrides only what it needs.
This is deferred — for now `koru.pq:sql` takes an explicit `conn` string argument.

### 2. Queries
Three query styles:

- **Simple exec**: fire-and-forget DDL or statements where you do not need results
- **Query**: returns rows, result accessed by column name
- **Prepared statements**: named, reusable, parameterized — first-class lifecycle

We intentionally do NOT expose `PQexecParams`-style raw calls. Parameters are
named and typed. The transformation to positional `$1/$2/...` placeholders is
handled by a comptime transform (same pattern as sqlite3's `{{param:type}}`).

### 3. Transactions
First-class, not `exec("BEGIN")`:

- `begin` / `commit` / `rollback` — explicit
- `transaction { ... }` — a comptime transform that wraps a block in
  begin/commit/rollback, auto-rolling back on any failure branch

### 4. Async
Full async interface:

- `send_query` transitions connection to `[async_pending]`
- A poll loop consumes results; the `done` branch auto-discharges `[async_pending]`
  and re-emerges with `[connected]`

### 5. Pipeline Mode
Pipeline mode transitions the connection to `[pipeline]`. Queries are sent
without waiting for responses. `sync` flushes and processes responses.
`exit_pipeline` returns to `[connected]`.

### 6. COPY
Typed streaming interface:

- `copy_from(table, columns)` — transitions to `[copy_in]`, returns a writer
- `copy_to(query)` — transitions to `[copy_out]`, returns a reader
- The writer/reader obligations must be finished before any other query

### 7. Notifications
`LISTEN`/`NOTIFY` via `PQnotifies`. Polled after any query call.

### 8. Large Objects
Full lo_* interface, gated behind `[in_tx]`.

### 9. Cancel
Full cancel lifecycle as a separate object, safe for cross-thread use.

---

## Examples We Will Build

These are the tests that prove the design. Every example compiles and runs
against a real PostgreSQL instance.

### `examples/connect.kz`
Open a connection, run a trivial query, close. The "hello world".

### `examples/transaction.kz`
Begin a transaction, insert two rows, commit. Then: begin, insert, force a
failure, demonstrate that only rollback is now valid.

### `examples/prepared.kz`
Prepare a statement once, execute it multiple times with different parameters.
Show that the prepared statement handle has its own lifecycle.

### `examples/copy_from.kz`
Bulk-load 10,000 rows via COPY FROM — show the copy_in state and the streaming
writer interface.

### `examples/async.kz`
Send multiple queries asynchronously, collect results in order.

### `examples/pipeline.kz`
Enter pipeline mode, send a batch of queries, sync, process results.

### `examples/notify.kz`
LISTEN on a channel, send a NOTIFY, receive it.

### `examples/large_object.kz`
Create, write, read, and delete a large object inside a transaction.

### `examples/real_app.kz`
A complete mini-application: schema migration, parameterized query, transaction
with rollback on error, COPY bulk load, notification. Everything in one flow.
This is the showpiece.

---

## System Dependencies

```
check:  pg_config --version
brew:   libpq
apt:    libpq-dev
dnf:    postgresql-devel
pacman: postgresql-libs
apk:    postgresql-dev
```

Build link: `exe.linkSystemLibrary("pq")` + `exe.linkLibC()`

C header: `libpq-fe.h` (for main API) + `libpq/libpq-fs.h` (for large objects)

---

## Phase 2: Connection Pooling

Connection pooling is deliberately deferred — but it is not out of scope. It
belongs here, and it is actually a **better** demonstration of phantom
obligations than single-connection lifecycle management.

The reason: a pool makes the obligations structural at scale. When you check out
a connection from the pool, you receive a `*Conn<checked_out!>` where the
discharge target is the pool itself, not a close operation. The obligation means
"return me to where I came from." Auto-discharge handles the forgotten-return
case automatically. And because each checked-out connection is a distinct
binding with its own independent obligation, you can hold N connections
simultaneously and the compiler tracks every single one.

No runtime reference counting. No "did I return this?" bugs. No pool starvation
from forgotten handles. It is enforced structurally.

We build the single-connection library first. Pooling comes after we have
validated the core design.

---

## What We Are NOT Building

- An ORM
- Schema migration tooling (separate concern)
- Replication protocol support
- Extensions (PostGIS, etc.) — though the query interface handles them naturally

---

## Quality Bar

- Every public event has a test
- Every phantom state transition is demonstrated in at least one example
- The `real_app.kz` example is a complete, working application
- No example uses a raw libpq call that we have not surfaced as a first-class event
- `koruc deps` installs libpq cleanly on macOS, Ubuntu, Arch, and Alpine
- **Auto-discharge must emit byte-identical Zig to explicit discharge.** `01_connect_auto.kz`
  and `01_connect.kz` must produce identical `output_emitted.zig`. This is a compiler
  invariant tracked by a regression test. The `~[no_auto_discharge]` module annotation
  (not yet implemented) will allow opting out per-module.

---

*This document is aspirational. It is also a contract. We build everything in it.*
