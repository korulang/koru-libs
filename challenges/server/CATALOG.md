# SERVER_CHALLENGE catalog

Finished **networked slices** from `SERVER_CHALLENGE.md`. Each entry names
the slice, the organ it stressed, and the lift/toolchain gaps it floated.

The catalog is the long-running artifact; each replay is one slice through
it. The gap lists are the toolchain's work list.

## Replays

| Entry | Slice | Organ stressed | Gaps floated |
|-------|-------|----------------|--------------|
| `games/asteroids-net` | udp lift + authoritative headless server + raylib client + scripted bot; join/input/snapshot/stale-sweep over real datagrams | posix sockets, phantom obligations, store-as-session-table, flow/branch composition | proc-body `__` hygiene (fixed — koru 400_192); unbounded loop primitive (`clock:ticks` is project-local, wants std); terminal `! query`/`\|> if` flow-shape friction; `~import std` pulls unparseable `ccp_aspirational.kz`; no sequencing/delta/interest/prediction yet |
