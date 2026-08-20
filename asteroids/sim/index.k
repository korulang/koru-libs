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