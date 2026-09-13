// cross.k — headless check of the crossed-bars level.
//
// 1. spawn: 4 border walls + 8 kill-bar segments + 66 crystals + ball.
// 2. zero-g: 600 ticks idle — the ball must not drift off spawn (300,600).
// 3. kill bar: teleport onto the horizontal bar (300,340) → dead →
//    respawn returns to (300,600).
// 4. collect: teleport onto the big crystal (300,120, r=20) → score.

import std/io
import std/store
import sim
import level/cross

level/cross:spawn()

for(0..600)
! each _ |> sim:tick()

sim:dump()

// onto the horizontal kill bar — dump BEFORE respawn so dead is visible
// (the next tick clears hit/dead markers)
sim:teleport(x: 300.0, y: 340.0)
sim:tick()
sim:dump()

sim:respawn()
sim:dump()

// onto the big crystal
sim:teleport(x: 300.0, y: 120.0)
sim:tick()
sim:collect()

sim:dump-game()
