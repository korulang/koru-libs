---
type: belief
id: frag-automation-verbs-are-first-class-surface
provenance: koru-libs/metal automation verbs (input.key, input.mouse, window.snap) — Lars ruled the naming question 2026-10-18: real features for agent automation, not test.* scaffolding
ts: 2026-10-18
---

# Automation verbs are first-class surface

Ruled 2026-10-18, Lars: synthesized input and framebuffer capture are
**real package features, not test scaffolding** — the question was
`test.*` vs real verbs and the ruling is real verbs, because an agent
driving a shared workspace is the product vision (OMNI S3), not a test
hack.

## The spellings

- `input.key(code: i64)` — synthesize a key-down; pushes `KeyData` into
  the event mailbox.
- `input.mouse(x: f64, y: f64)` — synthesize a mouse-down.
- `window.snap(path: string)` — request a framebuffer capture; the
  `frames` loop services it after `presentDrawable`+`commit`, blit-copying
  the drawable into a shared MTLBuffer and writing a 32-bit BMP.

## Why the seam matters more than the name

Automation rides the SAME seams a user does — `input.*` pushes into the
mailbox the ObjC IMPs write (not directly into arm calls), and
`window.snap` reads the presented drawable (not a side framebuffer).
What automation sees and does is what a hand sees and does; an
off-seam shortcut would make scenarios prove a pipeline users never take.

## Consequence

Headless scenario tests are just `.k` programs: inject at frame N,
capture at M, quit at K — compile, behavior, and pixels all verifiable
by an agent without human hands. Drawable textures are
`storageModePrivate`, so readback goes through a blit copy + sync, never
`getBytes` on the drawable.
