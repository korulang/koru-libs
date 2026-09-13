// pacman.k — headless check of the real level: the oracle's maze, zero-g.
//
// 1. spawn: 49 walls + 249 crystals + ball + game row land in the stores.
// 2. zero-g: 600 ticks with no input — the ball must not drift.
// 3. thrust: 240 ticks of right-thrust (Movement 1000 x DT) — the ball
//    leaves the central cross and wall-stops against the east face (x~393:
//    wall face 405 minus r 12).
// 4. collect: teleport onto a corridor dot (450,380) → +1; onto the big
//    stacked LastCrystal (300,320, r=45, emitted twice by the oracle data)
//    → +2. Total score 3/249.

import std/io
import std/store
import sim
import level/pacman

level/pacman:spawn()

// 2. zero-g drift check: the marble sits at spawn (300,380)
for(0..600)
! each _ |> sim:tick()

sim:dump()

// 3. right-thrust run: east corridor of the cross is clear of dots
for(0..240)
! each _ |> sim:thrust(left: 0.0, right: 8.3333, up: 0.0, down: 0.0) |> sim:tick() |> sim:collect()

// 4. corridor dot, then the big stacked final crystal
sim:teleport(x: 450.0, y: 380.0)
sim:tick()
sim:collect()
sim:teleport(x: 300.0, y: 320.0)
sim:tick()
sim:collect()

sim:dump()
sim:dump-game()
