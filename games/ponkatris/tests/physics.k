// physics.k — the engine's physics contract, driven through the shipped sim.
// (The engine copy this file used to carry inline moved to sim/index.k; the
// test drives it so the two can never drift.)
//
//   1. settle — drop from spawn, 1200 ticks: rest on the floor, no tunnel
//   2. graze  — sub-threshold contact on the flinger (e=10.5): must NOT
//      launch. Restitution only fires above vn 100 (Box2D's velocity
//      threshold); a walking-pace touch is inelastic.
//   3. slam   — supra-threshold: the flinger must still fling.

import std/io
import std/store
import sim
import level/test

level/test:spawn()

// 1. settle — ball should read y ~= 552 (floor top 560 - radius 8)
for(0..1200)
! each _ |> sim:tick()
sim:dump()

// 2. graze — parked 0.5px above the flinger's crown (bumper at 550,380 r40;
// ball r8 → contact ring at 48px, ball rests at y=332). Falls a hair, vn ~ 32
// < 100 → e collapses to 0: slide off, don't launch. |vy| stays small.
sim:launch(x: 550.0, y: 331.5, vx: 0.0, vy: 0.0)
for(0..120)
! each _ |> sim:tick()
std/store:query(bodies)
! query r when r.kind == 0 |> std/io:print.ln("graze x {{ r.x:f }} y {{ r.y:f }} vx {{ r.vx:f }} vy {{ r.vy:f }}")

// 3. slam — same contact, vn 600 > 100 → full 10.5x fling back upward
sim:launch(x: 550.0, y: 331.5, vx: 0.0, vy: 600.0)
for(0..30)
! each _ |> sim:tick()
std/store:query(bodies)
! query r when r.kind == 0 |> std/io:print.ln("slam  x {{ r.x:f }} y {{ r.y:f }} vx {{ r.vx:f }} vy {{ r.vy:f }}")
