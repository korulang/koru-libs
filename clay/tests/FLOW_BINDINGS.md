# Flow binding & arm-scoping friction found during the image spike

Surfaced wiring `libs/metal:image.load` into `spec_sel_live.k` (2026-10-18,
koru-libs working tree). Several of these are probably compiler bugs; each
section has the failing shape and the shape that worked. Pin candidates live
best in `~/src/koru/tests/regression/` — the shapes below should minimize
cleanly.

## 1. Arm syntax needs an explicit binding name — `| img` ≠ `| img img`

`| arm` alone binds the arm's payload under a **generated** name
(`result_..._img`), not under the arm name. The payload is unreachable:

```koru
| then |> libs/metal:image.load(win: w, path: "test.png")
    | img |> stored { world.tex: img.tex }   # emitted: img never declared
```

emits `const result_Handlers_..._img = result....img;` and the body's `img`
reference hits `use of undeclared identifier 'img'`. Working spelling —
arm name then binding name, same as `| win w`, `| row h24`:

```koru
    | img img |> stored { ... img.tex ... }
```

(`| drained` in `clay:each` works bare only because nothing uses the binding.)

## 2. A multi-arm tor mid-chain makes its arms wrap the whole remainder

Arms attach positionally to the tor they textually follow. There is no
"handle this arm and continue the chain" spelling:

```koru
| win w |> clear.color(...)
        |> image.load(win: w, path)     # returns | img | err
        |> frames(win: w)
    | img img |> ...                    # img arm
    | err e |> ...                      # err arm
    ! frame f                           # ERROR: attributed to image:load
```

Every arrangement was refused:
- arms after `|> frames` → `KORU021: tor 'frames' has no branch 'err'`
- arms between `image.load` and `|> frames` → `! frame`, `! key-down`,
  `| done` all error as `KORU021: tor 'image:load' has no branch 'frame'` —
  the arms consume the rest of the flow as their continuations.

The only working shape is `| img img |> <entire remainder of the program>` —
i.e. a multi-arm tor mid-chain forces nesting the rest of the flow one
level deeper. For `image.load` that meant reindenting ~200 lines of frame
arms, so the tor became `-> i64` with `@panic` on failure instead
(fail-loud, no degraded path — fits the no-fallbacks rule for a spike).

**Ruled 2026-10-18 — landed in koru `092264fb2`:** an unnamed `|>` at a
step's own level, after that step's arms, is the step's JOIN for every tor
(previously only keyword tors `if`/`for`). Both arms fall into it; arm
bindings stay arm-local, so a value an arm produces reaches the remainder
through the store:

```koru
| win w |> clear.color(...)
        |> image.load(win: w, path)
            | img i |> stored { world.tex: i.tex }
            | err e |> ...
        |> frames(win: w)
            ! frame f |> ...
```

Pins: koru `400_210` / `400_211` / `400_212`. Referencing an arm binding at
the join is refused today only by the host (`use of undeclared identifier`);
a koruc-level unbound-reference check is the open follow-up.

**The spike can't adopt it yet — blocked on §3.** The join route means the
texture reaches `! frame` via the store instead of the `texh` capture, and
dropping that capture is exactly what trips §3: measured 2026-10-18 by
moving `texh` into `stored { world.tex: texh }` before `frames` and removing
it from the `! frame` store write — `KORU030: binding 'w' was already
discharged` at `window.size(win: w)`. `image.load` stays `-> i64` + `@panic`
until 330_145 is fixed.

## 3. KORU030 phantom: ambient `w` inside `! frame` — non-compositional verdict

The rule as bisected (2026-10-19, against the real consumer):

- `w` inside `! frame` compiles **only when a `w`-derived binding is also
  captured into that arm** — `texh` from `image.load(win: w)` used inside
  `! frame` is the license. Remove that capture (`image.load: _`, or use
  `texh` before `frames` instead) and `window.size(win: w)` in the same arm
  gets `KORU030: binding 'w' was already discharged`.
- Capturing an *unrelated* ambient binding does not license it —
  `libs/clay:dims(cl: h)` inside `! frame` still leaves `w` refused.
- In a minimal pure-`.kz` repro (single-file tors, no library imports),
  `w` inside the event arm is refused **unconditionally** — even with a
  `w`-derived value captured alongside. So the app's "works when a derived
  binding is captured" path is a side door, not the rule.

Either `w` in event arms is legal (this minimal repro is over-strict) or it
isn't (the app's derived-capture path is under-strict). The verdict must be
compositional — today it depends on which other bindings are captured.

Pinned in the suite:
`tests/regression/300_ADVANCED_FEATURES/330_PHANTOM_TYPES/330_145_event_arm_capture_of_discharged_borrow/`
(BROKEN — reproduces exactly `KORU030`; ~45 lines, no library deps).

Related: `w` inside a `| then` body in `! frame` also gets KORU030
(`|> if (world.frame == 1) | then |> image.load(win: w)`), while bare
`window.size(win: w)` in the same frame body compiles — arm bodies appear
to resolve `w` to the discharged outer binding rather than the frame
capture. Same family, possibly same fix.

## 4. Emitter: `| row`-bound insert before another `| row` line → `else {}` with no `if`

In a `[tree]` store seed chain, inserting a `| row X |> insert(...)` line
immediately before `| row h24 |> stored {...}` produced:

```zig
switch (result_..._25) {
    .row => |himg| {
        else { _ = __store_write_spec_event.handler(...); }
        else { const r26 = __store_write_spec_event.handler(...); ...
```

`expected statement, found 'else'` at zig build. The arm body emitted every
chain statement as an `else {}` branch with no leading `if`.

**Stable repro:** `clay/tests/repro_else_orphan.k` — a copy of
`spec_sel_live.k` with the img row moved mid-chain so its `| row` arm is
bound (`| row h24 |> insert(img)` then `| row himg |> stored-chain`).
Fails deterministically at `output_emitted.zig` ~line 3183,
`.row => |himg| { else { ... }`.

**Minimization status (2026-10-19):** the bug resisted every flat repro —
25-deep nested `| row` binds, `if | then` wrappers, `! query` event-arm
context, and `[tree]` stores all compile cleanly without the orphan.
Whatever the trigger is lives in the surrounding `! frame`/`| win w`/
`| cl h` arm stack or the combination thereof. The package-level repro is
the pin for now; a suite-worthy minimization is follow-up work.

**Also observed while repro-ing:** two `.k`/`.kz` files with the same stem
in one directory (`repro_else.k` + `repro_else.kz`) clobber each other's
emitted artifacts — a build produced `output_emitted.zig` containing the
*sibling file's* program. Worth a toolchain look (cache keyed on stem).

## 5. Resolved this session: hit-test ordinals vs command indices

Not a compiler issue — a real consumer bug the image surfaced. Hit rows
keyed on the *running command index* (`world.cmdi`), but spec rows whose
kind emits no render command (`col`, `row` — 5 of them) shift every later
command's index off its spec ordinal. Clicking the image (command 20)
selected spec ordinal 20 — a cell, hence the purple palette. Now stamped:
`ui:panelx`/`ui:imgpanel` take `eid: o + 1` into `decl.userData`, which
survives into `Clay_RenderCommand.userData` → `CmdView.ud`, so hit rows
record the true spec ordinal regardless of emission order or culling.
Chrome (untagged, `ud == 0`) still resolves as `tool 1`.
