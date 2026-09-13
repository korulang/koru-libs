// index.k — ponkatris sim: the native store+kernel physics slice.
//
// One `bodies` store is the world. `kernel:self` integrates,
// `kernel:pairwise` resolves contacts. kind discriminates the union:
//   0 ball (dynamic circle) · 1 bumper (static circle, e=10.5 — a flinger)
//   2 wall (static box) · 3 crystal (sensor circle) · 4 killzone (sensor box)
// Sensors set `hit` on themselves and `dead` on the other body; no impulse.
// Fixed DT=1/120 — one tick per rendered frame.
// Gravity is per-body (`gx`,`gy` columns): the level format's `World:` line
// carries it, and pacman is a zero-g maze, not a faller.
// The sim owns no scene — a `level/` module inserts the world.

import std/io
import std/store
import std/kernel

std/store:new(bodies, capacity: 512) {
    x: f64, y: f64, vx: f64, vy: f64,
    inv_mass: f64, kind: f64, gx: f64, gy: f64, damp: f64,
    radius: f64, hw: f64, hh: f64, e: f64,
    hit: f64, dead: f64
}

// The game state is a second store, one row: score vs the level's crystal
// total, elapsed time (a timed run — the clock counts UP), and the two
// terminal flags. Keeping it in a store (not ambient scalars) is deliberate
// — rules are `stored` writes like every other mutation in the engine.
// The level inserts the row: `total` is the level's crystal count.
std/store:new(game, capacity: 4) {
    score: f64, total: f64, elapsed: f64, over: f64, won: f64,
    spawn_x: f64, spawn_y: f64
}

// One physics tick: integrate, then resolve every contact pair.
pub tor tick { }

tick = std/kernel:init(bodies) {}
    | kernel k |> std/kernel:step(0..1)
        | step |> std/kernel:self {
                const DT = 0.008333333333333333;
                if (k.inv_mass > 0.0) {
                    k.vx += k.gx * DT;
                    k.vy += k.gy * DT;
                    // linear damping (oracle: LinearDamping(0.5)) — zero-g
                    // mazes need it or the marble drifts forever.
                    k.vx *= 1.0 - k.damp * DT;
                    k.vy *= 1.0 - k.damp * DT;
                    k.x += k.vx * DT;
                    k.y += k.vy * DT;
                }
                k.hit = 0.0;
            } |> std/kernel:pairwise {
                const im = k.inv_mass + k.other.inv_mass;
                if (im > 0.0) {
                    // circles: ball, bumper, crystal-sensor. boxes: wall,
                    // killzone-sensor.
                    const kCirc = k.kind < 1.5 or (k.kind > 2.5 and k.kind < 3.5);
                    const oCirc = k.other.kind < 1.5 or (k.other.kind > 2.5 and k.other.kind < 3.5);
                    var nx: f64 = 0.0;
                    var ny: f64 = 0.0;
                    var pen: f64 = 0.0;
                    if (kCirc and oCirc) {
                        const dx = k.x - k.other.x;
                        const dy = k.y - k.other.y;
                        const rr = k.radius + k.other.radius;
                        const d2 = dx * dx + dy * dy;
                        if (d2 < rr * rr and d2 > 0.00000001) {
                            const d = @sqrt(d2);
                            pen = rr - d;
                            nx = dx / d;
                            ny = dy / d;
                        } else if (d2 <= 0.00000001 and rr > 0.0) {
                            // concentric: still a contact — sensors must see it.
                            pen = rr;
                            ny = -1.0;
                        }
                    } else {
                        // circle vs box — n convention: other -> k
                        var cx: f64 = k.x; var cy: f64 = k.y; var cr: f64 = k.radius;
                        var bx: f64 = k.other.x; var by: f64 = k.other.y; var bhw: f64 = k.other.hw; var bhh: f64 = k.other.hh;
                        var flip: f64 = 1.0;
                        if (!kCirc) {
                            cx = k.other.x; cy = k.other.y; cr = k.other.radius;
                            bx = k.x; by = k.y; bhw = k.hw; bhh = k.hh;
                            flip = -1.0;
                        }
                        const qx = @max(bx - bhw, @min(cx, bx + bhw));
                        const qy = @max(by - bhh, @min(cy, by + bhh));
                        const dx = cx - qx;
                        const dy = cy - qy;
                        const d2 = dx * dx + dy * dy;
                        if (d2 < cr * cr and d2 > 0.00000001) {
                            const d = @sqrt(d2);
                            pen = cr - d;
                            nx = dx / d * flip;
                            ny = dy / d * flip;
                        } else if (d2 <= 0.00000001) {
                            // circle center inside the box: exit along the
                            // least-penetration axis (deep overlap — the
                            // closest-point clamp degenerates to the center).
                            const ex = cx - bx;
                            const ey = cy - by;
                            const px = bhw - @abs(ex);
                            const py = bhh - @abs(ey);
                            if (px < py) {
                                pen = px + cr;
                                nx = (if (ex > 0.0) @as(f64, 1.0) else @as(f64, -1.0)) * flip;
                                ny = 0.0;
                            } else {
                                pen = py + cr;
                                nx = 0.0;
                                ny = (if (ey > 0.0) @as(f64, 1.0) else @as(f64, -1.0)) * flip;
                            }
                        }
                    }
                    if (pen > 0.0) {
                        const sensor = (k.kind > 2.5) or (k.other.kind > 2.5);
                        if (sensor) {
                            if (k.kind > 2.5) {
                                k.hit = 1.0;
                                if (k.kind > 3.5) { k.other.dead = 1.0; }
                            }
                            if (k.other.kind > 2.5) {
                                k.other.hit = 1.0;
                                if (k.other.kind > 3.5) { k.dead = 1.0; }
                            }
                        } else {
                            const rvx = k.vx - k.other.vx;
                            const rvy = k.vy - k.other.vy;
                            const vn = rvx * nx + rvy * ny;
                            if (vn < 0.0) {
                                // Restitution threshold (Box2D's velocityThreshold):
                                // sub-threshold impacts are inelastic — a grazing
                                // touch on a flinger must not launch at 10.5x.
                                var e = @max(k.e, k.other.e);
                                if (0.0 - vn < 100.0) { e = 0.0; }
                                const jn = 0.0 - (1.0 + e) * vn / im;
                                k.vx += jn * nx * k.inv_mass;
                                k.vy += jn * ny * k.inv_mass;
                                k.other.vx -= jn * nx * k.other.inv_mass;
                                k.other.vy -= jn * ny * k.other.inv_mass;
                            }
                            const corr = pen * 0.8 / im;
                            k.x += nx * corr * k.inv_mass;
                            k.y += ny * corr * k.inv_mass;
                            k.other.x -= nx * corr * k.other.inv_mass;
                            k.other.y -= ny * corr * k.other.inv_mass;
                        }
                    }
                }
            }

// Player thrust: WASD/arrows add velocity. Magnitude per direction is the
// level's `Movement: l r u d` in px/s² × DT — the caller passes the deltas.
pub tor thrust { left: f64, right: f64, up: f64, down: f64 }

thrust = std/store:query(bodies)
    ! query e when e.kind == 0.0
        |> std/store:stored {
            e.vx: e.vx + right - left,
            e.vy: e.vy + down - up
        }

// Rules — each tor is one query arm (the one-arm-per-flow shape). The frame
// loop calls collect/respawn/countdown after tick; reset* is the R-key path.

// A crystal that took a sensor hit is taken; the item continuation bumps
// score and flips `won` when the level's total is reached.
pub tor collect { }

collect = std/store:query(bodies)
    ! query e when e.kind == 3.0 and e.hit == 1.0
        |> std/store:take(bodies[e])
            | item _ |> bump-score()

pub tor bump-score { }

bump-score = std/store:query(game)
    ! query g |> std/store:stored {
        g.score: g.score + 1.0,
        g.won: (if (g.score + 1.0 >= g.total) @as(f64, 1.0) else g.won)
    }

// A dead ball (killzone) returns to the level's spawn point with cleared
// velocity and flags. The spawn lives on the game row — the level set it.
pub tor respawn { }

respawn = std/store:query(game)
    ! query g |> respawn-at(g.spawn_x, g.spawn_y)

pub tor respawn-at { spawn_x: f64, spawn_y: f64 }

respawn-at = std/store:query(bodies)
    ! query e when e.kind == 0.0 and e.dead == 1.0
        |> std/store:stored { e.x: spawn_x, e.y: spawn_y, e.vx: 0.0, e.vy: 0.0, e.dead: 0.0, e.hit: 0.0 }

// Timed run: the clock counts UP while the game is live. `won` freezes it.
pub tor stopwatch { }

stopwatch = std/store:query(game)
    ! query g when g.over == 0.0 and g.won == 0.0
        |> std/store:stored { g.elapsed: g.elapsed + 0.008333333333333333 }

// Restart: take any remaining crystals (the level re-seeds them — its
// spawn-crystals tor goes next in the caller's chain), send the ball back
// to the level's spawn point, reset the run fields on the game row.
pub tor reset { pressed: bool }

reset = std/store:query(bodies)
    ! query e when pressed and e.kind == 3.0
        |> std/store:take(bodies[e])
            | item _ |> _

pub tor reset-ball { pressed: bool }

reset-ball = std/store:query(game)
    ! query g when pressed |> reset-ball-at(g.spawn_x, g.spawn_y)

pub tor reset-ball-at { spawn_x: f64, spawn_y: f64 }

reset-ball-at = std/store:query(bodies)
    ! query e when e.kind == 0.0
        |> std/store:stored { e.x: spawn_x, e.y: spawn_y, e.vx: 0.0, e.vy: 0.0, e.dead: 0.0, e.hit: 0.0 }

pub tor reset-game { pressed: bool }

reset-game = std/store:query(game)
    ! query g when pressed
        |> std/store:stored { g.score: 0.0, g.elapsed: 0.0, g.over: 0.0, g.won: 0.0 }

// Place the ball directly — the test/debug door. Headless runs can't press
// keys; teleport + tick + the rules tors exercise collect/respawn paths
// deterministically.
pub tor teleport { x: f64, y: f64 }

teleport = std/store:query(bodies)
    ! query e when e.kind == 0.0
        |> std/store:stored { e.x: x, e.y: y, e.vx: 0.0, e.vy: 0.0, e.dead: 0.0, e.hit: 0.0 }

// Place AND launch — the graze/fling test door. `teleport` can't express an
// incoming velocity, and a restitution threshold can only be observed by
// arriving at a contact with a known vn.
pub tor launch { x: f64, y: f64, vx: f64, vy: f64 }

launch = std/store:query(bodies)
    ! query e when e.kind == 0.0
        |> std/store:stored { e.x: x, e.y: y, e.vx: vx, e.vy: vy, e.dead: 0.0, e.hit: 0.0 }

// End-of-run receipt: every body row, then the game row.
pub tor dump { }

dump = std/store:query(bodies)
    ! query r |> std/io:print.ln("kind {{ r.kind:d }} x {{ r.x:f }} y {{ r.y:f }} hit {{ r.hit:d }} dead {{ r.dead:d }}")

pub tor dump-game { }

dump-game = std/store:query(game)
    ! query g |> std/io:print.ln("score {{ g.score:d }}/{{ g.total:d }} t {{ g.elapsed:f }} over {{ g.over:d }} won {{ g.won:d }}")
