# ponkatris

The game challenge's boss target, native: a physics time-attack slice
ported from `~/src/ponkatris_arcade` (Bevy 0.12 + bevy_xpbd_2d, ~5k
lines) onto `std/store` + `std/kernel` + `libs/raylib`. No C physics —
the collision engine is Koru.

## Layout

- `sim/index.k` — the engine. One `bodies` store is the world; a second
  `game` store holds score/timer/flags. `kernel:self` integrates,
  `kernel:pairwise` resolves contacts, rules are query-arm tors.
- `main.k` — the shell. Window, frame loop, WASD/arrow input, kind-keyed
  paint tors, HUD text, R to restart.
- `tests/smoke.k` — headless rung: settle + collect + respawn + win,
  verified by `dump`/`dump-game` receipts.

## Shape vocabulary

`kind` discriminates the union — `cross()` doesn't exist yet, so every
body lives in one store:

| kind | shape | role |
|---|---|---|
| 0 | circle, dynamic | the marble |
| 1 | circle, static, e=10.5 | flinger bumper |
| 2 | box, static | wall |
| 3 | box, sensor | crystal (taken on hit) |
| 4 | box, sensor | killzone (dead → respawn) |

Physics: fixed DT=1/120, gravity 1000 px/s², thrust 1000/3000 px/s²
(oracle values), impulse + Baumgarte correction, inside-box least-axis
exit for deep penetration, and a restitution velocity threshold (vn <
100 → inelastic — without it a walking-pace graze on the e=10.5 flinger
still launched at 10.5x).

## What it forced out of the toolchain

Every one of these landed as a `koru` commit, not a library dodge:

- `if/else` blocks as kernel bodies emitted a stray `;` (771e9073c)
- `//` comments inside multi-line kernel bodies amputated the closing
  `}` — three sites (9bc582dc0)
- store backing vars for directory-path modules emitted into the
  importer's scope (7f7582f28)
- `insert |> insert` dropped the tail (7f7582f28, pin 690_304)
- imported module top-level flows ran AFTER the entry's flows — module
  init was dead code (291efff7c, pin 110_034)
- `take(store[row])` under `! query` leaked the raw binding and the
  sweep couldn't tolerate mid-loop removal (8f1cad076, pin 690_305)
- `std/fmt` passed `:f` through to Zig's formatter, which has no `{f}`
  specifier — now matches io's `{}` mapping (8f1cad076)

## Named gaps still standing

- No `for`/loops inside kernel bodies → no SAT/polygon narrowphase;
  v0 is circles + boxes only.
- No `cross(A,B)` → one union-typed store with a `kind` column; no
  heterogeneous shape sets.
- `pairwise` is serial N²/2; no broadphase, no deterministic-reduction
  contract yet. 256-body cap is the current comfort zone.
- No CCD — contact is discrete overlap per tick. A flinger slam can push
  the ball past ~50 px/tick and it can skip through the 10px kill-strip
  without registering. Swept narrowphase (or velocity-scaled substeps)
  is a real engine gap, not yet expressible per-substep.
- No `dt` from the frame loop — physics runs fixed-step; rendering and
  sim are locked 1:1. `libs/raylib:frames` should hand `! frame` a dt.
- Raw scan codes for input (`key: 262`) — decoded key names are the
  vaxis-shaped gap.
- Rules are one-arm-per-flow tors — `collect`, `respawn`, `countdown`,
  `reset`, `reset-spawn`, `reset-ball`, `reset-game` are seven tors for
  what a branchier flow shape would say in one. Named, not fixed: it's
  a grammar question, not a bug.
- Camera: none — the level fits one screen. The oracle's camera-follow
  is out of slice scope.
- Audio, particles, level JSON, ghost replays, the editor: all out of
  slice scope; each is a future replay.

## Run

    /Users/larsde/src/koru/zig-out/bin/koruc main.k && ./a.out
    /Users/larsde/src/koru/zig-out/bin/koruc tests/smoke.k && cd tests && ./a.out
