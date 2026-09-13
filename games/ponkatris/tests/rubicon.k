// rubicon.k — headless check of the real first level: gravity, the
// bouncy X, four solid diamonds, no floor.
//
// 1. spawn: ball at (310,190), gravity on. It falls straight down,
//    through the top diamond at (310,330) — solid collect: bounce +
//    take, score 1/4 — and comes to rest on the X's center circle
//    (~y 358 = center 380 - bumper r 14 - ball r 8).
// 2. no floor AND no kill strip — teleporting below the window drops
//    the marble out of the world ALIVE: dead stays 0, it keeps falling.
// 3. up-Boost: 3000 px/s2 vs gravity 1000 — the marble navigates blind
//    back into view.

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

// 2. out of bounds — alive, still falling, no respawn
sim:teleport(x: 310.0, y: 1500.0)
for(0..120)
! each _ |> sim:tick() |> sim:respawn()
sim:dump()

// 3. Boost climbs it back into the window from deep out
for(0..400)
! each _ |> sim:thrust(left: 0.0, right: 0.0, up: 25.0, down: 0.0) |> sim:tick()

sim:dump()
sim:dump-game()
