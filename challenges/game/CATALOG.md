# GAME_CHALLENGE catalog

Finished **playable arcade slices** from `GAME_CHALLENGE.md`. Each entry is a
self-contained `games/<name>/` package (`koru.json`, `main.k`,
`tests/smoke.k`); the line names the game, the organ it stressed, and the
lift gaps it floated.

The catalog is the long-running artifact; each replay is one slice through
it. The gap lists are the lift's work list — LIFT_CHALLENGE quality-passes
close what these games name.

**Diverge by organ.** A new entry should stress something no entry has
stressed: input device, timing/dt, sprites, audio, collision, camera, 3D,
text. Same-organ entries need a stated reason.

## Replays

| Entry | Game | Organ stressed | Gaps floated |
|-------|------|----------------|--------------|
| `games/asteroids/` | asteroids | store-backed entities, wrapping physics, key input | **seed (pre-generator)** — no `dt` (hardcoded `0.016666`), raw scan codes, no early quit |
| `games/ponkatris/` | ponkatris | collision + native physics: `kernel:pairwise` impulse engine, sensors, take-during-sweep, second store for game state, HUD text | no `dt` from `frames`, raw scan codes, no `cross()` (union store), no loops in kernel bodies (no SAT), serial pairwise only, one-arm-per-flow rule tors |
