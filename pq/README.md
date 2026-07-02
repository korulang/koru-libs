# pq — the definitive Koru libpq (PostgreSQL) edition

**One-line pitch**: libpq lifted behind phantom-typed connection/result obligations — forgotten `disconnect`/`result.clear` and post-disconnect use are compile errors.

**Entry type**: quality pass (language-migration + a real correctness fix) on the existing `pq` package.

**Author**: Claude Sonnet 5, contestant session (worktree `agent-a3d876d3c8e1c4edd`), 2026-07-02.

## What the C library does, and what we lift

libpq is PostgreSQL's canonical C client library — connection management,
query execution (`PQexec`), and a manually-freed `PGresult` object model with
no compiler help for forgetting `PQfinish`/`PQclear` or using a connection
after closing it. We lift it behind Koru's phantom obligation system: the
connection carries a `<connected!>` obligation discharged by `disconnect`,
and every query result carries a `<result!>` obligation discharged by
`result.clear` — both enforced at compile time, with auto-discharge covering
the common case where the binding just falls out of scope.

## Starting state and what this pass did

`pq/` was entirely dead on arrival — nothing in it compiled:

- Every `~proc` in `index.kz` was declared bare (no `|host` tag), which is a
  hard `KORU110` compile error at any call site under the current
  variant-mandatory rule (proven by the koru suite's own
  `tests/regression/300_ADVANCED_FEATURES/370_VARIANTS/8211_bare_proc_call_site_fails`).
  Fixed: tagged all 8 procs `|zig` — `connect` (index.kz:41), `disconnect`
  (:60), `exec` (:77), `query` (:94), `result.nrows` (:114), `result.col`
  (:126), `result.clear` (:137), `sql` (:158) — grounded against
  `vaxis/index.kz`, the currently-accurate exemplar (see Toolchain findings
  below for why `sqlite3/index.kz`, the exemplar named in the brief, was
  **not** trustworthy here).
- The four examples used a chaining syntax that predates the current rule
  that `|>` is inline glue and can never start a line. Fixed: every `|>`
  step now stays glued to the line of the step it continues, grounded in
  `sqlite3/tests/chained_exec.kz` and the `810_AOC_2015` corpus's long
  single-line chains.
- `examples/02_exec.kz`'s row loop called `std/control:for(0..n)`, which
  does not exist. The real construct is the `~for`/`for(...)` keyword
  (grounded in `koru_std/control.kz` and
  `tests/regression/300_ADVANCED_FEATURES/320_STDLIB/320_021_for_zero_overhead/input.kz`);
  nested inside a continuation it drops the `~` per the compiler's own
  `PARSE001` hint ("Nested flows (~) are not allowed inside continuations").
  Also added the required `:d`/`:s` format specifiers to `{{ }}`
  interpolations (`std/io:print.ln` rejects a bare `{{ i }}` with
  `'{{ i }}' requires a format specifier`).
- `result.col` (index.kz:121) declares hyphenated branch names (`is-null`,
  `no-such-col`), but its Zig body returned them with the hyphens intact
  (`.no-such-col`), which is not a legal Zig field name. Fixed to the
  underscored form (`.no_such_col` / `.is_null`, index.kz:128-129) — exactly
  the convention the koru suite's own
  `tests/regression/900_EXAMPLES_SHOWCASE/910_LANGUAGE_SHOOTOUT/2104_17_open_tx_multiple_execs/db.kz`
  uses for its `rolled-back` → `.rolled_back` variant.
- **Found and fixed a genuine use-after-free bug** — not a syntax migration
  issue. See "Correctness" below.
- Removed pre-existing, wrongly-committed compiler-output artifacts
  (`build.zig`, `build_backend.zig`, `compiler_env.zig`, `program_ast.zig`)
  from git tracking and added `pq/.gitignore` so this can't silently
  recur.
- Filled the previously-empty `pq/tests/` with three tests (below); it had
  zero coverage before this pass.

## The quadrifecta self-audit

- **DX**: the happy path is
  `~koru/pq:connect(conninfo: "...") | ok conn |> ... | err msg |> ...` —
  no manual `PQfinish`/`PQclear` bookkeeping in the common case;
  auto-discharge closes the connection when `conn` falls out of scope
  (`examples/01_connect_auto.kz`, functionally identical to the explicit
  version `01_connect.kz`). Errors carry the real libpq message text
  (`e:s`), not an opaque status code.
- **Performance**: the phantom obligation tracking and comptime SQL
  (`~[comptime]koru/pq:sql`) are pure compile-time constructs. `Conn` and
  `Result` (index.kz:25-31) are one-field structs wrapping the raw C
  pointer — no extra indirection over hand-written libpq C. Unmeasured
  against hand-written C for query throughput: no live server was reachable
  in this sandbox (see Proof of life).
- **Correctness**: use of a `*Conn` after `disconnect` is a compile error —
  `pq/tests/negative_use_after_disconnect.kz` is rejected with
  `error[KORU030]: Use-after-discharge: binding 'conn' was already
  discharged and cannot be used` (pasted verbatim below). Separately, and
  more interestingly: `connect` (index.kz:41) and `sql` (index.kz:158) both
  called `PQfinish()` — which frees the connection and invalidates any
  pointer previously returned by `PQerrorMessage()` — either immediately
  before, or (in `sql`) via `defer` around, the construction of
  `.{ .err = std.mem.span(msg) }`. The returned `[]const u8` pointed at
  already-freed memory. Confirmed empirically, not by inspection alone:
  three consecutive runs of the *identical* binary printed three different
  garbage byte sequences after `"Connection failed: "` —
  `0x28 0x10`, `0xc4 0x23`, `0xb9 0x23` — the textbook signature of reading
  freed heap (contents vary run to run under ASLR/heap state, same code
  path). Fixed by duplicating the message into an owned
  `page_allocator` buffer *before* calling `PQfinish` in both procs. Re-ran
  the same binary three times post-fix: byte-identical, correct 306-byte
  libpq message every time.
- **Resource safety**: `<connected!>` and `<result!>` are compiler-enforced
  obligations (auto-discharge or explicit `disconnect`/`result.clear`,
  index.kz:53-137). The use-after-free above closes the one hole phantom
  typing structurally *couldn't* catch in this pass's scope, because the
  danger was inside the raw Zig implementation of the phantom-typed event
  itself, not in a caller's misuse of the Koru-level API.

## What it explicitly doesn't do (yet)

Transactions, prepared statements, async, pipeline mode, COPY, LISTEN/NOTIFY,
large objects, connection pooling — all deliberately out of scope for this
pass; see `DESIGN.md` for the full roadmap. This pass is alignment (make it
compile against the current language) plus minimal test coverage on the
existing connect/exec/query/comptime-sql surface only, per the brief.

## Toolchain findings

1. **`sqlite3/index.kz`, the exemplar named in the brief, is itself stale.**
   Every `~proc` in it is bare — `koruc --check sqlite3/tests/basic.kz`
   currently fails with `error[KORU110]: event 'open' is called but its
   ~proc declaration has no |variant tag`. `vaxis/index.kz` is the
   currently-accurate exemplar for proc tagging (`~proc run|zig`, etc). Not
   fixed here — out of this pass's `pq/`-only scope — flagging so it
   doesn't mislead the next contestant who reads the brief's pointer at
   face value.
2. **`[comptime]` events currently fail past shape-checking.** Confirmed
   independent of pq: the koru repo's own `MUST_RUN` regression test
   `tests/regression/300_ADVANCED_FEATURES/310_COMPTIME/310_049_invocation_meta/input.kz`
   fails a fresh `koruc run` today with
   `error: no field named 'no_annotation' in enum ...`. `pq/examples/02_sql.kz`
   (comptime SQL) hits the same feature area from a different angle:
   `koruc --check` passes, but `koruc run`/`build` fails during **backend**
   compilation (Stage B) with `error: missing struct field: invocation` on
   the `std/io:print.ln` call inside the comptime event's `| ok |>`
   continuation, plus a separate include-path miss
   (`'libpq-fe.h' file not found`) in the backend's own `@cImport`. Minimal
   repro shape: any `[comptime]pub event` whose continuation calls a plain
   (no-interpolation) `std/io:print.ln`. Pinned as a suspected core-toolchain
   defect in the `[comptime]` event backend-codegen path — not something
   this pass's scope, or a library-side workaround, should paper over.
   `02_sql.kz`'s `--check` gate passes; its full-build gate is honestly red
   and left undone.
3. Not a bug, recorded for completeness: a previous session pinned a
   `KORU100` false-positive (interpolated bindings inside `~for` counted as
   unused) as a `TODO` fixture
   (`tests/regression/200_COMPILER_FEATURES/220_FLOW_CHECKER/220_012_interpolation_use_in_for_loop`).
   It does **not** reproduce today against the exact pattern pq's row-loop
   uses (`! each i |> ... | some name |> print.ln("{{ i:d }}: {{ name:s }}")`)
   — verified with a minimal isolated repro that compiled and ran clean.
   Looks fixed upstream; leaving the existing `TODO` fixture for whoever
   owns the koru suite to retire.

## Proof of life

All commands run from `pq/`; `koruc` = `/Users/larsde/src/koru/zig-out/bin/koruc`.

```
$ koruc --check index.kz
✓ Shape checking passed

$ koruc --check examples/01_connect.kz
✓ Shape checking passed
$ koruc --check examples/01_connect_auto.kz
✓ Shape checking passed
$ koruc --check examples/02_exec.kz
✓ Shape checking passed
$ koruc --check examples/02_sql.kz
✓ Shape checking passed

$ koruc --check tests/connect.kz
✓ Shape checking passed
$ koruc --check tests/exec_query.kz
✓ Shape checking passed
$ koruc --check tests/negative_use_after_disconnect.kz
✓ Shape checking passed

$ koruc run tests/connect.kz && ./a.out
...
✓ Built executable: a.out
Running a.out...

connect failed (expected without a live server): connection to server at "localhost" (::1), port 5432 failed: Connection refused
	Is the server running on that host and accepting TCP/IP connections?
connection to server at "localhost" (127.0.0.1), port 5432 failed: Connection refused
	Is the server running on that host and accepting TCP/IP connections?

$ koruc run tests/negative_use_after_disconnect.kz
...
error[KORU030]: Use-after-discharge: binding 'conn' was already discharged and cannot be used
  --> phantom_semantic_check:26:0
❌ Compiler coordination error: Phantom semantic validation failed
✗ Backend execution failed
```

`examples/01_connect.kz`, `01_connect_auto.kz`, `02_exec.kz`,
`tests/connect.kz`, and `tests/exec_query.kz` all compile and run **fully
end-to-end** — through all four koruc stages (frontend → backend build →
backend execution → output build+run) — producing a real linked binary
against real libpq. `02_sql.kz` (comptime SQL) compiles at `--check` but
hits the pre-existing `[comptime]` backend-codegen toolchain gap above at
full build.

No live PostgreSQL server was reachable in this sandbox — `pg_isready` and
`pg_config` are not on `PATH`, and the docker daemon was not running
(`docker ps` failed to reach `unix:///Users/larsde/.docker/run/docker.sock`).
libpq itself **is** installed (Homebrew, keg-only,
`/opt/homebrew/opt/libpq`), which is why the build/link/run pipeline above
gets as far as a real `PQconnectdb` call and a real, correct
"Connection refused" libpq error — this is the library's honest `err`
branch working correctly, not a stub. The `ok` branches (rows actually
returned) are unverified here; `docker compose up -d` (see
`docker-compose.yml`) would exercise them in an environment with a working
docker daemon.
