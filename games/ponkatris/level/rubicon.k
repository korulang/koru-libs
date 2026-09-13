// rubicon.k — "Crossing the rubicon", 2023-12-04, the first level.
// Data from ponkatris_astro src/content/levels/2023-12-04.md:
//   Player: 0 200
//   Crystal: 150 0 / 0 0 / 0 -150 / -150 0      (four solid diamonds)
//   Wall: 0 -50 500 25 -45 / +45                (the crossed pink bars)
//   KillZone: 0 -700 5000 250                   (oracle death floor — cut:
//   no floor AND no strip; the marble leaves the world alive and can
//   navigate blind back in — Boost 3000 outlifts gravity 1000 + damp)
// No World/Movement lines -> oracle defaults: gravity -1000 (y-up),
// Movement 1000/1000/3000/0 — up-Boost is the lesson of this level.
// Bevy y-up -> screen y-down: sx = x + 310, sy = 390 - y; cross and
// crystals then raised another 60px for window feel.
//
// The narrowphase is AABB/circle only, so each rotated bar is a chain of
// bouncy bumper circles (e=1.0 — the oracle's wall Restitution). SAT for
// rotated boxes is the named gap; the chain is the feel.

import std/store
import sim

pub tor spawn { }

// marble: oracle r 7.5 -> 8, LinearDamping 0.5, gravity 1000 down
spawn = std/store:insert(bodies) { x: 310.0, y: 190.0, vx: 0.0, vy: 0.0, inv_mass: 1.0, kind: 0.0, gx: 0.0, gy: 1000.0, damp: 0.5, radius: 8.0, hw: 0.0, hh: 0.0, e: 0.2, hit: 0.0, dead: 0.0 }
    |> std/store:insert(game) { score: 0.0, total: 4.0, elapsed: 0.0, over: 0.0, won: 0.0, spawn_x: 310.0, spawn_y: 190.0 }
    |> std/store:insert(bodies) { x: 310.0, y: 8.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 302.0, hh: 8.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 8.0, y: 340.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 8.0, hh: 330.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 612.0, y: 340.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 2.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 0.0, hw: 8.0, hh: 330.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 140.3, y: 549.7, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 140.3, y: 210.3, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 161.5, y: 528.5, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 161.5, y: 231.5, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 182.7, y: 507.3, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 182.7, y: 252.7, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 203.9, y: 486.1, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 203.9, y: 273.9, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 225.1, y: 464.9, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 225.1, y: 295.1, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 246.4, y: 443.6, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 246.4, y: 316.4, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 267.6, y: 422.4, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 267.6, y: 337.6, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 288.8, y: 401.2, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 288.8, y: 358.8, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 310.0, y: 380.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 331.2, y: 358.8, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 331.2, y: 401.2, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 352.4, y: 337.6, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 352.4, y: 422.4, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 373.6, y: 316.4, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 373.6, y: 443.6, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 394.9, y: 295.1, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 394.9, y: 464.9, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 416.1, y: 273.9, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 416.1, y: 486.1, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 437.3, y: 252.7, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 437.3, y: 507.3, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 458.5, y: 231.5, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 458.5, y: 528.5, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 479.7, y: 210.3, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> std/store:insert(bodies) { x: 479.7, y: 549.7, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 1.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 14.0, hw: 0.0, hh: 0.0, e: 1.0, hit: 0.0, dead: 0.0 }
    |> spawn-crystals(pressed: true)

// diamonds — re-seeded on restart after sim:reset takes the survivors.
pub tor spawn-crystals { pressed: bool }

spawn-crystals = std/store:query(game)
    ! query g when pressed
        |> std/store:insert(bodies) { x: 460.0, y: 330.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 5.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 12.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0.0, dead: 0.0 }
        |> std/store:insert(bodies) { x: 310.0, y: 330.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 5.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 12.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0.0, dead: 0.0 }
        |> std/store:insert(bodies) { x: 310.0, y: 480.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 5.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 12.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0.0, dead: 0.0 }
        |> std/store:insert(bodies) { x: 160.0, y: 330.0, vx: 0.0, vy: 0.0, inv_mass: 0.0, kind: 5.0, gx: 0.0, gy: 0.0, damp: 0.0, radius: 12.0, hw: 0.0, hh: 0.0, e: 0.0, hit: 0.0, dead: 0.0 }
