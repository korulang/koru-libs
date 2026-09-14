---
challenge: server
kind: generator
status: standing
yields: one networked slice — authoritative server + client — plus every gap it couldn't cross, named and pinned
catalog: challenges/server/CATALOG.md
family: server
---

# SERVER_CHALLENGE — put the sims on the wire, name what breaks

*Walker context: the games accidentally built the right architecture —
`games/*/sim/index.k` is headless (zero raylib), and `main.k` is already a
client-shaped shell: input → sim tors → paint. A dedicated server is the
same sim with a network shell; a client is the same paint fed by a
replicated store. What is missing is almost entirely transport — and
transport is liftable.*

*The ambition has a name: WARDOGS (BULKHEAD/Team17, early access
2026-09-10) — 100 players, three teams of ~33, a King-of-the-Hill control
zone inherited from Sa-Matra's Arma 3 mission. The server-visible game is
modest: ~99 players + vehicles ≈ a few hundred store rows (ponkatris's
demonstrated comfort zone), zone scoring a `when`-guarded query per cycle.
The hard part is never the sim — it is replication: snapshots, deltas,
interest management, session lifecycle, lag-compensated hit validation.*

---

## The brief (sealed — you are the contestant)

You ARE the contestant. Do not ask which slice to build or whether the
concept is good enough. Pick a slice, name it, write code, ship. Lars
judges after you ship, by reading and running.

Ship **one networked slice**: an authoritative server process plus a client
process, real sockets between them, the sim driven by client input and
observed through replicated state — and the writeup of every gap it hit.

## The slice — what "networked" means

A real server loop, not a pipe dream:

- **A real socket** — datagrams between two processes (or a wrapped
  transport; see the lift note). An in-process function call wearing
  network vocabulary is a lie about the organ being tested.
- **Server owns the truth** — state lives in `std/store` on the server;
  clients send intent (`thrust`, `fire`), never state. A client that
  dictates its own position has no authority boundary — that is the
  architecture this generator exists to exercise.
- **Deterministic halt** — the slice must run to completion headless:
  bounded tick count + scripted client inputs + dump receipts, the same
  discipline as `games/*/tests/smoke.k`. Two processes, one assertion.
- **Tick-driven** — the server advances on a wall-clock tick
  (`std/time` has the clock; the event source that fires `! tick` on a
  deadline is likely a named gap), not on packet arrival.

## The gap list — the real yield

Expected organs to be missing — each is a named gap, not a thing to
route around:

- **UDP socket lift** — `std/net` refuses by design; Orisha's pumps are
  TCP accept+readiness; `unikraft/net` is raw frames. Nothing datagram
  exists. First lift decides: raw posix UDP (smallest honest organ) or
  ENet (sequenced reliable+unreliable channels, the oracle-grade choice —
  MIT, and Cube 2 is the reference consumer).
- **Deadline event source** — kqueue pumps wake on readiness; a game
  server wakes on packet-OR-deadline (`EVFILT_TIMER`-shaped). A loop that
  has never existed in the corpus.
- **Wire format** — `yyjson` JSON is fat but honest for v0; binary
  snapshot packing is new territory.
- **Delta / store-diff** — "what changed since this client's last ack"
  wants set-difference over stores — presses the `cross(A,B)` adjacency.
- **Per-connection flows** — `! packet` arms parameterized by the
  connection row; a `clients` store where join=`insert`, drop=`take`.
- **Interest management** — probably expressible today as a `when`
  distance-guard parameterized by viewer position — compile it before
  claiming it.
- **Session lifecycle** — `*Conn<connected>` → `<authed>` → `<in-match>`
  is phantom machinery in its intended habitat.
- **Input taint** — wire bytes arrive `[]const u8<net:tainted!>`; the
  validator discharges. Compile-time half of "never trust the client."
- **Lag-compensated rewind** — per-entity tick history for hit
  validation; the stretch goal, name it don't dodge it.
- **Dispatch pressure** — join/leave/input/fire message arms press the
  already-named one-arm-per-flow grammar gap.

## Signal tie-in — the second organ

The same tick loop feeds `koru/signal` models pointed two ways:
server telemetry first (tick_ms sustained-over-budget is `Breath`
verbatim; `011_token_bucket` ported is both a rate detector AND a
bandwidth shaper), per-player physics-consistency detectors later.
Rung order and the surface design live in `signal/SURFACE.md`; the
foreign-vs-native ruling and the per-value/per-stream division are in
koru `concepts/` (`frag-signal-lift-vs-native-port`,
`frag-taint-is-per-value-signal-is-per-stream`).

## Reference shelf — oracles in the open

| Oracle | What it teaches |
|---|---|
| **ENet** (MIT) | the transport lift candidate — reliable+unreliable UDP channels, sequencing |
| **Cube 2 / Sauerbraten** | a real game server on ENet — the reference consumer |
| **Quake III / ioquake3 + mvdsv** | snapshot + delta compression — the canonical ancestor text |
| **DDNet/Teeworlds** | clean modern server, 64 players, lag compensation, prediction |
| **RobustToolbox / SS14** (MIT) | server-authoritative + prediction + autogenerated state sync, proven at "hundreds of players" |
| **Veloren** | modern Rust ECS authoritative server, ~100+ concurrent |
| **Soldat / BZFlag** | the rare native multi-team oracles (4 teams / 4+rogue) |
| **SealDrop-KOTH + Sa-Matra lineage** | the rules oracle — zone cycles, cash economy, three teams |
| **Fiedler's articles + netcode.io/yojimbo** | the textbook — connection flow, reliability, why UDP |

The oracle property that matters: these are **executable**. A bot-client
harness can point at their dedicated servers and ours alike — tick cost,
bytes/snapshot, players-per-core are byte-exact comparisons, not vibes.

## The boss target — `games/zonecontrol`

A top-down command-map KOTH: three teams, a control zone, scoring cycles,
bot-driven players — recognizably the WARDOGS problem at the layer our
tech can honestly reach. The rules are a weekend of store queries
(SealDrop/Sa-Matra semantics are the oracle); the feel layer (FPS client,
voice, prediction polish) is out of honest reach and stays named as such.

## Ship shape

- **Socket lift:** `libs/enet` or `libs/udp` — a package like any other:
  `index.kz`, phantom obligations on peer/host handles, `tests/`.
- **Game slice:** `games/<name>-net/` — server `main.k` (headless tick
  loop) + client `main.k` (raylib shell fed by the wire) + a headless
  two-process smoke test.
- **Writeup:** README gap list — what you tried, what the lift/compiler
  lacks, verbatim diagnostics.
- **Catalog:** one line in `challenges/server/CATALOG.md`.

## Done-gates

1. The smoke test passes: server ticks N frames headless, scripted client
   exchanges real datagrams, end-state asserted.
2. Client intent → server truth → client observation is the only data
   path; no shared-memory shortcuts.
3. Every absence is a named gap; none is worked around in game code.
4. Catalog line appended.

## Holes — float and pin, never fix, never route around

Compiler rejects clean Koru, emit produces broken Zig, phantom won't
stick where it should? ~50% chance it's your misunderstanding — float
the exact program + error, pin when real, stop. The toolchain fix
belongs to mom and dad between replays.

## Replays

- 2026-09-14 · generator planted — seeded from the signal/server design
  walk; slice ladder: socket lift → `games/asteroids-net` (existing sim,
  zero new game code) → `games/zonecontrol` (the WARDOGS-shaped one).
