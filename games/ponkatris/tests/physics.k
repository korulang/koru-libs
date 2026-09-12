// physics.k — the native store+kernel collision engine, oracle-tested.
// No raylib: the engine is a bodies store + one kernel step per tick.
//
// Scene: a marble (kind 0, r=8, e=0.7) dropped at y=50 under gravity 1000
// onto a static floor box (kind 2, top at y=290). Rest y should converge
// to 290 - 10(hh) - 8(r) = 272. Plus a bumper (kind 1, e=10.5) parked to
// the side and a sensor kill-strip (kind 4) under the floor for the flag
// path. Prints ball state after 120 ticks (1s at DT=1/120).

import std/io
import std/store
import std/kernel

// kind: 0 ball (dynamic circle) · 1 bumper (static circle) · 2 wall (static
// box) · 3 crystal (sensor box) · 4 killzone (sensor box)
std/store:new(bodies, capacity: 256) {
    x: f64, y: f64, vx: f64, vy: f64,
    inv_mass: f64, kind: f64,
    radius: f64, hw: f64, hh: f64, e: f64,
    hit: f64, dead: f64
}

std/store:insert(bodies) { x: 400.0, y: 50.0, vx: 0.0, vy: 0.0, inv_mass: 1.0, kind: 0.0, radius: 8.0, hw: 0.0, hh: 0.0, e: 0.7, hit: 0.0, dead: 0.0 }
std/store:insert(bodies) { x: 400.0, y: 300.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2.0, radius: 0.0, hw: 300.0, hh: 10.0, e: 0.8, hit: 0.0, dead: 0.0 }
std/store:insert(bodies) { x: 200.0, y: 200.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, radius: 40.0, hw: 0.0, hh: 0.0, e: 10.5, hit: 0.0, dead: 0.0 }
std/store:insert(bodies) { x: 400.0, y: 400.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 4.0, radius: 0.0, hw: 300.0, hh: 10.0, e: 0.0, hit: 0.0, dead: 0.0 }

std/kernel:init(bodies) {}
| kernel k |> std/kernel:step(0..120)
    | step |> std/kernel:self {
            const DT = 0.008333333333333333;
            const GRAV = 1000.0;
            if (k.inv_mass > 0.0) {
                k.vy += GRAV * DT;
                k.x += k.vx * DT;
                k.y += k.vy * DT;
            }
            k.hit = 0.0;
        } |> std/kernel:pairwise {
            const im = k.inv_mass + k.other.inv_mass;
            if (im > 0.0) {
                const kCirc = k.kind < 1.5;
                const oCirc = k.other.kind < 1.5;
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
                            const e = @max(k.e, k.other.e);
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

std/store:query(bodies)
! query r |> std/io:print.ln("kind {{ r.kind:d }} x {{ r.x:f }} y {{ r.y:f }} vx {{ r.vx:f }} vy {{ r.vy:f }} hit {{ r.hit:d }} dead {{ r.dead:d }}")
