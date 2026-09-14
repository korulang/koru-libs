# @korulang/udp

Nonblocking UDP datagrams for Koru — the first slice of the
[`SERVER_CHALLENGE`](../SERVER_CHALLENGE.md) gap list. Raw posix sockets behind
phantom obligations; no C library, `linkLibC` only.

## The shape

- `udp:bind(port:)` → `*Socket<bound!>` — bind is the only mint; port 0 asks
  the OS for an ephemeral port (read it back with `udp:socket.port`).
- `udp:packets(sock, max:)` — the drain: a source combinator firing
  `! packet p` once per queued datagram, stopping at `max` or at WouldBlock.
  `p` is a scoped borrow aliasing the recv buffer — valid inside the branch.
- `udp:packet.data / .key / .addr / .port` — payload as `string`, and the
  i64 session key (`ipv4 << 16 | port`) a server keys per-client rows on.
- `udp:send.ip` (dotted quad), `udp:send.to` (host-order u32+u16),
  `udp:send.key` (the packet.key fold) — three destination spellings.
- `udp:close(sock: <!bound>)` — branchless; a datagram close can't
  meaningfully fail, and an `| err` arm here would only fork the obligation
  graph (two sockets, nested closes, first leaks — measured, KORU030).

Nonblocking by construction: `SOCK.NONBLOCK` at `socket()` (the portable
spelling — posix.socket applies it internally; darwin's `O` is a bitfield).

## Named gaps (deliberate v0 cuts)

- **Poll-shaped only.** The drain reads what's queued *now*; there is no
  "packet OR deadline" event source. kqueue/epoll integration belongs in a
  future socket-source tor (Orisha's pump is the port source).
- **IPv4 only.** `parseIp4` + `AF.INET`. v6 is a follow-on.
- **No sendto backpressure** — UDP has none; EAGAIN on a full send buffer is
  currently `| err`.
- **packet.key is IPv4-shaped** — a v6 key wants a wider fold.

## Test

```sh
koruc run udp/tests/basic.k
```

Loopback self-test: two ephemeral sockets, a→b datagram, b→a ack, session
keys asserted, both sockets closed. Sleeps 20ms between send and drain —
localhost delivery is near-synchronous, not synchronous.
