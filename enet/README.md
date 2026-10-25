# @korulang/enet

Reliable + sequenced UDP sessions via libenet — the transport lift
`SERVER_CHALLENGE.md` names for the Cube 2 slice. ENet is MIT, hosted at
sauerbraten.org, and was written for Cube; this lift wraps its C API behind
phantom obligations the way `koru/curl` wraps libcurl.

## Why this exists

`libs/udp` proved the raw-datagram shape end to end (`games/asteroids-net`,
N=1024). What it measures but does not repair is *reliability*: seq gaps
count into `indrop`, dup/reorder is detected — and there the surface stops.
ENet is that missing layer, already battled at exactly this altitude:
sequenced reliable + unreliable channels, connection management, ping/RTT
telemetry, fragmentation — and a *real client* (Sauerbraten) that speaks it
on the wire, so the lift's oracle is a retail FPS client, not another koru
bot.

## The shape

- `enet:host(port:, peers:, channels:, down:, up:)` → `*Host<host!>` — bound
  server host; bandwidth caps 0 = unlimited.
- `enet:client(channels:)` → `*Host<host!>` — unbound client host, one peer.
- `enet:dial(host:, ip:, port:, channels:)` → `| dialing` with the peer key
  NOW — the connect outcome arrives as a `! connect` event on service.
  Non-blocking by design: a loopback that pumped both hosts on one thread
  would deadlock on a blocking dial.
- `enet:service(host:, timeout_ms:)` — the pump; fires each queued event:
  `! connect p` / `! packet pk` / `! disconnect p`, then `| idle`. Each
  borrow is branch-scoped (udp's `! packet` shape); releases auto-insert.
- `enet:peer.key` → i64 — the peer HANDLE as the session-row key (a
  *ENetPeer can't be refolded from an address the way udp's can). The same
  value comes off `packet.peer-key` inside `! packet`.
- `enet:peer.pid` → i64 — enet's incoming-peer index; the natural slot for
  a protocol's client-number field.
- `enet:send.peer` / `enet:send.key` — packet on `channel:`, `reliable:`
  picks `ENET_PACKET_FLAG_RELIABLE` vs unreliable-sequenced.
- `enet:peer.disconnect` / `peer.disconnect-key` — graceful; the teardown
  event still arrives through service, rows drop THERE.
- `enet:flush` — push the outgoing queue now.
- `enet:close(host: <!host>)` — branchless (udp's `| err`-fork lesson).

## Test

`tests/basic.k` — loopback on one thread: `host` + `client`, `dial` →
both sides pump `service` each round (a blocking dial would deadlock),
reliable `hello koru` up on channel 0, `ack` back, `disconnect-key` →
graceful teardown, `close` both. Measured (first run):

    srv conn 1 key 4351663840 pkts 1 bytes 10; cli conn 1 pid 0 pkts 1
    bytes 3; disc s1 c1
    closed

The dial-time discovery this bakes in: `send` on a `| dialing` peer fails
`peer_send failed — peer not connected` — ENet wants `CONNECTED` state.
Send from the `! connect` arm (the test does) or gate on your own state.

## Named gaps (deliberate v0 cuts)

- **Stale-key hazard** — a stored key outliving its peer reaches a recycled
  or dead peer slot. The row-removal discipline (drop on `! disconnect`)
  is the current answer; `peer->data` carrying a generation stamp is the
  likely hardening, named not built.
- **IPv4 string dials only** — `enet_address_set_host` on a dotted quad.
- **No port-0 readback** — server hosts want a fixed port today.
- **Packets >64KB truncate** — buf is fixed at 65536 like udp's Packet;
  enet allows ~32MB fragmented packets. A `packet.truncated` flag is the
  honest marker, currently absent.
- **enet_initialize is once-ever, not refcounted** — fine for one process.
- **No compression/bandwidth-throttle/range-coder surfaces** — enet's
  optional features are unbound.
- **Poll-shaped only** — the evented socket-source (kqueue port from
  Orisha's pump) is the shared gap with libs/udp.

## The slice this unblocks — `games/cube2-net`

Cube 2: Sauerbraten over three enet channels — `0` positions, `1` game
events, `2` coop-edit maps (p1x's protocol notes decode the handshake
byte-by-byte: `N_SERVINFO` carries cn + protocol version + session id +
map + description). Protocol oracle: `sauerbraten/waiter`, a working Go
server on stock enet — proof stock libenet speaks to real clients. The
demo that counts: a retail Sauerbraten client connects, receives a cn +
serverinfo + map + spawn, and watches koru-served entities move — then
`games/cube2-net` and asteroids-net's diff extracts `libs/gameserver`.
