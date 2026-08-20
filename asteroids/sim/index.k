// sim.k — the pure Asteroids rules. Tors only: values in, values out. No
// state, no host escape, no raylib. Every knob is a named constant; the game
// main composes these tors into its per-frame update, and these same tors are
// what the regression tests pin.
//
// Constants mirror the asteroids-demos reference (bradcypert/asteroids-demos)
// so a knob stays one line in the language it came from. raylib's y grows
// downward, so rotation 0 faces straight up (the reference's sin/-cos
// convention).

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

// Muzzle velocity: ship velocity + BULLET_SPEED along the facing.
pub tor bullet-vel { dx: f32, dy: f32, rotation: f32 } -> { dx: f32, dy: f32 }

bullet-vel -> { dx: dx + @sin(rotation) * BULLET_SPEED, dy: dy - @cos(rotation) * BULLET_SPEED }

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
