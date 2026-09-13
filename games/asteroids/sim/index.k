// index.k — asteroids sim: the pure rules AND the world they rule.
//
// One `bodies` store is the world, kind-discriminated (the ponkatris
// architecture): 1 ship · 2 rock · 3 bullet. kernel:self integrates and
// wraps; kernel:pairwise flags bullet×rock and ship×rock contacts; query
// arms harvest the flags — take, split, score, respawn. Nothing is taken
// inside pairwise: flags first, takes in the sweep after.
//
// The pure tors below are values in, values out; every knob is a named
// constant mirroring the asteroids-demos reference (bradcypert/asteroids-
// demos). raylib's y grows downward, so rotation 0 faces straight up (the
// reference's sin/-cos convention).

import std/io
import std/store
import std/kernel

std/store:new(bodies, capacity: 128) {
    x: f32, y: f32, dx: f32, dy: f32,
    kind: f32, r: f32, t: f32,
    seed: i32,
    hit: f32, dead: f32,
    rot: f32, inv: f32, cd: f32
}

std/store:new(game, capacity: 2) {
    score: f32, lives: f32, over: f32
}

const {
    SCREEN_WIDTH: 800
    SCREEN_HEIGHT: 600
    SHIP_SIZE: 20.0[f32]
    SHIP_ROTATION_SPEED: 3.5[f32]
    SHIP_THRUST: 220.0[f32]
    SHIP_DRAG: 0.60[f32]
    MAX_SHIP_SPEED: 380.0[f32]
    BULLET_SPEED: 520.0[f32]
    BULLET_LIFETIME: 1.1[f32]
    FIRE_COOLDOWN: 0.25[f32]

    KEY_LEFT: 263
    KEY_RIGHT: 262
    KEY_UP: 265
    KEY_A: 65
    KEY_D: 68
    KEY_W: 87
    KEY_SPACE: 32
    KEY_ENTER: 257
    RNG_M: 12981
    RNG_A: 28411
    RNG_N: 65536
    DEG_RAD: 0.0174533[f32]
    SPLIT_COS: 0.743145[f32]
    SPLIT_SIN: 0.669131[f32]
    CHILD_MIN_R: 16.0[f32]
    ROCK_SIDES: 9[i32]
    KIND_SHIP: 1.0[f32]
    KIND_ROCK: 2.0[f32]
    KIND_BULLET: 3.0[f32]
    SHIP_INVULN: 2.0[f32]
    START_LIVES: 3.0[f32]
}

// The ship's facing unit vector. Straight up at rotation 0.
pub tor facing { rotation: f32 } -> { x: f32, y: f32 }

facing -> { x: @sin(rotation), y: -@cos(rotation) }

// Wrap one axis across the screen edge (the signature Asteroids mechanic).
pub tor wrap-x { x: f32, width: f32 } -> f32

wrap-x -> if (x < 0.0) x + width else (if (x >= width) x - width else x)

pub tor wrap-y { y: f32, height: f32 } -> f32

wrap-y -> if (y < 0.0) y + height else (if (y >= height) y - height else y)

// Rotation change this frame. Both keys held net to zero (the reference
// applies left then right on the same dt, which cancels).
pub tor rotation-delta { left: bool, right: bool, dt: f32 } -> f32

rotation-delta -> if (left and right) 0.0 else (if (left) 0.0 - SHIP_ROTATION_SPEED * dt else (if (right) SHIP_ROTATION_SPEED * dt else 0.0))

// Thrust along the facing, added to a velocity component. Applied only while
// the thrust key is held; otherwise the component is returned untouched.
pub tor thrust-dx { vx: f32, rotation: f32, thrusting: bool, dt: f32 } -> f32

thrust-dx -> if (thrusting) vx + @sin(rotation) * SHIP_THRUST * dt else vx

pub tor thrust-dy { vy: f32, rotation: f32, thrusting: bool, dt: f32 } -> f32

thrust-dy -> if (thrusting) vy - @cos(rotation) * SHIP_THRUST * dt else vy

// Exponential drag: velocity multiplied by DRAG^dt each frame.
pub tor drag-x { vx: f32, dt: f32 } -> f32

drag-x -> vx * @exp(@log(SHIP_DRAG) * dt)

pub tor drag-y { vy: f32, dt: f32 } -> f32

drag-y -> vy * @exp(@log(SHIP_DRAG) * dt)
// ── RNG ──────────────────────────────────────────────────────────────────────
// Deterministic 16-bit LCG, one draw per call; the returned s2 is the next
// seed, v is the draw. Constants chosen so NO intermediate product overflows
// (65535 * 12981 + 28411 < 2^30) — the sequence is fully pinned. Full period
// 65536 (12981 ≡ 1 mod 4, 28411 odd). The game threads s into the grid; the
// regression tests pin exact (s2, v) pairs, so a knob change is a board flip.

// Advance the LCG once. v = s2's low 12 bits (0..4095) — one draw, ~359 plus
// a 4-bit edge marker, biased but harmless for a game.
pub tor rand { s: u32 } -> { s2: u32, v: u32 }

rand -> { s2: (s * RNG_M + RNG_A) % RNG_N, v: (s * RNG_M + RNG_A) % 4096 }

// A uniform draw under n.
pub tor rand-under { s: u32, n: u32 } -> { s2: u32, v: u32 }

rand-under -> { s2: (s * RNG_M + RNG_A) % RNG_N, v: (s * RNG_M + RNG_A) % n }

// ── Geometry ─────────────────────────────────────────────────────────────────
// Unit velocity from degrees, game-facing convention (0 = straight up,
// y grows down). speed scales it.
pub tor dir { deg: u32, speed: f32 } -> { dx: f32, dy: f32 }

dir -> { dx: @sin(@as(f32, @floatFromInt(deg % 360)) * DEG_RAD) * speed, dy: -@cos(@as(f32, @floatFromInt(deg % 360)) * DEG_RAD) * speed }

// Position along an axis as a fraction of a draw (0..99 -> 0..scale).
pub tor edge-pos { v: u32, scale: f32 } -> f32

edge-pos -> @as(f32, @floatFromInt(v % 100)) / 100.0 * scale

// Ship nose: SHIP_SIZE along the facing from the ship center.
pub tor nose { x: f32, y: f32, rotation: f32 } -> { x: f32, y: f32 }

nose -> { x: x + @sin(rotation) * SHIP_SIZE, y: y - @cos(rotation) * SHIP_SIZE }

// The ship's silhouette: nose + two aft corners at ±2.5 rad, 0.75× scale —
// the classic wedge. draw.triangle.lines takes the three vertices.
pub tor ship-verts { x: f32, y: f32, rotation: f32 } -> { x1: f32, y1: f32, x2: f32, y2: f32, x3: f32, y3: f32 }

ship-verts -> { x1: x + @sin(rotation) * SHIP_SIZE, y1: y - @cos(rotation) * SHIP_SIZE, x2: x + @sin(rotation + 2.5) * SHIP_SIZE * 0.75, y2: y - @cos(rotation + 2.5) * SHIP_SIZE * 0.75, x3: x + @sin(rotation - 2.5) * SHIP_SIZE * 0.75, y3: y - @cos(rotation - 2.5) * SHIP_SIZE * 0.75 }

// Rock silhouette: ROCK_SIDES vertices on a circle, each pushed out by a
// deterministic jitter folded from (seed, vertex index) — same seed, same
// jagged polygon every frame. Vertex i and i+1 bound one drawn segment;
// the tor reduces i mod ROCK_SIDES so the caller passes a raw counter.
pub tor rock-vert { cx: f32, cy: f32, r: f32, seed: i32, i: i32 } -> { x: f32, y: f32 }

rock-vert -> { x: cx + @cos(@as(f32, @floatFromInt(@mod(i, ROCK_SIDES))) * 0.698132) * r * (0.7 + 0.5 * @as(f32, @floatFromInt(@mod(seed * 31 + @mod(i, ROCK_SIDES) * 97 + seed * @mod(i, ROCK_SIDES) + 13, 997))) / 997.0), y: cy + @sin(@as(f32, @floatFromInt(@mod(i, ROCK_SIDES))) * 0.698132) * r * (0.7 + 0.5 * @as(f32, @floatFromInt(@mod(seed * 31 + @mod(i, ROCK_SIDES) * 97 + seed * @mod(i, ROCK_SIDES) + 13, 997))) / 997.0) }

// Muzzle velocity: ship velocity + BULLET_SPEED along the facing.
pub tor bullet-vel { dx: f32, dy: f32, rotation: f32 } -> { dx: f32, dy: f32 }

bullet-vel -> { dx: dx + @sin(rotation) * BULLET_SPEED, dy: dy - @cos(rotation) * BULLET_SPEED }

pub tor bullet-life {} -> f32

bullet-life -> BULLET_LIFETIME

// ── Asteroids ───────────────────────────────────────────────────────────────
// Split: the two children keep the parent's velocity rotated by ±42 deg, each
// speed-scaled 1.00..1.24 from the draw so the pair diverges.
pub tor split { s: u32, dx: f32, dy: f32 } -> { s2: u32, dx1: f32, dy1: f32, dx2: f32, dy2: f32 }

split -> { s2: (s * RNG_M + RNG_A) % RNG_N, dx1: (dx * SPLIT_COS - dy * SPLIT_SIN) * (1.0 + @as(f32, @floatFromInt(s / 25 % 25)) / 100.0), dy1: (dx * SPLIT_SIN + dy * SPLIT_COS) * (1.0 + @as(f32, @floatFromInt(s / 25 % 25)) / 100.0), dx2: (dx * SPLIT_COS + dy * SPLIT_SIN) * (1.0 + @as(f32, @floatFromInt(s % 25)) / 100.0), dy2: (0.0 - dx * SPLIT_SIN + dy * SPLIT_COS) * (1.0 + @as(f32, @floatFromInt(s % 25)) / 100.0) }

// How many children a destroyed asteroid leaves: 2 above the small floor,
// else 0 (small shards are the last tier).
pub tor split-count { r: f32 } -> i32

split-count -> if (r > CHILD_MIN_R) 2 else 0

// Child radius: half the parent, floored at CHILD_MIN_R.
pub tor child-r { r: f32 } -> f32

child-r -> if (r * 0.5 < CHILD_MIN_R) CHILD_MIN_R else r * 0.5

// ── Collision & bullets ─────────────────────────────────────────────────────
// Circle-circle. Squared compare, no sqrt.
pub tor collide { ax: f32, ay: f32, ar: f32, bx: f32, by: f32, br: f32 } -> bool

collide -> (ax - bx) * (ax - bx) + (ay - by) * (ay - by) <= (ar + br) * (ar + br)

// One bullet''s motion: straight line, lifetime draining.
pub tor bullet-tick { x: f32, y: f32, dx: f32, dy: f32, t: f32, dt: f32 } -> { x: f32, y: f32, t: f32 }

bullet-tick -> { x: x + dx * dt, y: y + dy * dt, t: t - dt }

// ── the world rules ───────────────────────────────────────────────────────
// Everything below this line owns the stores. Each rule is one query arm —
// the one-arm-per-flow shape the store grammar gives.

// One tick: integrate + wrap every body; bullets drain their fuse; the
// invulnerability and cooldown timers decay; then pairwise flags contacts —
// bullet×rock marks both hit, ship×rock kills the ship unless it is still
// ghosting through. Rocks ignore each other, as they should.
pub tor tick { }

tick = std/kernel:init(bodies) {}
    | kernel k |> std/kernel:step(0..1)
        | step |> std/kernel:self {
                const DT = 0.0166666;
                k.x += k.dx * DT;
                k.y += k.dy * DT;
                if (k.x < 0.0) { k.x += 800.0; }
                if (k.x >= 800.0) { k.x -= 800.0; }
                if (k.y < 0.0) { k.y += 600.0; }
                if (k.y >= 600.0) { k.y -= 600.0; }
                if (k.kind > 2.5) {
                    k.t -= DT;
                    if (k.t <= 0.0) { k.dead = 1.0; }
                }
                if (k.inv > 0.0) { k.inv -= DT; }
                if (k.cd > 0.0) { k.cd -= DT; }
                k.hit = 0.0;
            } |> std/kernel:pairwise {
                const ddx = k.x - k.other.x;
                const ddy = k.y - k.other.y;
                const rr = k.r + k.other.r;
                const touching = ddx * ddx + ddy * ddy < rr * rr;
                if (touching) {
                    // bullet × rock — flag both either way round
                    if (k.kind > 2.5 and k.other.kind > 1.5 and k.other.kind < 2.5) {
                        k.hit = 1.0;
                        k.other.hit = 1.0;
                    }
                    if (k.other.kind > 2.5 and k.kind > 1.5 and k.kind < 2.5) {
                        k.hit = 1.0;
                        k.other.hit = 1.0;
                    }
                    // ship × rock — the kill, unless the ship is still ghosting
                    if (k.kind > 0.5 and k.kind < 1.5 and k.other.kind > 1.5 and k.other.kind < 2.5) {
                        if (k.inv <= 0.0) { k.dead = 1.0; }
                    }
                    if (k.other.kind > 0.5 and k.other.kind < 1.5 and k.kind > 1.5 and k.kind < 2.5) {
                        if (k.other.inv <= 0.0) { k.other.dead = 1.0; }
                    }
                }
            }

// Input → the ship row: rotate, thrust along the facing, drag.
pub tor control { left: bool, right: bool, thrusting: bool }

control = std/store:query(bodies)
    ! query e when e.kind == 1.0 and e.dead == 0.0
        |> rotation-delta(left, right, dt: 0.016666): drot
        |> thrust-dx(vx: e.dx, rotation: e.rot + drot, thrusting, dt: 0.016666): tvx
        |> drag-x(vx: tvx, dt: 0.016666): ndx
        |> thrust-dy(vy: e.dy, rotation: e.rot + drot, thrusting, dt: 0.016666): tvy
        |> drag-y(vy: tvy, dt: 0.016666): ndy
        |> std/store:stored { e.rot: e.rot + drot, e.dx: ndx, e.dy: ndy }

// Fire one bullet from the nose while the cooldown is out. The insert lands
// inside the bodies sweep — safe: the appended row is visited this same
// sweep and fails the kind==ship guard, so it is seen, not acted on.
pub tor fire { pressed: bool }

fire = std/store:query(bodies)
    ! query e when e.kind == 1.0 and e.dead == 0.0 and pressed and e.cd <= 0.0
        |> nose(e.x, e.y, rotation: e.rot): n
        |> bullet-vel(e.dx, e.dy, rotation: e.rot): v
        |> std/store:insert(bodies) { n.x, n.y, v.dx, v.dy, kind: 3.0, r: 2.0, t: 1.1, seed: 0, hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0 }
        |> std/store:stored { e.cd: 0.25 }

// Bullets that burned out or struck.
pub tor harvest { }

harvest = std/store:query(bodies)
    ! query e when e.kind > 2.5 and (e.hit == 1.0 or e.dead == 1.0)
        |> std/store:take(bodies[e])
            | item _ |> _

// Rocks that took a bullet — the taken row's fields feed split/score on the
// | item continuation.
pub tor harvest-rocks { }

harvest-rocks = std/store:query(bodies)
    ! query e when e.kind > 1.5 and e.kind < 2.5 and e.hit == 1.0
        |> std/store:take(bodies[e])
            | item i |> spawn-children(i.x, i.y, i.dx, i.dy, i.r, i.seed)
                |> score-rock(i.r)

// A rock big enough splits in two — children keep the parent's velocity
// rotated ±42°, inherit its position and radius halved (floored at the
// minimum). Child seeds come off the parent's LCG chain.
pub tor spawn-children { x: f32, y: f32, dx: f32, dy: f32, r: f32, seed: i32 }

spawn-children = split-count(r): nk
    |> if (nk > 0)
        | then |> split(s: @as(u32, @intCast(seed)), dx, dy): sp
            |> child-r(r): cr
            |> rand(s: sp.s2): r1
            |> rand(s: r1.s2): r2
            |> std/store:insert(bodies) { x, y, dx: sp.dx1, dy: sp.dy1, kind: 2.0, r: cr, t: 0.0, seed: @as(i32, @intCast(r1.v)), hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0 }
            |> std/store:insert(bodies) { x, y, dx: sp.dx2, dy: sp.dy2, kind: 2.0, r: cr, t: 0.0, seed: @as(i32, @intCast(r2.v)), hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0 }
        | else |> _

// Classic scoring: big 20, medium 50, small 100.
pub tor score-rock { r: f32 }

score-rock = std/store:query(game)
    ! query g |> std/store:stored {
        g.score: g.score + @as(f32, if (r > 40.0) 20.0 else (if (r > 25.0) 50.0 else 100.0))
    }

// Ship death: spend a life first; revive only runs while the game is live,
// so the last death leaves the field empty under "game over".
pub tor respawn-ship { }

respawn-ship = std/store:query(bodies)
    ! query e when e.kind == 1.0 and e.dead == 1.0
        |> lose-life()
        |> revive-ship()

pub tor lose-life { }

lose-life = std/store:query(game)
    ! query g |> std/store:stored {
        g.lives: g.lives - 1.0,
        g.over: (if (g.lives <= 1.0) @as(f32, 1.0) else g.over)
    }

pub tor revive-ship { }

revive-ship = std/store:query(game)
    ! query g when g.over == 0.0 |> revive-ship-body()

pub tor revive-ship-body { }

revive-ship-body = std/store:query(bodies)
    ! query e when e.kind == 1.0 and e.dead == 1.0
        |> std/store:stored { e.x: 400.0, e.y: 300.0, e.dx: 0.0, e.dy: 0.0, e.rot: 0.0, e.dead: 0.0, e.inv: 2.0, e.cd: 0.0 }

// Restart: wipe the field, refill lives, reset the ship, seed fresh rocks.
pub tor reset { pressed: bool }

reset = std/store:query(game)
    ! query g when pressed
        |> std/store:stored { g.score: 0.0, g.lives: 3.0, g.over: 0.0 }
        |> clear-field()
        |> reset-ship()
        |> seed-field()

pub tor clear-field { }

clear-field = std/store:query(bodies)
    ! query e when e.kind > 1.5
        |> std/store:take(bodies[e])
            | item _ |> _

pub tor reset-ship { }

reset-ship = std/store:query(bodies)
    ! query e when e.kind == 1.0
        |> std/store:stored { e.x: 400.0, e.y: 300.0, e.dx: 0.0, e.dy: 0.0, e.rot: 0.0, e.dead: 0.0, e.hit: 0.0, e.inv: 0.0, e.cd: 0.0 }

// Three fresh rocks, fixed seeds — the restart is deterministic on purpose.
pub tor seed-field { }

seed-field = std/store:insert(bodies) { x: 600.0, y: 150.0, dx: -40.0, dy: 25.0, kind: 2.0, r: 45.0, t: 0.0, seed: 11, hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0 }
    |> std/store:insert(bodies) { x: 150.0, y: 400.0, dx: 35.0, dy: -20.0, kind: 2.0, r: 35.0, t: 0.0, seed: 23, hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0 }
    |> std/store:insert(bodies) { x: 400.0, y: 550.0, dx: -25.0, dy: -30.0, kind: 2.0, r: 55.0, t: 0.0, seed: 37, hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0 }

// The test/debug door — the ship teleports where a headless run cannot
// steer it. Same trick as ponkatris `launch`.
pub tor place-ship { x: f32, y: f32, dx: f32, dy: f32 }

place-ship = std/store:query(bodies)
    ! query e when e.kind == 1.0
        |> std/store:stored { e.x: x, e.y: y, e.dx: dx, e.dy: dy, e.dead: 0.0, e.inv: 0.0 }

// End-of-run receipts.
pub tor dump { }

dump = std/store:query(bodies)
    ! query e |> std/io:print.ln("kind {{ e.kind:d }} x {{ e.x:f }} y {{ e.y:f }} r {{ e.r:f }} hit {{ e.hit:d }} dead {{ e.dead:d }}")

pub tor dump-game { }

dump-game = std/store:query(game)
    ! query g |> std/io:print.ln("score {{ g.score:d }} lives {{ g.lives:d }} over {{ g.over:d }}")
