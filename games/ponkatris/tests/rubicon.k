// rubicon.k — headless check of the real first level: gravity, the
// bouncy X, four solid diamonds.
//
// 1. spawn: ball at (310,190), gravity on. It falls straight down,
//    through the top diamond at (310,330) — solid collect: bounce +
//    take, score 1/4 — and comes to rest on the X's center circle
//    (~y 358 = center 380 - bumper r 14 - ball r 8).
// 2. no floor — teleporting below the window drops the marble onto the
//    off-screen kill strip at y 720: dead, then respawned to spawn.
// 3. up-Boost: 3000 px/s2 vs gravity 1000 — the ball climbs.

import std/io
import std/store
import sim
import level/rubicon

level/rubicon:spawn()

// 1. the drop: 600 ticks — collect the top diamond mid-fall, land on the X
for(0..600)
! each _ |> sim:tick() |> sim:collect()

sim:dump()
sim:dump-game()

// 2. no floor — drop out of the window, die on the strip, respawn
sim:teleport(x: 310.0, y: 690.0)
for(0..240)
! each _ |> sim:tick() |> sim:respawn()
sim:dump()
sim:dump-game()

// 3. Boost: 240 ticks of up-thrust should lift the marble off the X
for(0..240)
! each _ |> sim:thrust(left: 0.0, right: 0.0, up: 25.0, down: 0.0) |> sim:tick()

sim:dump()
sim:dump-game()
