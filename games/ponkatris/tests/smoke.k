// smoke.k — headless ponkatris: the shared sim engine, no window.
//
// 1. Settle: 1200 ticks of gravity — the marble must rest on the floor.
// 2. Rules: teleport onto the crystal → collect takes it, score/won flip.
//    Teleport onto the killzone → dead flips, respawn returns it to spawn.

import sim
import level/test

level/test:spawn()

// stopwatch counts up while live: 120 calls x 1/120s = 1.0s elapsed
for(0..120)
! each _ |> sim:stopwatch()

sim:dump-game()

for(0..1200)
! each _ |> sim:tick()

// settle receipt — ball should read y ~= 552 (floor top 560 - radius 8)
sim:dump()
sim:dump-game()

// crystal at (250,500): teleport into it, one tick to mark, collect
sim:teleport(x: 250.0, y: 500.0)
sim:tick()
sim:collect()

// killzone at (680,555): teleport into it, one tick to mark, respawn
sim:teleport(x: 680.0, y: 555.0)
sim:tick()
sim:respawn()

sim:dump()
sim:dump-game()

// stopwatch: counts up while live, frozen once won — the `won` flag is
// already set above, so elapsed must stay pinned at whatever it reached
// before the win. Drive it before the win too: not yet possible here
// (score flips on collect), so just prove the freeze.
for(0..10)
! each _ |> sim:stopwatch()

sim:dump-game()
