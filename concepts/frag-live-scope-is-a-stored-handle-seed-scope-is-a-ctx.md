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

Hover-candidacy landed the same day and taught the final model in two
corrections. The candidate state has TWO slots: `world.held` — written
only by swatch CLICKS — and `preview.th` — transient, following the
cursor over swatches and falling back to `held` over anything else.
Apply commits `held`, never the transient preview. First correction:
a "mirror" rule reverted preview to the SHELL's theme over non-
actionable pixels — crossing the gap to the apply chip reverted the
candidate and the click committed the shell's own theme, a correct
no-op reading as "click doesn't take." Second correction: making the
hover candidate sticky-with-no-revert let the PATH to apply change
the pick — hovering ember then crossing moss en route committed moss.
Held/transient resolves both: hovering previews honestly (snap A:
preview moss over the moss swatch while `held` stays ember), the
crossing can't steal the pick (snap B: apply committed EMBER), and
leaving the strip falls back to the held candidate, not the shell —
a selection is what a click held, not what the cursor last touched.
Scripted pin walks it: move → click ember → move over moss → move
onto apply → click → `held` printed ember throughout, shell took
ember. The `p.th != s.th` / `!= world.held` guards keep writes once-
per-change, not once-per-pixel — worth remembering wherever a
standing watch or event arm feeds a handle.

Laid out as a row, the model still read wrong in the hand: the
natural path from a swatch to apply CROSSED sibling swatches, so the
preview flickered through themes nobody picked. The swatches now form
a column with apply beside it — the path from pick to commit exits
sideways through no sibling. Layout is part of the gesture contract:
where a commit control sits relative to the candidates determines
whether transient hover is a feature or a theft.

Postscript, ruling on the whole loop: on a desktop the apply chip is
a staged-commit artifact the gesture does not need — hover previews,
click commits directly, and `held` collapses into the shell write.
Apply earns its keep where a tap needs a confirmation boundary
(mobile). Same mechanism either way — `held` is the commit slot; the
only question is whether an arm writes shell from a click or a chip.

Open: per-subtree dirty propagation is possible now that scope
membership is derivable from `eff`/`th` columns — but only pays once a
`! dirty` arm or paused pump exists to spend it.
