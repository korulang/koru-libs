---
challenge: game
kind: generator
status: standing
yields: one playable arcade slice on the raylib lift, plus every gap it couldn't cross — named and pinned
catalog: games/*
family: game
---

# GAME_CHALLENGE — grow the arcade catalog, stress the raylib lift

*Walker context: game-shaped work kept recurring against the raylib lift
unprompted — `raylib/tests/` (bounce, boids, primitives, draw_per_entity),
then `asteroids/` as a full package with a `sim/` module and a headless
smoke test. That recurrence earned this generator. The lift itself is a v0
nucleus — window lifecycle + frame bracket + ~16 transliterated calls — and
it will not grow koru-shaped by speculation. It grows by being pulled: each
replay ships one playable slice and, as the real product, the **gap list**
— every place the lift forced transliterated C onto koru-shaped intent.
LIFT_CHALLENGE quality-passes then close what the games name.*

*The reference for "koru-shaped" is `vaxis/index.kz`, not the C original:
`run` owns init→loop→deinit and consumers bind effect arms; input arrives
decoded (`! char`, `! wheel-up`) with raw taps as escape hatches; state is
store-reactive. raylib's analog is already half-emerged: entities live in
`std/store` / `std/grid`, `std/store:rule` blocks are the systems, queries
drive the paint. A game written the C way — arrays, hand-looped update
lists, raw scan codes — is the smell that names the gap.*

---

## The brief (sealed — you are the contestant)

You ARE the contestant, not the assistant. Do **not** ask which game to
build, whether your concept is good enough, or which direction to take —
the choices this brief leaves open are left open on purpose. Pick a slice,
name it, write code, ship. If you catch yourself drafting "which of these
would you like?" — stop, delete it, pick one. Lars judges *after* you ship,
by reading and running. Variance across replays is the metric.

Ship **one playable arcade slice** against `@korulang/raylib`, and the
writeup of every gap it hit.

## The slice — what "playable" means

A real game loop, not a screensaver:

- **State that responds** — the player moves something, and the world
  moves back (bounce, collision, spawn, score, win/lose or survival).
- **Real input path** — keys (or mouse, or pad) genuinely polled and
  consumed inside the frame; not a demo that ignores you.
- **Deterministic halt** — the slice must be runnable to completion by a
  judge: `window.open.hidden` + a bounded `frames` count, or a quit path
  the harness can reach. `asteroids/tests/smoke.k` is the shape to copy —
  hidden window, fixed frames, state asserted at the end.
- **Koru-shaped state** — entities in `std/store` / `std/grid`, sim rules
  as `std/store:rule`, per-frame paint driven by `std/store:query`.
  Hand-rolled parallel arrays and manual update lists are the C reflex —
  they mean either you didn't ground in the idiom, or the idiom can't
  reach. Only the second one is allowed, and it goes on the gap list.

## The gap list — the real yield

The lift is ~3% of raylib and still smells like C. Every place your game
needed something the lift can't express koru-shape is a **named gap** —
write it down. Known-absent organs to expect: `dt` (no `GetFrameTime` —
asteroids hardcodes `0.016666`), decoded input arms, early quit,
mouse/pad, sprite rects & rotation (`DrawTexturePro`), audio, fonts &
text measurement, camera, collision helpers. An entry reporting "hit no
gap" had better be a truly tiny slice.

You MAY touch `raylib/index.kz` — but **only** to add the primitive your
game actually needs, in the lift's own idiom (phantom obligations, scoped
borrows, effect branches). You may NOT:

- route around the toolchain (no scope hacks, no wrapper tricks, no
  "just avoid that name") — clean code rejected by the compiler means
  **STOP, float the gap, pin a minimal repro**. ~50% chance it's you;
  float it, don't fix it and don't dodge it.
- grow the lift speculatively — a primitive with no game pulling it is
  inventory, not coverage.
- paper over a lift hole in game code — a local fix for a lift-shaped
  absence hides the signal this generator exists to produce.

## Reference shelf — diverge by organ

The arcade canon is the triage shelf — pick a slice that stresses an
organ no catalog entry has stressed yet:

| Slice | Organ it stresses |
|---|---|
| pong / breakout | collision, bounce physics, paddle input |
| snake | grid state, turn-based-in-real-time stepping |
| invaders / galaga | entity swarms, spawning, sprite sheets |
| tetris | grid rules, rotation, gravity timing |
| lunar lander | analog physics, dt-critical integration |
| twin-stick / shooter | mouse or dual-axis input, bullets at scale |
| flappy | one-button timing, scroll |
| anything with sound | the entire raudio organ (unclaimed) |
| anything 3D | the entire rmodels organ (unclaimed) |

Two entries may share a genre only if they stress different organs. Read
`challenges/game/CATALOG.md` first — bring something not already there.
raylib's own examples collection is the API map when you need to know
what the C original calls a thing.

## The boss target — ponkatris

`~/src/ponkatris_arcade` is a finished Bevy 0.12 + `bevy_xpbd_2d`
physics arcade game (~5k lines Rust): a player-driven ball collects
crystals against the clock through levels of walls, restitution-10.5
bumpers, disappearing walls, sensor kill-zones. Basic graphics, real
demands. **A ponkatris slice is the marquee replay** — the core loop
only: dynamic ball vs static colliders, restitution, sensors, dt-critical
integration, timer text, camera follow. Editor, ghosts, particles, WASM
are NOT the slice.

Its first fork is the challenge's best question: raylib ships collision
*queries* (`CheckCollision*`) but no dynamics — xpbd carried the whole
physics load. The **native route is not speculative**: `std/kernel` over
`std/store` already covers the collision-engine skeleton — bodies as
store rows (`insert`/`take` = spawn/despawn, proven by asteroids'
bullets), `kernel:self` elementwise integration over the SoA columns
(390_112), `kernel:pairwise` over store rows with symmetric
both-endpoint writes — the impulse-resolution shape (390_115, green
2026-09-12), and `kernel:step(0..N)` for solver substeps. Build the
engine in the game's `sim` module out of those; every place it breaks
is a toolchain finding, and the standing wall it pushes on is
`store-kernel-seam` (koru `challenges/013`): nested row bindings
(690_110/112), pairwise serial until the deterministic-reduction
contract lands, N²/2 broadphase, kernel bodies' restricted vocabulary.

The alternative — lifting a C dynamics engine (Box2D & co.) as a
`@korulang/` package — is a legitimate **LIFT replay on its own**; it is
not a move inside a game entry. A game that leans on C physics has
answered "koru can't express this" without ever asking. Dodging the
physics with canned animations is worse: not a finding, a lie.

## Ship shape — zero-friction append

- **Directory:** `games/<name>/` — a self-contained package like
  `asteroids/`: `koru.json` (`libs: { "raylib": "../../raylib" }`),
  `main.k` (the playable slice), `tests/smoke.k` (hidden-window
  deterministic run). Sibling modules (`sim/`) welcome — real games are
  multi-file; that's the point of the directory shape.
- **Writeup:** `games/<name>/README.md` — one-line thesis, the gap list
  (each gap: what you tried, what the lift lacks or the compiler said),
  and the quadrifecta note if you touched the lift.
- **Catalog:** one line under Replays in `challenges/game/CATALOG.md` —
  game, organ stressed, gaps named. Frontier scraps don't enter.

## Done-gates — self-check before you ship

1. `koruc run games/<name>/tests/smoke.k` exits clean — hidden window,
   bounded frames, end-state printed or asserted.
2. `koruc build games/<name>/main.k` compiles; the slice is playable
   under `window.open` (you cannot demo it to yourself headless — the
   code must show the input arms genuinely wired).
3. State lives in stores/grids, or every exception is a named gap.
4. The gap list is filed — names, not vibes.
5. Any `raylib/index.kz` addition is a primitive the game pulls, in the
   lift's obligation idiom, with a negative test if it carries an
   obligation.
6. Catalog line appended.
7. Lars plays it — or reads the smoke and says "yeah, that's a game."

## Holes — float and pin, never fix, never route around

Compiler rejects clean koru? Emit pass produces broken zig? ~50% chance
it's your misunderstanding — float the exact program + error, pin when
real, stop. The toolchain fix belongs to mom and dad between replays; a
routed-around hole is a generator that lied about what it found.

## Replays

- 2026-09-12 · generator planted — recurrence: `raylib/tests/*.k` demos +
  the `asteroids/` package predating the brief. Seed: `asteroids/` moved
  to `games/asteroids/` as catalog entry one (pre-generator shape —
  smoke-passing, gaps already named).
