# ponkatris

The game challenge's boss target, native: a physics time-attack slice
ported from `~/src/ponkatris_arcade` (Bevy 0.12 + bevy_xpbd_2d, ~5k
lines) onto `std/store` + `std/kernel` + `libs/raylib`. No C physics —
the collision engine is Koru.

The shipped level IS the oracle's first level — "Crossing the
rubicon" (ponkatris_astro `src/content/levels/2023-12-04.md`): the
marble drops into a bouncy X of two pink bars (500x25 at +/-45deg,
Restitution 1.0 — the cross is bounceable) and must Boost (up-thrust
3000, 3x lateral) out of the pockets to collect four solid diamond
crystals. Gravity on, kill floor below, count-up stopwatch — a timed
clear. `level/pacman.k` and `level/cross.k` survive as alternates.

## Layout

- `sim/index.k` — the engine. One `bodies` store is the world; a second
  `game` store holds score/elapsed/flags/spawn. `kernel:self`
  integrates, `kernel:pairwise` resolves contacts, rules are
  query-arm tors. No scene lives here — sim is level-agnostic.
- `level/rubicon.k` — the shipped level: the bouncy X, four diamonds,
  gravity, kill floor. Real data, lifted from the astro site's
  content collection.
- `level/pacman.k` — alternate level, remade for feel from the oracle's
  proprietary `level_data` strings (`levels/pacman.txt` @2b933b1).
- `level/cross.k` — alternate level, the earlier crossed-bars guess.
  Levels expose `spawn()` to seed bodies + game row and
  `spawn-crystals(pressed:)` to re-seed dots on restart.
- `level/test.k` — the toy scene (one flinger, one crystal, one
  kill-strip, gravity) that the headless tests drive.
- `main.k` — the shell. Calls `level/rubicon:spawn()`, then window,
  frame loop, WASD/arrow input, kind-keyed paint tors, HUD text,
  R to restart.
- `tests/smoke.k` — headless rung: settle + collect + respawn + win +
  stopwatch count-up/freeze, verified by `dump`/`dump-game` receipts.
- `tests/physics.k` — restitution threshold: settle, graze (inelastic),
  slam (flings).
- `tests/rubicon.k` — the shipped level headless: gravity drop
  collects the top diamond mid-fall (score 1/4), rests on the X at
  y~418, killfloor death + respawn, Boost climbs.
- `tests/cross.k` — the crossed-bars guess level headless.
- `tests/pacman.k` — the pacman alternate headless: 298 bodies spawn,
  zero-g drift check, wall-stop containment, dot + stacked-crystal
  collect.
- `tests/bisect*.k` — standalone compiler-stress repros (own stores,
  own scenes; not part of the sim architecture).

## Shape vocabulary

`kind` discriminates the union — `cross()` doesn't exist yet, so every
body lives in one store:

| kind | shape | role |
|---|---|---|
| 0 | circle, dynamic | the marble |
| 1 | circle, static, e=10.5 | flinger bumper (test level only) |
| 2 | box, static | wall |
| 3 | circle, sensor | dot crystal (taken on hit) |
| 4 | box, sensor | killzone (dead → respawn) |
| 5 | circle, solid | diamond (bounce + collect — the oracle's Crystal) |

Physics: fixed DT=1/120, per-body gravity (`gx`/`gy` columns — the
pacman level is `World: 0 0`), per-body linear damping (`damp` — the
oracle's `LinearDamping(0.5)` is what makes zero-g steerable), impulse +
Baumgarte correction, inside-box least-axis exit for deep penetration,
and a restitution velocity threshold (vn < 100 → inelastic — without it
a walking-pace graze on the e=10.5 flinger still launched at 10.5x).

Movement comes from the level's Movement defaults — rubicon declares
none, so the oracle's `1000/1000/3000/0` applies: lateral nudge, a 3x
up-Boost, no down (gravity owns that). `main.k` turns held keys into
per-tick deltas and `sim:thrust` adds them to velocity.

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

- **Unreferenced imports are pruned whole** — `import level/test` with
  no `level/test:` reference drops the module's init flows silently.
  That's why levels expose `spawn()` and callers invoke it: a
  side-effect import is a no-op. Named, not fixed — dead-import
  elimination vs. Go-style init-on-import is a language call.
- Inline `| row r |>` on an insert line is silently dropped at parse —
  the arm must lead its own line. Grammar gap, logged.
- No `for`/loops inside kernel bodies → no SAT/polygon narrowphase;
  v0 is circles + boxes only.
- No `cross(A,B)` → one union-typed store with a `kind` column; no
  heterogeneous shape sets.
- `pairwise` is serial N²/2; no broadphase. The pacman level runs
  298 bodies → ~44k pair checks per tick at 120Hz; it holds, but the
  comfort zone is still ~256.
- No CCD — contact is discrete overlap per tick. Terminal velocity
  under full thrust is ~2000 px/s (16 px/tick): through a 30px
  corridor wall it can tunnel. Swept narrowphase is a real engine gap.
- No `dt` from the frame loop — physics runs fixed-step; rendering and
  sim are locked 1:1. `libs/raylib:frames` should hand `! frame` a dt.
- Raw scan codes for input (`key: 262`) — decoded key names are the
  vaxis-shaped gap.
- Rules are one-arm-per-flow tors — `collect`, `respawn`, `stopwatch`,
  `reset`, `reset-ball`, `reset-game` are six tors for what a
  branchier flow shape would say in one. Named, not fixed: it's a
  grammar question, not a bug.
- Camera: none — the level fits one screen. The oracle's camera-follow
  is out of slice scope.
- Audio, particles, the level backend + editor, ghost replays: all out of
  slice scope; each is a future replay.

## Run

    /Users/larsde/src/koru/zig-out/bin/koruc main.k && ./a.out
    cd tests && /Users/larsde/src/koru/zig-out/bin/koruc smoke.k && ./a.out
