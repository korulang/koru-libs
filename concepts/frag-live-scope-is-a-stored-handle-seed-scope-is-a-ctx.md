---
type: belief
id: frag-live-scope-is-a-stored-handle-seed-scope-is-a-ctx
provenance: clay/tests/theme_preview.k, 2026-10 — scripted input.mouse clicks, two window.snap BMPs, printed handle log
ts: 2026-10-20
---

# Live scope is a stored handle; seed scope is a ctx (belief)

Ambient injection and live re-scoping are two different mechanisms, and
the demo that proves it is a theme picker. `std/ctx(row)` injects row
fields into a component's declared props at the call site — ambient,
seed-time, one shot (probe_ctx_comp). A scope root's `th` column holds
a themes-row *handle*; every descendant resolves `eff` per frame — own
`th` if nonzero, else `parent.eff`, else the world default. Because
`eff` is derived, not seeded, a single `stored` write to a scope root's
`th` re-themes its whole subtree next frame. The store write IS the
repaint trigger; no dirty flag was needed for this to move pixels.

A commit point is then just a handle copy: `spec[shroot].th :=
spec[pvroot].th`. The preview subtree diverged on the swatch click
(printed: scope 2 th 33554432 → 33554433 while scope 1 held 33554432,
and snap A shows the preview card in ember with the shell still slate);
the shell only moved when apply copied the handle (snap B: shell in
ember). Two `ctx(themes[t0])` scopes seeded both subtrees identically —
`th` was never spelled at the call site: each theme row stamps its own
handle into a `self` column and ctx injects `self:` ambiently.

Honest edges, all observed not guessed: ctx stays seed-time — the fs
that arrived ambiently does NOT follow live theme swaps (colors move,
font stays; visible in the demo, not a bug). `eff`'s doc-order sweep
depends on parents preceding children in insertion order — true for
markup-emitted seeds; a row reordered post-seed would read a stale
parent.eff for one frame. And handle-sharing means apply does not fork
the theme — shell and preview point at the same themes row after
commit, which is the desired semantics for "preview becomes live."

Hover-candidacy landed the same day and was one arm: `! mouse-move`
queries the hit map, and when the hovered row's `act` is 1 writes the
preview scope's `th` to the swatch's own theme handle — same stored-
write trigger, no new machinery. The candidate is STICKY: leaving the
swatch keeps it. An earlier "mirror" rule reverted preview to the
shell's theme whenever the cursor held nothing actionable — it looked
consistent on paper and broke apply in the hand: the pixels between
the swatch and the apply chip are nothing actionable, so crossing to
the commit button reverted the candidate and apply then committed the
shell's own theme — a correct no-op that read as "click doesn't take."
Selection that a commit gesture can reach must survive the path to the
commit button. Scripted pin covers all three transitions: `input.move`
over swatch 1 re-themed the preview with zero clicks, a move to empty
space left it holding, and the apply click committed the last-hovered
theme. The `p.th != s.th` guard on each write keeps it once-per-
change rather than once-per-pixel — worth remembering wherever a
standing watch or event arm feeds a handle.

Open: per-subtree dirty propagation is possible now that scope
membership is derivable from `eff`/`th` columns — but only pays once a
`! dirty` arm or paused pump exists to spend it.
