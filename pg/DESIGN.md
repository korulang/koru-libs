# pg — a native pgwire driver for Koru

Lars's ruling (2026-10-28): make Postgres *perfect* — worth more than any
benchmark. `pq` (libpq binding) and `sqlite3` (C binding) are both
binding-era shapes; pgwire is a documented wire protocol with no C layer
to imitate, so this surface is designed from Koru's idioms outward.

## Why native, not libpq

- libpq's `PGresult` object model forces materialization + copies per
  query — wrong shape for a server that streams rows.
- Its async surface (PQsendQuery/PQconsumeInput/PQgetResult) proved the
  need but adds an adapter layer: state machine outside our control.
- A native driver owns the socket bytes end-to-end: zero-copy field
  views into the recv buffer, the driver's own state machine, suspension
  as a first-class concept — no handoff.

## The surface (target)

- **Phantom lifecycle**: `Conn<connecting!|connected!|in_tx!|failed!>`,
  `Result<!result>`, rows `<!row>` — use-after-close/misuse are compile
  errors, like pq's retrofit but designed-in.
- **[comptime|transform] query** — lift sqlite3's pattern and exceed it:
  SQL literal → parsed at compile time → extended-protocol (Parse/Bind/
  Execute) emitted once, with the row decode shape generated per query.
- **Streaming rows** — `DataRow` messages yield one row at a time; the
  surface never forces materialization (rows/next + scol.*, à la
  sqlite3's stream mode).
- **Pipelining first-class** — pgwire batches queries per roundtrip;
  expose batch send/recv, not just single-shot.
- **Zero-copy fields** — column values are views into the recv buffer,
  valid until the next read; no per-row allocation.
- **Event-loop-native fd** — the driver operates on a caller-owned
  nonblocking fd: `drive` (step the state machine on readable/writable),
  not a hidden thread. The pump suspension is internal.
- **Per-worker conns** — one conn per pump worker, pooled at the surface.

## pgwire essentials

Frame: 1B type + 4B len (includes len, excludes type) + payload.
Frontend: startup (196608), 'Q' query, 'P' parse, 'B' bind, 'D'
describe, 'E' execute, 'S' sync, 'H' flush, 'X' terminate.
Backend: 'R' auth (0 ok, 3 cleartext, 5 md5, 10-12 SASL),
'S' ParameterStatus, 'K' BackendKeyData, 'Z' ReadyForQuery,
'T' RowDescription, 'D' DataRow, 'C' CommandComplete, 'E' Error.
Auth needed for TFB/HttpArena: trust + md5 (+ SCRAM later).
world row = (id int4, randomNumber int4); fortune = (id int4, message text).

## Build plan

1. Socket layer: caller-owned nonblocking fd, read/write into driver
   buffers (posix or std primitives — check std first).
2. Frame codec: parse a byte stream into typed backend messages.
3. startup + auth (trust, then md5) + 'Z' ready → connected.
4. Simple 'Q' query → T/D/C stream → row views.
5. Extended protocol + comptime transform.
6. Pump integration: exchange suspension on pg fd readiness
   (same class as /delay park, readiness-driven).
7. TFB routes: /db, /queries, /fortunes, /updates, /cached-worlds.

## Instruments it serves

- HttpArena async-db / production-stack profiles.
- TechEmpower db/queries/fortunes/updates/cached-worlds (5 of 7 tests).
- The toolchain proof: real async protocol driver expressed in Koru.

## Spike result (2026-10-28)

Raw-Zig pgwire spike (/tmp/pg-spike/main.zig, zig 0.15.2, docker
postgres:17 trust auth, hello_world.world 10k rows, loopback):
**6,916 q/s** — 100k serial simple-protocol 'Q' queries, blocking
socket, rows decoded correctly (id=10000 rn=6123). ~144µs/query is
Postgres's own parse+plan+exec + one roundtrip per query, NOT codec.
Levers measured next: (a) extended protocol + prepared statements
(kills parse/plan per query), (b) query pipelining (N queries per
roundtrip — the multiplier), (c) zero-copy decode. TFB leaders do
prepared+pipelined on pooled conns: 200-600K q/s on bigger rigs.

## Spike result 2 — extended protocol + pipelining (2026-10-28)

Same rig: serial prepared 'P'+'BDE'+'S' = **6,647 q/s** (prepared alone
buys ~nothing serial — roundtrip dominates); **pipelined x16 (B+D+E
batched, one S per batch) = 38,191 q/s** — 5.7× serial, rows still
correct. Postgres's ~26µs/query inside the batch is now the cost —
bigger batches + binary params + result-format skipping are next levers.
The multiplier is real: pipelining is the pg-native win libpq can't
express.

## Spike result 3 — batch sweep, B+E only (2026-10-28)

Dropped per-query Describe (row shape known → DataRow arrives anyway):
x4 22K, x16 49.8K, x64 52.2K, x128 34.8K (dip — likely send-buffer
boundary), x256 59.4K q/s. Single-conn ceiling ~50-60K q/s on this rig —
~7-8× serial. The next multiplier isn't deeper batching, it's conn
PARALLELISM: one conn pins one postgres backend process; TFB leaders
pool 4-8 conns/worker to spread across backends. Confirms the design:
per-worker pooled conns is the fast path, not a nicety.

## Spike result 4 — conn parallelism (2026-10-28)

Thread-per-conn, each pipelined x64, 50K q total: 1c 49K, 2c 131K,
**4c 166K (peak)**, 8c 95K, 16c 73K, 32c 79K. Peak at 4 conns on this
docker-VM rig — postgres backends + loopback contention past that.
Design read: per-worker pool of ~4 conns is the fast shape; single-conn
understates the driver by ~3.4×. On metal (more cores, real NUMA) the
curve moves right — pool size should be configurable, not baked.

## Pump suspension design (2026-10-28 — for orisha drive|race)

Precedent: /delay's park machinery (pump.kz ~750-810) — `park_until`
ms deadline + sorted list + `parkMsUntilDue` in the ring wait. The pg
wake is fd-READINESS not a deadline — sibling mechanism, not a reuse:

- **Worker pg conn**: `worker.pg: ?*pg.Conn` — one per worker (pool of
  N later; spike showed ~4/worker is the sweet spot). Registered on the
  worker's ring as a new cqe class (PG_READ) with the pg conn as
  userdata — NOT a client ConnState.
- **Exchange parks on pending**: handler returns a `pending_pg` response
  variant — pump sends bind.exec (B+E appended to pg.tx, flush once per
  batch), marks the client conn's exchange suspended-on-pg, pushes it on
  the pg conn's waiter queue. Client conn's send interest can stay armed
  (pipelined requests behind it still flow when their results land).
- **Resume on PG_READ**: pg fd readable → pg:row.next drains → for each
  waiting exchange the row completes → resume → stage response → arm
  send. Multiple waiters share one pg roundtrip — that's the batch
  fan-in the 136K q/s pipeline proves.
- **Handler contract (the open semantic)**: Response gets a
  `pending_pg` variant — route declares the query; the row-result
  completes through a named continuation the route registers. Two-phase:
  declare → resume-with-row → produce Response. /queries batches N
  binds; /updates writes; /fortunes needs a fetch-all + sort + template
  (no suspension shape change).
- **Ordering**: pipelined requests on one client conn that all suspend —
  results must stage in request order (the send_plan already handles
  out-of-order staging per conn? — verify).
