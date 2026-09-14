# SERVER_CHALLENGE catalog

Finished **networked slices** from `SERVER_CHALLENGE.md`. Each entry names
the slice, the organ it stressed, and the lift/toolchain gaps it floated.

The catalog is the long-running artifact; each replay is one slice through
it. The gap lists are the toolchain's work list.

## Replays

| Entry | Slice | Organ stressed | Gaps floated |
|-------|-------|----------------|--------------|
| `games/asteroids-net` | udp lift + authoritative headless server + raylib client + scripted bot; join-ack (`you`), keepalive, sequenced input + per-recipient loss telemetry (`indrop`); driver/watcher oracle pair + `test.sh` | posix sockets, phantom obligations, store-as-session-table, flow/branch composition, fan-out as telemetry channel | proc-body `__` hygiene (fixed — koru 400_192); conditional-join obligation double-free (fixed — koru 400_193); frozen `inline_body` under `! query` arms + `@constCast`-drop (fixed — koru 690_312); unbounded loop primitive (`clock:ticks` is project-local, wants std); terminal `! query`/`\|> if` flow-shape friction; `~import std` pulls unparseable `ccp_aspirational.kz`; loss measured not repaired; no delta/interest/prediction yet |
