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

## Gap list (the real yield — next slices)

- **Session store absent** — cn comes from enet's pid; a `clients` store
  keyed on `peer.key` lands when game state does (spawn, position).
- **Welcome is minimal** — full welcome adds TeamInfo/InitClient lists,
  privileged-users, pause-state, mode init payload.
- **No spawn/positions** — a retail client will handshake but stand
  spawnless: needs SpawnState + channel-0 position fan-out + TrySpawn →
  ConfirmSpawn handling.
- **No MapCRC/checkmaps, no chat, no pings** (nmc 30 ClientPing → Pong is
  probably mandatory to keep a real client alive).
- **nmc 93 unidentified** — received from waiter post-join, 14 bytes
  (likely RequestAuth); decode it.
- **cubecode high bytes** — ASCII passthrough only; port waiter's full
  256-entry cubeToUni/uniToCube tables.
- **No game timer** — TimeLeft is a constant 600; the real one counts down
  and drives intermission.
- **Stale peer-key hazard** rides along from libs/enet's named gap.
- **probe asserts nothing** — it prints; a `tests/` oracle asserts the
  decoded fields (proto==260 etc.) so the parity check is mechanical.
