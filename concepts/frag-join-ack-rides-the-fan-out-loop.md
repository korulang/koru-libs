---
type: belief
id: frag-join-ack-rides-the-fan-out-loop
provenance: session 2026-09-14 — asteroids-net join-ack slice; KAS2
ts: 2026-09-14
tags: [netcode, protocol, asteroids-net, session, oracle]
---

# Per-recipient session state rides the fan-out loop

asteroids-net needed "which ship is mine" — the classic join
acknowledgement. The honest shape was not a handshake datagram but one
byte in the existing fan-out: `snap.send` already iterates player rows
one datagram at a time, so the header grew a `you u8` patched with that
session's `pid` (wire `KAS2`). Every snapshot is the ack; a missed packet
self-heals on the next tick, which a one-shot handshake never does.

The next slice reused the seam a second time: `indrop u16` stamps the
recipient's cumulative input-gap count (`KAS3`). Two stamps makes it a
channel, not a trick — **per-recipient session state (identity,
telemetry) is a header field patched in the fan-out loop**, and any
client can read it back without protocol machinery. The return path for
"what the server believes about YOUR session" already exists.

## The sibling constraint: silence is not a client state

A join-then-listen client hears ~90 snaps (~1.5s) and then nothing — the
stale sweep reaps silent sessions. Receiving is not participation. The
resolution is structural, not a new packet type: every input packet runs
`sim:drive`, which touches `last` — so a periodic zero-flag input IS the
keepalive. The watcher keepalives every 30 ticks and now hears the full
window (~356 snaps vs ~91). With seq = client tick, keepalive cadence
shows up honestly in `indrop` as under-send gaps.

## Open questions

Delta snapshots and interest management will revisit the same patch
point. Ordering/duplication is detected (dup seqs are liveness-only,
never re-applied) but not yet *reported* — a `dups` counter is the next
stamp if it earns its byte. When pids outgrow u8 or sessions need real
identity (not addr<<16|port), `you` is where the upgrade lands.
