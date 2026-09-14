---
type: belief
id: frag-join-ack-rides-the-fan-out-loop
provenance: session 2026-09-14 — asteroids-net join-ack slice; KAS2
ts: 2026-09-14
tags: [netcode, protocol, asteroids-net, session, oracle]
---

# A join-ack is a per-recipient field, not a packet

asteroids-net needed "which ship is mine" — the classic join
acknowledgement. The honest shape was not a handshake datagram but one
byte in the existing fan-out: `snap.send` already iterates player rows
one datagram at a time, so the header grew a `you u8` patched with that
session's `pid` (wire `KAS2`). Every snapshot is the ack; a missed packet
self-heals on the next tick, which a one-shot handshake never does. The
cost is one patched byte per datagram; the gain is zero protocol
machinery and an oracle (`snap.you`) any client can read.

## The sibling constraint: silence is not a client state

The same slice measured that a join-then-listen client hears ~90 snaps
(~1.5s) and then nothing — the server's stale sweep reaps silent
sessions. Any probe, watcher, or future "spectator" role that intends to
stay joined must send periodically; receiving is not participation.
Driver-first ordering in the isolation pair exists because the watcher's
hearing window is bounded by its own silence.

## Open questions

Delta snapshots and interest management will revisit the same per-
recipient patch point — `you` shows the seam exists. When pids outgrow
u8 or sessions need real identity (not addr<<16|port), `you` is where
the upgrade lands.
