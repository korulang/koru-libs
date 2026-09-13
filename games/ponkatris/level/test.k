// test.k — the toy level: one flinger, one crystal, one kill-strip, gravity.
// The headless tests (smoke.k, physics.k) drive this scene through sim.
// The consumer calls spawn() — an unreferenced import is pruned whole,
// module init flows and all.

import std/store
import sim

pub tor spawn { }

spawn = std/store:insert(bodies) { x: 120.0, y: 60.0, vx: 0.0, vy: 0.0, inv_mass: 1.0, kind: 0.0, gx: 0.0, gy: 1000.0, damp: 0.0, radius: 8.0, hw: 0.0, hh: 0.0, e: 0.7, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 400.0, y: 580.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 380.0, hh: 20.0, e: 0.8, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 10.0, y: 300.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 10.0, hh: 300.0, e: 0.5, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 790.0, y: 300.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 10.0, hh: 300.0, e: 0.5, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 550.0, y: 380.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 40.0, hw: 0.0, hh: 0.0, e: 10.5, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 250.0, y: 500.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 12.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 680.0, y: 555.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 4.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 60.0, hh: 5.0, e: 0.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(game) { score: 0.0, total: 1.0, elapsed: 0.0, over: 0.0, won: 0.0, spawn_x: 120.0, spawn_y: 60.0 }
