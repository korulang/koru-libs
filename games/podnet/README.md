# podnet — the authored-game slice

The third `SERVER_CHALLENGE` shape and the first that isn't recovered:
our own protocol, our own sim — the "agent emits sim+wire, platform
hosts it" vertical in miniature.

- `sim/index.kz` — the shared racer tick (thrust/turn → x,y,a,v). Same
  file compiles server-side (arbitration) and client-side (prediction).
- `wire/index.kz` — fixed little-endian: nmc 1 input [3B], nmc 2 pos [21B].
- `server.k` — enet host, grid-row players, input → sim:step → pos fan-out.
- `client.k` — scripted-input artifact; decodes the broadcast.

Measured: two clients joined (cn 0, cn 1); each saw the other's racer
orbit under server-side sim — pos rows streaming ~50/s, clean join/leave.

Next: real input (keyboard), match cost numbers under loadbot N-sessions,
and the wasm-server-side-sim story for untrusted uploads.
