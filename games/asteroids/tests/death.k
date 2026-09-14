// death.k — the kill chain, deterministic. `sim:place-ship` drops the ship
// onto a rock (headless runs cannot steer); one tick flags it dead; the
// respawn rule spends a life and arms the 1.5s delay; the clock runs out
// and the ship reappears ghosting. Three deaths end the game; Enter at
// game over reseeds everything through the wave machinery.
//
//   1. overlap   — ship placed inside a rock's circle -> dead after tick
//   2. respawn   — lives 3->2 and rt 1.5 armed; clock-out -> revived inv 2
//   3. game over — two more deaths -> over=1, ship stays dead
//   4. restart   — reset(pressed) -> wave 1 dealt by wave-check+spawn-tick

import std/io
import std/store
import sim

std/store:insert(bodies) { x: 400.0, y: 300.0, dx: 0.0, dy: 0.0, kind: 1.0, r: 12.0, t: 0.0, seed: 0, hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0 }
std/store:insert(game) { score: 0.0, lives: 3.0, over: 0.0, wave: 1.0, rocks: 1.0, pending: 0.0, rt: 0.0, seed: 7.0 }

// one rock parked near the ship's respawn point — the census counts it so
// the wave machinery stays quiet through the whole test
std/store:insert(bodies) { x: 300.0, y: 300.0, dx: 0.0, dy: 0.0, kind: 2.0, r: 60.0, t: 0.0, seed: 5, hit: 0.0, dead: 0.0, rot: 0.0, inv: 0.0, cd: 0.0 }

std/io:print.ln("── before")
sim:dump()
sim:dump-game()

// 1. overlap: ship slides onto the rock at (300,300) r=60 — r+r = 72, the
// ship enters at x=350, well inside
sim:place-ship(x: 350.0, y: 300.0, dx: 0.0, dy: 0.0)
sim:tick()
std/io:print.ln("── after tick (ship should be dead)")
sim:dump()

// 2. respawn: spends a life and arms the delay — the ship stays dead until
// the clock runs out. Headless has no frames to wait through, so the test
// winds the clock forward; one respawn-tick drains the sliver and revives.
sim:respawn-ship()
std/io:print.ln("── after respawn-ship (lives 2, rt 1.5, ship still dead)")
sim:dump()
sim:dump-game()

std/store:query(game)
    ! query g |> std/store:stored { g.rt: 0.01 }
sim:respawn-tick()
sim:maybe-revive()
std/io:print.ln("── after clock-out (ship alive at 400,300 inv 2)")
sim:dump()

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

// 4. restart: reset fires only at game over; the field is wiped and the
// wave machinery deals wave 1 — same code path as the live game
sim:reset(pressed: true)
std/io:print.ln("── after reset (over 0, lives 3, field empty)")
sim:dump()
sim:dump-game()
sim:wave-check()
sim:spawn-tick()
sim:spawn-tick()
sim:spawn-tick()
sim:spawn-tick()
std/io:print.ln("── after wave 1 dealt (ship + 4 rim rocks)")
sim:dump()
sim:dump-game()
