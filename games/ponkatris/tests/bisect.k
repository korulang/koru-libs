// bisect.k — reproduce the main.k explosion headless. Same level layout,
// chunked steps with prints between to watch the ball's trajectory.

import std/io
import std/store
import std/kernel

std/store:new(bodies, capacity: 256) {
    x: f64, y: f64, vx: f64, vy: f64,
    inv_mass: f64, kind: i32,
    radius: f64, hw: f64, hh: f64, e: f64,
    hit: i32, dead: i32
}

std/store:insert(bodies) { x: 120.0, y: 60.0, vx: 0.0, vy: 0.0, inv_mass: 1.0, kind: 0, radius: 8.0, hw: 0.0, hh: 0.0, e: 0.7, hit: 0, dead: 0 }
std/store:insert(bodies) { x: 400.0, y: 580.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2, radius: 0.0, hw: 380.0, hh: 20.0, e: 0.8, hit: 0, dead: 0 }
std/store:insert(bodies) { x: 10.0, y: 300.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2, radius: 0.0, hw: 10.0, hh: 300.0, e: 0.5, hit: 0, dead: 0 }
std/store:insert(bodies) { x: 790.0, y: 300.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2, radius: 0.0, hw: 10.0, hh: 300.0, e: 0.5, hit: 0, dead: 0 }
std/store:insert(bodies) { x: 550.0, y: 380.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1, radius: 40.0, hw: 0.0, hh: 0.0, e: 10.5, hit: 0, dead: 0 }
std/store:insert(bodies) { x: 250.0, y: 500.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, radius: 0.0, hw: 12.0, hh: 12.0, e: 0.0, hit: 0, dead: 0 }
std/store:insert(bodies) { x: 680.0, y: 555.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 4, radius: 0.0, hw: 60.0, hh: 5.0, e: 0.0, hit: 0, dead: 0 }

std/kernel:init(bodies) {}
| kernel k |> std/kernel:step(0..300)
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
! query r when r.kind == 0 |> std/io:print.ln("t300 ball x {{ r.x:f }} y {{ r.y:f }} vx {{ r.vx:f }} vy {{ r.vy:f }} hit {{ r.hit:d }} dead {{ r.dead:d }}")

std/kernel:init(bodies) {}
| kernel k |> std/kernel:step(0..300)
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
! query r when r.kind == 0 |> std/io:print.ln("t600 ball x {{ r.x:f }} y {{ r.y:f }} vx {{ r.vx:f }} vy {{ r.vy:f }} hit {{ r.hit:d }} dead {{ r.dead:d }}")
