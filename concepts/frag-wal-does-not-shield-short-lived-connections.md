---
type: belief
id: frag-wal-does-not-shield-short-lived-connections
provenance: campfire koru app, wrk -c16 against a WAL-mode Rails seed — 775 SQLITE_BUSY "database is locked" errors on pure SELECTs, zero once sqlite3_busy_timeout(5000) went into `open`
ts: 2026-10-05
tags: [sqlite3, wal, concurrency, koru-libs, measured]
---

# WAL does not shield short-lived connections — busy_timeout is the adapter contract

The prior belief: "the DB is in WAL mode, so readers never see `database is
locked`." Measured wrong: a Koru server opening a fresh `sqlite3` connection
per request logged 775 `SQLITE_BUSY` failures on plain `SELECT`s over ~166k
requests — no writers running.

WAL protects *steady-state* readers from a writer. It does not protect the
connection *lifecycle*: every fresh connection's first read attaches to the
wal-index shared-memory region, and every `sqlite3_close` on the last open
connection runs a WAL checkpoint. Under a server churning open→query→close
across worker threads on one file, those two paths contend — the attach sees
a checkpoint in progress (or a stale shm needing recovery) and `sqlite3_step`
on a `SELECT` returns `SQLITE_BUSY`.

The durable ruling: **`sqlite3_busy_timeout` is part of `open`, not an opt-in.**
Every real adapter does this — Rails' sqlite3 adapter applies
`timeout: 5000` from `database.yml` unconditionally. An `open` that omits it
hands every consumer a per-request coin flip at load, and the failure is
silent-corrupting: an app that maps err→nil turns lock contention into wrong
answers (Campfire's auth gate 302'd valid sessions) rather than errors.

Open question the measurement leaves: per-request open/close is itself the
wrong shape for a server — a per-worker persistent connection removes the
churn entirely (and 12k req/s worth of open/close syscalls). `busy_timeout`
makes the current shape *correct*; pooling would make it *fast*. Those are
different obligations.
