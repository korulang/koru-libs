# asteroids-net — authoritative UDP Asteroids

The first `SERVER_CHALLENGE.md` replay: the asteroids sim forked for N
players over real datagrams. Three programs share `sim/` + `wire/`:

    koruc build server.k   # authoritative server on :7777, unbounded ticks
    koruc build client.k   # raylib client — WASD/arrows, space to fire
    koruc run   bot.k      # scripted headless client (the smoke test)
    koruc build driver.k   # thrusting probe + loss oracle (isolation pair, below)
    koruc build watcher.k  # parked probe — asserts ITS ship never moved
    ./test.sh              # the whole probe, self-contained (~15s): builds
                           # all three, spawns its own server, asserts both
                           # oracles, exits nonzero on any red

## Shape

- `udp` — nonblocking POSIX datagrams, `*Socket<bound>` phantom lifecycle,
  `packets` drain effect. No C deps.
- `clock` — `ticks { count: ?i64 }`: the raylib `frames` optional-count
  idiom for a headless loop. Unbounded by default; a server runs until
  killed. (Wants a `std/time:ticks` or `std/control:loop` home.)
- `sim` — the single-player rules + `owner` column, a `players` session
  store keyed by `packet.key`, find-or-join `drive`, stale sweep that
  takes the session row AND its ship.
- `wire` — fixed-layout big-endian codec: `KAI2` sequenced input flags
  up (seq u32 = client tick · flags u8), `KAS3` full-state snapshots
  down (tick u32 · count u16 · `you` u8 join-ack · `indrop` u16 · pad ·
  28B entities · score/wave trailer). `you`/`indrop` are patched
  per-recipient in `snap.send` — the fan-out loop is the return channel
  for "what the server believes about YOUR session": which ship is
  yours, and how many of your inputs never arrived.
- `server.k` — drain → drive → tick → sweep → broadcast, ~60Hz, heartbeat
  receipts every 600 ticks.
- `client.k` — input flags up every frame; snapshots clear+refill a `view`
  store and paint it, own ship cyan via `snap.you`. No client-side
  prediction — the window IS the server's authoritative state.
- `bot.k` — 100 input packets, 120 silent ticks; proves join, remote
  thrust, replication, and stale removal without a display.
- `driver.k` / `watcher.k` — the owner-isolation pair. Driver thrusts;
  watcher joins, keepalives a zero-flag packet every 30 ticks (~0.5s —
  every send runs `sim:drive`, which touches `p.last`), parks, and
  listens. Watcher learns its pid from `you` and asserts its OWN ship
  never moved while the driver's did — a cross-owner input leak fails
  the first half. Driver doubles as the loss oracle: it withholds ticks
  140–144 outright, opening a real 5-packet seq gap, then asserts the
  server measured exactly 5 via `snap.indrop`.

## Measured (first two-process smoke)

- bot: 190 snapshots, ship drifted (63,572) → (589,387) under remote thrust
- server: exactly 100 pkts in, `nextpid 2`, player dump empty at end —
  the sweep took session + ship
- raylib client live: 271 pkts in / 239 snaps out on the first run

## Measured (three-way live run)

- One human raylib client + two concurrent bots on one unbounded server:
  `nextpid 4`, both bots saw identical world views (`last count 9` = 6
  rocks + 3 ships), both ships flew the scripted path, heartbeat showed
  only the human's row after the bots' 90-tick silence swept them.
- 12k+ input pkts / 10k+ snaps over a 4-minute session — the loop doesn't
  degrade with uptime.
- NOT yet pinned: strict owner-isolation needs asymmetric inputs — two
  identical scripts can't distinguish "each drove its own ship" from
  "inputs applied to all ships" (thrust is idempotent per tick). The
  staggered-start variant (offset bot B so its thrust window lands in A's
  silence) is the honest version of that test. DONE, stronger: the
  driver/watcher pair below asserts per-pid, not just asymmetric.

## Measured (join-ack + owner isolation)

- Watcher keepalives, driver thrusts: `watcher: 353 snaps, pid 5 —
  1 mine-parked, 1 parked, 1 driving` → `ISOLATION: PASS`. The pid came
  off `snap.you` — the watcher's own ship pinned parked by identity,
  not by "some ship didn't move" — and the keepalive held the session
  for the whole ~6s window (353 snaps vs ~91 silent). Watcher exits
  clean (the join-time double-free is gone — koru `166190187`).

## Measured (input-loss telemetry, KAI2/KAS3)

- Driver withholds ticks 140–144 (a real gap, not a flag): server counts
  `drops += 5` at the next seq, echoes it per-recipient as `indrop`.
  Driver: `359 snaps, last count 6, indrop 5` → `LOSS-ORACLE: PASS`.
- Same run: `watcher: 356 snaps, pid 2 — 1 mine-parked, 1 parked,
  1 driving` → `ISOLATION: PASS`.
- Semantics: `seq > lseq` is fresh input (gap → `drops`, apply); `seq <=
  lseq` is dup/reorder — liveness touch only, never re-applied.

## Compiler contours this slice surfaced

- Branch arms ARE the continuation — a branched call ends its enclosing
  flow (box it in a tor, e.g. `push-input`, to keep a chain linear).
- Terminal `! query` / `|> if` end flows — split find-or-join into
  `find-touch` + `drive`; move unconditional reads before the branch.
- Proc-body `__`-locals were NOT hygienic — nested `packets`/`ticks`
  collided on `__i`, std/io's print helper `__f` collided with raylib's
  `__f`. Fixed in koru (`__x` → `__x_s{N}` per splice site, pin 400_192).
- `for` index is usize-like — declare loop-index params `usize`, not i64.
- `~import std` in a `.kz` pulls the whole umbrella including the
  unparseable `ccp_aspirational.kz` — import narrowly (`std/build` etc).
- A branched call's `| err` arm can't `std/io:print` inside raylib's
  `! frame` arm pre-hygiene-fix — it can now.
- `if(<row>.<field>)` under a `! query` arm froze raw row refs into the
  template's `inline_body` before the sweep rewrite ran — emitted
  `undeclared identifier 'e'`. Fixed in koru `5632e47` (pin 690_312):
  the sweep walk now reaches into the frozen text, and the walk target
  must be `var` — `@constCast` on a const local silently drops the write.
- An inherited owned resource discharged inside conditional arms AND at
  the join — double-free on watcher exit. Fixed in koru `166190187`
  (pin 400_193): obligations are live-through a join continuation.

## Gap list (the next slices)

- Reliability is measured, not repaired: input seq gaps count into
  `indrop` and dup/reorder is detected — but there are no acks, no
  resend, and no client-side response to `indrop > 0`.
- Full-state snapshots only — no delta compression, no interest
  management (server sends everyone the whole field).
- No client-side prediction or interpolation — input latency shows raw.
- No tick-rate accounting — `sleep-ms(16)` approximates 60Hz, no drift
  correction, no fixed-timestep accumulator.
- Session key is addr<<16|port — fine for LAN, not identity. No auth.
- No anti-cheat/telemetry — that's the `koru/signal` slice; the detector
  surface (per-stream models over per-session state) is designed but
  unbuilt.
- `clock:ticks` is project-local — the unbounded-iteration primitive
  wants a std ruling.
- JS emitter has the same proc-body hygiene hole, unfixed (Zig path only).
