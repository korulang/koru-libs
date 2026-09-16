// index.k — asteroids-net sim: the asteroids rules, forked for N players.
//
// Same architecture as the single-player sim — one kind-discriminated
// `bodies` store, kernel:self integrates, kernel:pairwise flags contacts,
// query arms sweep. What the server adds:
//
//   owner   — a bodies column: which player's ship this is (0 = world-owned
//             rocks). Bullets carry their firer's pid.
//   players — the session store: one row per connected client, keyed by the
//             udp packet.key fold (i64). Carries the per-player respawn
//             clock (rt/waiting) and the staleness baseline (last tick).
//   drive   — the per-packet tor: find-or-join the session, then apply that
//             player's input to their ship. The server's whole input path.
//
// Lives and game-over are gone for v0 — co-op rules: shared score, shared
// waves, ships respawn 1.5s after dying, forever. Restart = rerun.

import std/io
import std/store
import std/kernel
import std/grid

// 1024: players cap is 256, and N ships + rocks + live bullets already
// overflowed the entity store at N=128 — late joiners spawned shipless.
// Entity rows must exceed the session ceiling or the caps disagree by
// construction.
std/store:new(bodies, capacity: 1024) {
    x: f32, y: f32, dx: f32, dy: f32,
    kind: f32, r: f32, t: f32,
    seed: i32,
    hit: f32, dead: f32,
    rot: f32, inv: f32, cd: f32,
    owner: f32
}

std/store:new(players, capacity: 256) {
    pid: f32, key: i64, rt: f32, waiting: f32, last: f32,
    lseq: f32, drops: f32
}

std/store:new(game, capacity: 2) {
    score: f32, wave: f32, rocks: f32, pending: f32,
    seed: f32, nextpid: f32
}

// spawn-player's answer slot — a `| row` arm can write a grid cell but
// can't return a scalar, so the join path parks the new pid here and the
// none-chain reads it back (0 = refused).
std/grid:new(lookup, size: 1) { pid: 0.0[f32] }

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

// Speed clamp: the scale factor that pulls a velocity back under
// MAX_SHIP_SPEED (380^2 = 144400 — squared compare, one sqrt only when over).
pub tor cap-scale { dx: f32, dy: f32 } -> f32

cap-scale -> if (dx * dx + dy * dy > 144400.0) MAX_SHIP_SPEED / @sqrt(dx * dx + dy * dy) else 1.0

// Either key held — A/D mirror the arrows in the reference.
pub tor either { a: bool, b: bool } -> bool

either -> a or b

// Invulnerability blink: while inv > 0 the ship flickers at 10Hz — the
// reference blinks off wall-clock time; we blink off the timer itself,
// which is the same flicker and stays deterministic.
pub tor ship-visible { inv: f32 } -> bool

ship-visible -> if (inv <= 0.0) true else (@mod(@as(i32, @intFromFloat(inv * 10.0)), 2) == 1)
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

// Wave spawn point: edge 0..3 picks a side (left, right, top, bottom), p
// (0..99) is the position along it — rocks always enter from the rim,
// never on top of the ship.
pub tor edge-x { edge: u32, p: f32 } -> f32

edge-x -> if (edge == 0) 0.0 else (if (edge == 1) 800.0 else p * 8.0)

pub tor edge-y { edge: u32, p: f32 } -> f32

edge-y -> if (edge == 2) 0.0 else (if (edge == 3) 600.0 else p * 6.0)

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

// Muzzle velocity: BULLET_SPEED along the facing — the reference does not
// inherit the ship's velocity, the shot is pure facing.
pub tor bullet-vel { rotation: f32 } -> { dx: f32, dy: f32 }

bullet-vel -> { dx: @sin(rotation) * BULLET_SPEED, dy: 0.0 - @cos(rotation) * BULLET_SPEED }

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

// One tick: integrate every body; the ship and the rocks wrap at the rim,
// bullets die there instead (the reference contract: a shot off the edge
// is gone); bullets also drain their fuse; the invulnerability and
// cooldown timers decay; then pairwise flags contacts — bullet×rock marks
// both hit, ship×rock kills the ship unless it is still ghosting through.
// Rocks ignore each other, as they should.
pub tor tick { }

tick = std/kernel:init(bodies) {}
    | kernel k |> std/kernel:step(0..1)
        | step |> std/kernel:self {
                const DT = 0.0166666;
                k.x += k.dx * DT;
                k.y += k.dy * DT;
                if (k.kind > 2.5) {
                    k.t -= DT;
                    if (k.t <= 0.0) { k.dead = 1.0; }
                    if (k.x < 0.0) { k.dead = 1.0; }
                    if (k.x >= 800.0) { k.dead = 1.0; }
                    if (k.y < 0.0) { k.dead = 1.0; }
                    if (k.y >= 600.0) { k.dead = 1.0; }
                } else {
                    if (k.x < 0.0) { k.x += 800.0; }
                    if (k.x >= 800.0) { k.x -= 800.0; }
                    if (k.y < 0.0) { k.y += 600.0; }
                    if (k.y >= 600.0) { k.y -= 600.0; }
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

// Input → that player's ship row: rotate, thrust along the facing, clamp to
// MAX_SHIP_SPEED, drag (the reference order: thrust, cap, drag). owner is
// the per-client guard — every client drives exactly its own ship.
pub tor control { pid: f32, left: bool, right: bool, thrusting: bool }

control = std/store:query(bodies)
    ! first e when e.kind == 1.0 and e.owner == pid and e.dead == 0.0
        |> rotation-delta(left, right, dt: 0.016666): drot
        |> thrust-dx(vx: e.dx, rotation: e.rot + drot, thrusting, dt: 0.016666): tvx
        |> thrust-dy(vy: e.dy, rotation: e.rot + drot, thrusting, dt: 0.016666): tvy
        |> cap-scale(dx: tvx, dy: tvy): cs
        |> drag-x(vx: tvx * cs, dt: 0.016666): ndx
        |> drag-y(vy: tvy * cs, dt: 0.016666): ndy
        |> std/store:stored { e.rot: e.rot + drot, e.dx: ndx, e.dy: ndy }

// Fire one bullet from the nose while the cooldown is out. The insert lands
// inside the bodies sweep — safe: `! first` has already exited, so the
// appended row is never visited by this scan at all.
pub tor fire { pid: f32, pressed: bool }

fire = std/store:query(bodies)
    ! first e when e.kind == 1.0 and e.owner == pid and e.dead == 0.0 and pressed and e.cd <= 0.0
        |> nose(e.x, e.y, rotation: e.rot): n
        |> bullet-vel(rotation: e.rot): v
        |> std/store:insert(bodies) { n.x, n.y, v.dx, v.dy, kind: 3.0, r: 2.0, t: 1.1, seed: 0, hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0, owner: pid }
            | row _ |> std/store:stored { e.cd: 0.25 }
            | full |> _

// Bullets that burned out or struck.
pub tor harvest { }

harvest = std/store:query(bodies)
    ! query e when e.kind > 2.5 and (e.hit == 1.0 or e.dead == 1.0)
        |> std/store:take(bodies[e])
            | item _ |> _

// Rocks that took a bullet — the taken row's fields feed split/score on the
// | item continuation. The game row's rock count is the wave trigger's
// census: parent out (-1), children in (+2 inside spawn-children).
pub tor harvest-rocks { }

harvest-rocks = std/store:query(bodies)
    ! query e when e.kind > 1.5 and e.kind < 2.5 and e.hit == 1.0
        |> std/store:take(bodies[e])
            | item i |> spawn-children(i.x, i.y, i.dx, i.dy, i.r, i.seed)
                |> score-rock(i.r)
                |> bump-rocks(n: 0.0 - 1.0)

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
            |> std/store:insert(bodies) { x, y, dx: sp.dx1, dy: sp.dy1, kind: 2.0, r: cr, t: 0.0, seed: @as(i32, @intCast(r1.v)), hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0, owner: 0.0 }
                | row _ |> std/store:insert(bodies) { x, y, dx: sp.dx2, dy: sp.dy2, kind: 2.0, r: cr, t: 0.0, seed: @as(i32, @intCast(r2.v)), hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0, owner: 0.0 }
                    | row _ |> bump-rocks(n: 2.0)
                    | full |> bump-rocks(n: 1.0)
                | full |> _
        | else |> _

// Classic scoring: big 20, medium 50, small 100.
pub tor score-rock { r: f32 }

score-rock = std/store:query(game)
    ! query g |> std/store:stored {
        g.score: g.score + @as(f32, if (r > 40.0) 20.0 else (if (r > 25.0) 50.0 else 100.0))
    }

// Ship death is per-owner now: the dead ship marks itself processed (t=1)
// and the PLAYER's row carries the respawn clock — one death arms one
// client's timer, everyone else keeps playing (co-op: no lives, no over).
pub tor respawn-ship { }

respawn-ship = std/store:query(bodies)
    ! query e when e.kind == 1.0 and e.dead == 1.0 and e.t == 0.0
        |> arm-respawn(pid: e.owner)
        |> std/store:stored { e.t: 1.0 }

tor arm-respawn { pid: f32 }

arm-respawn = std/store:query(players)
    ! query p when p.pid == pid
        |> std/store:stored { p.rt: 1.5, p.waiting: 1.0 }

// The respawn clock lives on the session row: decay per tick; when it runs
// out the waiting ship reappears at its spawn spot, ghosting.
pub tor respawn-tick { }

respawn-tick = std/store:query(players)
    ! query p when p.rt > 0.0
        |> std/store:stored { p.rt: p.rt - 0.016666 }

pub tor maybe-revive { }

maybe-revive = std/store:query(players)
    ! query p when p.waiting == 1.0 and p.rt <= 0.0
        |> revive-ship-body(p.pid)
        |> std/store:stored { p.waiting: 0.0 }

tor revive-ship-body { pid: f32 }

revive-ship-body = std/store:query(bodies)
    ! query e when e.kind == 1.0 and e.owner == pid and e.dead == 1.0
        |> spawn-spot(pid): spot
        |> std/store:stored { e.x: spot.x, e.y: spot.y, e.dx: 0.0, e.dy: 0.0, e.rot: 0.0, e.dead: 0.0, e.inv: 2.0, e.cd: 0.0, e.t: 0.0 }

// ── waves ─────────────────────────────────────────────────────────────────
// The reference's escalating field: wave N puts 3+N large rocks on the rim.
// The census is bookkeeping (bump-rocks at every insert/take) so wave-check
// needs no NOT EXISTS; an empty field arms the next wave, and spawn-tick
// deals it out one rock per tick — ~70ms to materialize, deterministic off
// the game row's LCG seed.

// One rock-count adjustment — every insert and take in the field funnels
// through here so the census stays live.
pub tor bump-rocks { n: f32 }

bump-rocks = std/store:query(game)
    ! query g |> std/store:stored { g.rocks: g.rocks + n }

// An empty, quiet field (no rocks, none pending) advances the wave and
// arms 3 + wave spawns — wave 1 deals 4, like the reference. No `over`
// guard in co-op: the field escalates forever.
// (stored reads the pre-update row, so pending = old wave + 4 = new + 3.)
pub tor wave-check { }

wave-check = std/store:query(game)
    ! query g when g.rocks <= 0.0 and g.pending <= 0.0
        |> std/store:stored { g.wave: g.wave + 1.0, g.pending: g.wave + 4.0 }

// One pending rock per tick: four LCG draws pick the rim edge, the spot
// along it, the heading, and the speed band (40..110 like the reference);
// a fifth seeds the jagged polygon.
pub tor spawn-tick { }

spawn-tick = std/store:query(game)
    ! query g when g.pending > 0.0
        |> rand-under(s: @as(u32, @intFromFloat(g.seed)), n: 4): e1
        |> rand-under(s: e1.s2, n: 100): p1
        |> rand-under(s: p1.s2, n: 360): a1
        |> rand-under(s: a1.s2, n: 70): v1
        |> rand(s: v1.s2): j1
        |> edge-x(edge: e1.v, p: @as(f32, @floatFromInt(p1.v))): ex
        |> edge-y(edge: e1.v, p: @as(f32, @floatFromInt(p1.v))): ey
        |> dir(deg: a1.v, speed: 40.0 + @as(f32, @floatFromInt(v1.v))): vel
        |> std/store:insert(bodies) { x: ex, y: ey, vel.dx, vel.dy, kind: 2.0, r: 45.0, t: 0.0, seed: @as(i32, @intCast(j1.v)), hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0, owner: 0.0 }
            | row _ |> std/store:stored { g.pending: g.pending - 1.0, g.rocks: g.rocks + 1.0, g.seed: @as(f32, @floatFromInt(j1.s2)) }
            | full |> _

// ── sessions ────────────────────────────────────────────────────────────
// The server's whole input path: one packet → one drive() call. The key is
// udp's packet.key fold (addr<<16|port). `! first` finds the session row and
// stops; `| none` is the join path — the find-or-join arm pair, one scan.
// seq is the client's tick: seq > lseq is fresh input — the gap counts into
// drops (inputs the server never saw); seq <= lseq is a dup/reorder —
// liveness only, never re-applied.
//
// `| none` resets lookup's pid before the join attempt, so a refused join
// (| full in spawn-player) leaves it 0 and the input application no-ops —
// the client never hears its pid, and the next packet retries.
pub tor drive { key: i64, tick: f32, seq: f32, left: bool, right: bool, thrusting: bool, firing: bool }

drive = std/store:query(players)
    ! first p when p.key == key
        |> if (seq > p.lseq)
            | then |> std/store:stored { p.last: tick, p.drops: p.drops + seq - p.lseq - 1.0, p.lseq: seq }
                |> control(p.pid, left, right, thrusting)
                |> fire(p.pid, pressed: firing)
            | else |> std/store:stored { p.last: tick }
    | none |> std/grid:stored { lookup[0].pid: 0.0 }
        |> spawn-player(key, tick, seq)
        |> if (lookup[0].pid != 0.0)
            | then |> control(lookup[0].pid, left, right, thrusting)
                |> fire(lookup[0].pid, pressed: firing)
            | else |> _

// Spawn spots fan out on a 4×2 midline grid by pid — deterministic, spread
// enough that two joining ships don't overlap.
pub tor spawn-spot { pid: f32 } -> { x: f32, y: f32 }

spawn-spot -> { x: 80.0 + @mod(pid, 4.0) * 213.0, y: 80.0 + @mod(@floor(pid / 4.0), 2.0) * 440.0 }

// A refused join is a boundary, not a crash: | full leaves lookup at 0,
// so the caller's input application no-ops and the client just never
// hears its pid. The packet still touched nothing — next one retries.
tor spawn-player { key: i64, tick: f32, seq: f32 }

spawn-player = std/store:query(game)
    ! query g |> std/store:insert(players) { pid: g.nextpid, key, rt: 0.0, waiting: 0.0, last: tick, lseq: seq, drops: 0.0 }
        | row _ |> std/grid:stored { lookup[0].pid: g.nextpid }
            |> spawn-ship(pid: g.nextpid)
            |> std/store:stored { g.nextpid: g.nextpid + 1.0 }
        | full |> std/io:print.ln("server full — refused join, key {{ key:d }}")

tor spawn-ship { pid: f32 }

// bodies-full leaves a shipless session row — a ghost that hears snaps
// but owns nothing. Graceful, and the watcher's per-pid tracking would
// report it as "no own ship" rather than hide it.
spawn-ship = spawn-spot(pid): spot
    |> std/store:insert(bodies) { spot.x, spot.y, dx: 0.0, dy: 0.0, kind: 1.0, r: 12.0, t: 0.0, seed: 0, hit: 0.0, dead: 0.0, rot: 0.0, inv: 2.0, cd: 0.0, owner: pid }
        | row _ |> _
        | full |> _

// A client silent for `timeout` ticks forfeits: the session row takes, then
// its ship — take's | item arm carries pid across the two stores.
pub tor sweep-stale { tick: f32, timeout: f32 }

sweep-stale = std/store:query(players)
    ! query p when tick - p.last > timeout
        |> std/store:take(players[p])
            | item i |> remove-ship(i.pid)

tor remove-ship { pid: f32 }

remove-ship = std/store:query(bodies)
    ! query e when e.kind == 1.0 and e.owner == pid
        |> std/store:take(bodies[e])
            | item _ |> _

// The test/debug door — a ship teleports where a headless run cannot
// steer it. Same trick as ponkatris `launch`.
pub tor place-ship { pid: f32, x: f32, y: f32, dx: f32, dy: f32 }

place-ship = std/store:query(bodies)
    ! query e when e.kind == 1.0 and e.owner == pid
        |> std/store:stored { e.x: x, e.y: y, e.dx: dx, e.dy: dy, e.dead: 0.0, e.inv: 0.0, e.t: 0.0 }

// End-of-run receipts.
pub tor dump { }

dump = std/store:query(bodies)
    ! query e |> std/io:print.ln("kind {{ e.kind:d }} x {{ e.x:f }} y {{ e.y:f }} r {{ e.r:f }} hit {{ e.hit:d }} dead {{ e.dead:d }}")

pub tor dump-game { }

dump-game = std/store:query(game)
    ! query g |> std/io:print.ln("score {{ g.score:d }} wave {{ g.wave:d }} rocks {{ g.rocks:d }} pending {{ g.pending:d }} seed {{ g.seed:d }} nextpid {{ g.nextpid:d }}")

pub tor dump-players { }

dump-players = std/store:query(players)
    ! query p |> std/io:print.ln("player pid {{ p.pid:d }} key {{ p.key:d }} last {{ p.last:d }} rt {{ p.rt:f }} waiting {{ p.waiting:d }} drops {{ p.drops:d }}")
