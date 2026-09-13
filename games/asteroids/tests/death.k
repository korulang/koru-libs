// death.k — the kill chain, deterministic. `sim:place-ship` drops the ship
// onto a rock (headless runs cannot steer); one tick flags it dead; the
// respawn rule spends a life and revives it ghosting. Three deaths end the
// game; R reseeds everything.
//
//   1. overlap   — ship placed inside a rock's circle -> dead after tick
//   2. respawn   — lives 3->2, ship revived at center with inv=2
//   3. game over — two more deaths -> over=1, ship stays dead
//   4. restart   — reset(pressed) -> lives 3, over 0, 3 fresh rocks

import std/io
import std/store
import sim

std/store:insert(bodies) { x: 400.0, y: 300.0, dx: 0.0, dy: 0.0, kind: 1.0, r: 12.0, t: 0.0, seed: 0, hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0 }
std/store:insert(game) { score: 0.0, lives: 3.0, over: 0.0 }

// one rock parked on the ship's respawn point — every revive lands inside
// it, but inv covers the first 2s so the revived ship survives its tick
std/store:insert(bodies) { x: 300.0, y: 300.0, dx: 0.0, dy: 0.0, kind: 2.0, r: 60.0, t: 0.0, seed: 5, hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0 }

std/io:print.ln("── before")
sim:dump()
sim:dump-game()

// 1. overlap: ship slides onto the rock at (300,300) r=60 — r+r = 72, the
// ship enters at x=380 (dx -40 for one tick: 380.67, still inside)
sim:place-ship(x: 350.0, y: 300.0, dx: 0.0, dy: 0.0)
sim:tick()
std/io:print.ln("── after tick (ship should be dead)")
sim:dump()

// 2. respawn: spends a life, revives at center ghosting
sim:respawn-ship()
std/io:print.ln("── after respawn (lives 2, ship alive at 400,300 inv 2)")
sim:dump()
sim:dump-game()

// 3. two more deaths -> game over; the last ship stays dead
sim:place-ship(x: 350.0, y: 300.0, dx: 0.0, dy: 0.0)
sim:tick()
sim:respawn-ship()
sim:place-ship(x: 350.0, y: 300.0, dx: 0.0, dy: 0.0)
sim:tick()
sim:respawn-ship()
std/io:print.ln("── after three deaths (over 1, ship dead)")
sim:dump()
sim:dump-game()

// 4. restart: field cleared, lives refilled, three fresh rocks seeded
sim:reset(pressed: true)
std/io:print.ln("── after reset (over 0, lives 3, ship + 3 rocks)")
sim:dump()
sim:dump-game()
