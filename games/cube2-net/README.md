# cube2-net — Cube 2: Sauerbraten server in Koru over libs/enet

The second `SERVER_CHALLENGE` replay, and the first aimed at a *real*
protocol: not a wire format we invented, but Sauerbraten's — verified
against a live reference implementation.

## The oracle setup

- **Readable spec:** `sauerbraten/waiter` (Go) — `pkg/protocol/packet.go`
  holds the wire codec (sauer `put-int` varint, `put-uint` LEB, cubecode
  strings), `pkg/protocol/nmc` the message table, `pkg/server` the
  handshake choreography. Cloned at `/tmp/waiter` during the slice.
- **Executable oracle:** the same waiter binary runs locally on :28785.
- **The instrument:** `probe.k` — a koru enet client that dials, decodes
  ServerInfo, answers TryJoin, and prints every channel-1 message code it
  receives. One binary, pointed at either server, diffs them.

## Measured (first parity run)

probe → **waiter** (`./probe.bin 28785`):

    SERVERINFO cn 0 proto 260 session 436899731 desc "p1x.pw @ <git-dev>"
        authdom "waiter.p1x.pw"
    nmc 64 ch 1 len 8      (SetTeam)
    nmc 2  ch 1 len 39     (Welcome)
    nmc 35 ch 1 len 158    (ServerMessage — the MOTD)
    nmc 93 ch 1 len 14

probe → **this server** (`./probe.bin 28790`):

    SERVERINFO cn 0 proto 260 session 12345 desc "koru cube2 server"
        authdom ""
    nmc 2  ch 1 len 22     (Welcome — our minimal one, no MOTD/RequestAuth)

server log:

    connect pid 0
    tryjoin "koru-probe" model 0

Both directions verified: we decoded waiter's bytes; waiter accepted our
TryJoin (it proceeded to send Welcome — it parsed us). Same probe binary
on both ends.

## Shape

- `wire/index.kz` — the codec: `nmc`, `tryjoin.encode`/`.decode`,
  `serverinfo`/`.decode`, `welcome` (minimal: MapChange+TimeLeft+SetTeam).
  Ports waiter's `PutInt`/`PutUint`/`GetInt` byte-exact.
- `server.k` — `libs/enet:host` + per-tick `service`; `! connect` →
  ServerInfo on channel 1; `! packet` nmc 0 → TryJoin decode → Welcome;
  `! disconnect` → log. cn := enet `incomingPeerID` (no session store yet).
- `probe.k` — the client instrument; takes the target port as argv[1].

## Measured (spawn handshake, second run)

probe → **this server**: full client-visible join —

    SERVERINFO cn 0 proto 260 session 12345
    WELCOME len 22
    SPAWNSTATE cn 0 lifeseq 1 hp 100/100 armour 25 weapon 6
    PONG 42

server log: `connect pid 0` → `tryjoin "koru-probe" model 0` →
`spawn confirmed lifeseq 1 weapon 6`. The complete retail-client-visible
join spine works: connect → serverinfo → tryjoin → welcome → tryspawn →
spawnstate → confirmspawn → ping/pong.

Waiter difference measured: it calls `s.Spawn(c)` inside Join, so its
TrySpawn guard (`State == Dead`) never fires for our probe — no
SpawnState from it; ours answers. Retail clients send TrySpawn after map
load and wait on the server's answer, so the responding behavior is the
correct one for the real-client gate.

nmc 93 identified: `RequestAuth` carrying `stats.p1x.pw` — waiter's own
log dumped the bytes (`[93 115 116 97 116 115 46 112 49 120 46 112 119 0]`
= code + the ASCII string, one byte per put-int). It's the stats-server
auth prompt — not needed here.

## Measured (retail client, third run — the real gate)

A retail Sauerbraten client (brew cask, 2020-12-21 build) connected via
`autoexec.cfg: connect 127.0.0.1 28790`. Server log:

    connect pid 0
    tryjoin "unnamed" model 0
    nmc 102 ch 1 len 18          ← MapCRC (client hashed the map we named)
    nmc 4 ch 0 len 16 (repeat)   ← live position packets, ~50/sec

Client log confirms: `connected to server` → loaded
`packages/base/metl3.ogz` → `game mode is ffa` → in-world, spawned,
streaming positions. ffa auto-spawns on join — the client never waited
for SpawnState; the TrySpawn path stays verified only against ourselves.

## Gap list (the real yield — next slices)

- **Session store absent** — cn comes from enet's pid; a `clients` store
  keyed on `peer.key` lands when game state does (position fan-out).
- **Welcome is minimal** — full welcome adds TeamInfo/InitClient lists,
  privileged-users, pause-state, mode init payload.
- **No positions** — retail client stands in-world after spawn but sees a
  frozen world: needs channel-0 position ingest + fan-out, and our own
  server-controlled entities to watch move.
- **No MapCRC/checkmaps, no chat** — chat is one codec step; MapCRC is a
  file-hash question (`/checkmaps` compares server-side).
- **ClientPing swallowed, not broadcast** — correct for one client; the
  relay lands with the session store.
- **cubecode high bytes** — ASCII passthrough only; port waiter's full
  256-entry cubeToUni/uniToCube tables.
- **No game timer** — TimeLeft is a constant 600; the real one counts down
  and drives intermission.
- **Stale peer-key hazard** rides along from libs/enet's named gap.
- **probe asserts nothing** — it prints; a `tests/` oracle asserts the
  decoded fields (proto==260 etc.) so the parity check is mechanical.
- **Positions arrive but are undecoded** — nmc 4 packets stream at ~50/s
  and are only counted. Decoding (lifeseq + physstate + packed
  xyz/vel/yaw, waiter's position reader is the oracle) is the next
  increment — then fan-out so two clients see each other.

## Measured (loadbot, 20 clients × 2000 pings, fourth run)

`loadbot.k` = a real enet client that joins, then Ping-spams (unreliable,
nmc 30) counting Pong replies. Same binary vs both servers:

| server | sent | ponged | loss | note |
|---|---|---|---|---|
RETRACTED — rerun with per-bot tallies showed both at ~99.8% delivery
(waiter 33,981/34,006 with 3 rejects at max_clients 18; koru 39,895/39,995,
0 disconnects). The earlier "divergence" ran while the retail client was
still connected: the server prints every unhandled nmc, so ~50 position
packets/sec of client traffic made it stdout-bound — an artifact, not a
capacity limit.

Single-bot control: 1998/2000 and 1999/2000 — parity at low load.
Mechanisms partially identified: waiter's send deficit is config-level
rejection; why its pongs also drowned is unmeasured. Ours held every
connection through the flood and lost the replies — opposite failure
mode. Falsifier for the pong-loss side: server-side pong counters and
per-bot `| err`/`! disconnect` tallies on the loadbot.
