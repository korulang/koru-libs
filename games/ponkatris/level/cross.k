// cross.k — the first level, remade for feel: two crossed pink
// kill-bars over a dot field. One horizontal bar across the middle, one
// diagonal — staircased from axis-aligned boxes because the narrowphase
// is AABB-only (SAT is a named gap). Zero-g marble, count-up clock.

import std/store
import sim

pub tor spawn { }

// marble spawns bottom-center; the bars gate every route north
spawn = std/store:insert(bodies) { x: 300, y: 600, vx: 0.0, vy: 0.0, inv_mass: 1.0, kind: 0, gx: 0.0, gy: 0.0, damp: 0.5, radius: 12.0, hw: 0.0, hh: 0.0, e: 0.2, hit: 0, dead: 0 }
    |> std/store:insert(game) { score: 0, total: 66, elapsed: 0.0, over: 0, won: 0, spawn_x: 300.0, spawn_y: 600.0 }
    |> std/store:insert(bodies) { x: 310, y: 15, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 300.0, hh: 15.0, e: 0.0, hit: 0, dead: 0 }
    |> std/store:insert(bodies) { x: 310, y: 665, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 300.0, hh: 15.0, e: 0.0, hit: 0, dead: 0 }
    |> std/store:insert(bodies) { x: 10, y: 340, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 10.0, hh: 325.0, e: 0.0, hit: 0, dead: 0 }
    |> std/store:insert(bodies) { x: 610, y: 340, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 10.0, hh: 325.0, e: 0.0, hit: 0, dead: 0 }
    |> std/store:insert(bodies) { x: 300, y: 340, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 4, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 190.0, hh: 10.0, e: 0.0, hit: 0, dead: 0 }
    |> std/store:insert(bodies) { x: 165, y: 255, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 4, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 34.0, hh: 22.0, e: 0.0, hit: 0, dead: 0 }
    |> std/store:insert(bodies) { x: 210, y: 283, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 4, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 34.0, hh: 22.0, e: 0.0, hit: 0, dead: 0 }
    |> std/store:insert(bodies) { x: 255, y: 311, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 4, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 34.0, hh: 22.0, e: 0.0, hit: 0, dead: 0 }
    |> std/store:insert(bodies) { x: 300, y: 339, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 4, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 34.0, hh: 22.0, e: 0.0, hit: 0, dead: 0 }
    |> std/store:insert(bodies) { x: 345, y: 367, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 4, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 34.0, hh: 22.0, e: 0.0, hit: 0, dead: 0 }
    |> std/store:insert(bodies) { x: 390, y: 395, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 4, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 34.0, hh: 22.0, e: 0.0, hit: 0, dead: 0 }
    |> std/store:insert(bodies) { x: 435, y: 423, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 4, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 34.0, hh: 22.0, e: 0.0, hit: 0, dead: 0 }
    |> spawn-crystals(pressed: true)

// dots — re-seeded on restart after sim:reset takes the survivors.
pub tor spawn-crystals { pressed: bool }

spawn-crystals = std/store:query(game)
    ! query g when pressed
        |> std/store:insert(bodies) { x: 80, y: 100, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 120, y: 100, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 160, y: 100, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 200, y: 100, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 240, y: 100, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 280, y: 100, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 320, y: 100, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 360, y: 100, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 400, y: 100, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 440, y: 100, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 480, y: 100, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 520, y: 100, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 560, y: 100, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 80, y: 180, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 120, y: 180, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 160, y: 180, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 200, y: 180, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 240, y: 180, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 280, y: 180, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 320, y: 180, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 360, y: 180, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 400, y: 180, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 440, y: 180, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 480, y: 180, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 520, y: 180, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 560, y: 180, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 60, y: 270, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 100, y: 270, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 60, y: 300, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 100, y: 300, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 520, y: 380, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 560, y: 380, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 520, y: 410, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 560, y: 410, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 80, y: 560, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 120, y: 560, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 160, y: 560, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 200, y: 560, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 240, y: 560, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 280, y: 560, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 320, y: 560, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 360, y: 560, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 400, y: 560, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 440, y: 560, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 480, y: 560, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 520, y: 560, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 560, y: 560, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 80, y: 620, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 120, y: 620, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 160, y: 620, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 200, y: 620, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 240, y: 620, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 280, y: 620, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 320, y: 620, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 360, y: 620, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 400, y: 620, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 440, y: 620, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 480, y: 620, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 520, y: 620, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 560, y: 620, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 60, y: 300, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 560, y: 300, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 60, y: 380, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 560, y: 380, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 300, y: 470, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 5.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
        |> std/store:insert(bodies) { x: 300, y: 120, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 3, gx: 0.0, gy: 0.0, damp: 0.0, radius: 20.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0, dead: 0 }
