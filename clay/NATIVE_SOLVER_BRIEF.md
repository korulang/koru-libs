# Native layout solver — fusion brief

```
kind: commissioned design-attack + build session
status: draft — 2026-10-20
trees: koru-libs 4e2f332 (main), koru 4c2f38b30 (main), nanoui ede1eb4 (clone)
```

> **To the session reading this brief**: the numbers below were measured,
> not quoted — every table entry has a reproduction path. Your job is to
> attack the bet in §5 before building it: find the trap the brief missed,
> or strengthen the design until it survives you. Do not ship a solver that
> wins on a workload the gate cannot falsify — an ungated number is worse
> than no number (see §7, the contract).

## 1. The question

koru-libs renders UI through vendored Clay v0.14 (`clay.h`, 5,058 lines,
652 internals) for layout. Nanoui — the Zig framework metal/index.kz
already ports glyphs/atlas/instancing from — solves the same workload
with a purpose-built 318-line flexbox (`src/ui/layout.zig`) and wins the
layout phase ~3.9×.

**Should the dialect get a narrow native solver** — and if so, does the
combination (retained spec rows + small solver + dirty gating) let us
*beat* nanoui's frame number rather than trail it?

## 2. Measured state (receipts, not claims)

Machine: M2 Pro, zig 0.17.0, both sides ReleaseFast, hillclimb protocol
(30 warmup + 300 measured × 3 reps, lowest median retained, ±5% = noise).

| | nanoui | koru | upstream Clay |
|---|---|---|---|
| view build | 0.035 ms | ~0 (retained spec) | n/a |
| layout solve | 0.015 | 0.058 (Clay) | 0.058 |
| paint / emit+drain | 0.017 | ~0.031 | n/a |
| **frame CPU** | **0.067** | **0.089** | **0.058** |
| encode CPU | 0.014 | — (unmeasured) | — |
| GPU | 0.612 | — (no offscreen surface yet) | — |

Scene: `boxes` — 600 rounded+shadowed boxes, 20×30 grid, sine-offset +
HSL colors at frame 100/120. 1201 painted instances.

**Correctness gate ran first** (`clay/tests/bench_boxes_gate.k` +
`bench_boxes_cmp.py`): a patched hillclimb `dump` exe prints nanoui's
painted instance stream; the Koru candidate reproduces it 1201/1201 with
0 divergences at 0.005pt/0.002 tolerances. Mutation-tested: a gr/gc-swapped
seed fails with 2247 divergences + 200 orphans. The gate can say no.

Finding that reframes the problem: **the dialect layer is already ahead.**
Nanoui pays 0.035ms building its ephemeral view tree; our retained spec
costs ~0 there and our walk+drain is ~0.031 vs their 0.052 build+paint.
The *entire* deficit is Clay's solve.

## 3. Architecture as it stands

```
spec store (retained rows, stable handles, [tree] parent stamps)
  → expansion pass (queries spec, emits element decls each frame)
  → Clay: BeginLayout → open/cfg/close × N → EndLayout → render commands
  → CmdView drain (kind, x/y/w/h, rgba, img, ud=eid, tx, fs)
  → metal/index.kz draw ops → instance stream → GPU
```

Per frame today: everything runs, unconditionally, ~60fps polling pump
(`frames|zig` in metal/index.kz: pump events → dispatch → `! frame` →
sleep 16ms). Nothing is skipped; nothing is cached across frames except
metal's glyph/text caches.

Nanoui is the inverse: ephemeral per-frame box tree, retained caches
below it, and **a paused CADisplayLink at idle** (their measured idle
CPU: 0.00%; ours polls).

## 4. The dialect census — the Clay surface actually reachable

Everything our bindings can spell (`clay/index.kz` el.cfg/el.img/el.clip,
`ui/index.kz` panel/panelx/text/imgpanel):

| Clay feature | status |
|---|---|
| sizing: fit / grow / percent / fixed, per axis | **reachable** |
| padding | uniform only (`pad` → all 4 sides) |
| childGap, childAlignment x/y, direction LTR/TTB | **reachable** |
| backgroundColor | **reachable** |
| floating | narrow: offset + ATTACH_TO_ROOT + LEFT_TOP/LEFT_TOP only |
| image (imageData → IMAGE command) | **reachable** |
| clip (horiz/vert + childOffset — scroll) | **reachable** |
| text (CLAY_TEXT: color, fontSize, userData) | **reachable** — default wrap, no config exposed |
| userData (eid → CmdView.ud — hit-testing depends on it) | **reachable, load-bearing** |
| borders, aspectRatio, per-side padding, zIndex, attach matrix, expand offsets, pointer capture, element ids, multi-font, wrap config, debug | **unreachable** |
| corner radius | **not a Clay concept** — lives paint-side in metal's instance format |

The reachable set is close to nanoui's 318-line vocabulary plus
percent-sizing, alignment, and the text measure callback.

## 5. The bet (attack this)

A narrow solver covering §4's reachable surface, ~318-line-class,
emitting the same CmdView contract, with two possible wins:

1. **Constant factor** — no generality tax. Straight win vs 0.058 if
   the solver is honestly narrower.
2. **Incrementality Clay structurally cannot offer** — Clay has no
   partial-solve API; retained spec + stable row identity + `[tree]`
   parent chains means dirty-subtree re-solve is expressible. This is
   the win beyond nanoui (which also re-solves globally) — but see trap 6.

Known traps, ranked:

1. **Grow/fit semantics are subtle.** Fit-then-grow with per-sibling grow
   distribution, alignment, percent-of-parent, minMax — 95%-correct ships
   a subtly wrong solver. Defense exists: gate vs Clay's CmdView stream
   on identical trees (a *second* oracle, same repo, no cloning) AND vs
   nanoui's instance dump.
2. **Text is the hard case.** The measure bridge (`koru_clay_measure`,
   CoreText, installed as Clay's MeasureTextFunction) must be called by
   the native solver or text sizes diverge. Wrapping is reachable-by-
   default (ui:text exposes no wrap config) — whether any spec actually
   wraps is **unmeasured**; census it first. If nothing wraps, a solver
   may still handle wrapped text by refusing or falling back (see trap 3).
3. **The hybrid boundary.** Per-scene routing (whole tree native iff
   every element in vocabulary, else whole tree Clay) is honest and
   simple. Subtree-level routing embeds a foreign-solved subtree inside a
   global fit/grow pass — sizing feedback makes it a real problem, not a
   seam. Do not pick the subtree hybrid without solving the feedback.
4. **CmdView is a contract.** Command order, `ud` (eid) stamps, SCISSOR
   pairs around clip children, TEXT command fields — consumers
   (hit-testing, metal drain) depend on all of it. The solver must emit
   the stream, not a lookalike.
5. **Where it runs.** `~proc |zig` host code inside `clay/index.kz` —
   same surface as el.cfg, compiled with the exe, fastest honest path.
   A surface-`.kz` solver is better dogfood but its perf on the row-walk
   + math is unmeasured. Decide deliberately; "Koru-native" that loses
   the race it was built to win is a contradiction.
6. **Incremental relayout validity.** A dirty child's grow/percent can
   resize siblings and bubble up through ancestors' fit pass. Subtree
   re-solve is only sound under a real invalidation rule (probably:
   dirty bubbles to nearest sizing-independent ancestor). Nanoui doesn't
   attempt it; if we do, the invalidation rule IS the contribution —
   gate it as hard as the solver itself.

## 6. Orthogonal steals (smaller, separable, still worth it)

- **Hillclimb protocol → koru-side harness.** `std/benchmarking:run`
  currently runs-for-duration. Port: warmup + measured × reps + lowest
  median + ±5% noise + `--label` + append-only `bench/history.jsonl`.
  Makes every future number protocol-comparable to nanoui's published
  table and turns regression into a ledger diff.
- **Paused pump** — store-watch → dirty flag → skip expansion/solve/drain
  when clean; nanoui pauses the display link itself. Idle Clay cost
  0.058 → 0 beats any solver constant-factor. Watch out: hover writes
  every mouse-move (dirty under interaction is correct); `stored` writes
  inside `! frame` mean write→fire recursion — flag-and-drain, not
  recursive fire.
- **Scene catalog** — boxes done; text (300 changing labels — exercises
  measure bridge), scroll (1000 rows + clip), dashboard, list
  (virtualized 100k) remain. Each port = upstream dump mode + comparator
  + Koru scene, gate first.

## 7. The contract (non-negotiable)

- **Gate before numbers.** Any solver races only workloads whose
  instance/cmd streams were verified identical first. A solver that
  can't be gated identical doesn't get measured.
- **Two oracles, both live.** Clay's CmdView stream (same repo, cheap)
  and nanoui's painted instances (clone + dump patch, authoritative).
- **Mutation-test the gate.** The boxes gate proved it rejects a
  known-wrong candidate (gr/gc swap → 2247 divergences). Every new gate
  needs its own known-wrong.
- **Estimator: lowest median, never means.** Same rule as upstream.
- **Report asymmetry is disqualifying.** Behind says "behind" first.
- **Regression-pin everything** — the dialect has snap/pixel oracles
  (`spec_snap.k`, `spec_tree.k` byte-identical BMPs); a solver swap must
  leave them byte-identical.
- **No perf claim leaves the session without its workload + gate named.**

## 8. File map

| path | role |
|---|---|
| `clay/index.kz` | bindings: init/layout/el.cfg/el.img/el.clip/measure.text/each/cmd.count; `~proc |zig` host procs compile with the exe (`exe.addCSourceFile` → same opt level) |
| `clay/clay.h`, `clay_impl.c` | vendored Clay v0.14 + CoreText measure bridge (`koru_clay_measure`) |
| `ui/index.kz` | dialect layer: panel/panelx/text/imgpanel — dock coercions, eid→userData |
| `clay/tests/bench_boxes.k` | measured candidate (benchmarking:run wrapper) |
| `clay/tests/bench_boxes_gate.k` | gate candidate — prints instance stream |
| `clay/tests/bench_boxes_cmp.py` | comparator, 0.005pt/0.002 tolerances |
| `clay/tests/spec_snap.k`, `spec_tree.k` | pixel oracles (byte-identical BMP requirement) |
| `metal/index.kz` | draw ops, instance format (kind 0 quad/1 text/2 shadow/3 image), `frames|zig` pump |
| nanoui clone `/tmp/nanoui-check` | `hillclimb/` harness (may need re-clone — /tmp is scratch); `src/ui/layout.zig` = the 318-line reference |

Repro: `cd /tmp/nanoui-check/hillclimb && zig build run -- --scene boxes
--only nanoui` (baseline), `dump` exe for the reference stream — the
gate file's header documents the full path including the patch.

## 9. Open questions the session must resolve

1. Whole-tree native-with-vocabulary-check vs subtree hybrid — and if
   hybrid, the sizing-feedback story.
2. Text: does anything in the corpus actually wrap? If yes, does the
   solver own wrapping or route those subtrees to Clay?
3. Where the solver runs (`|zig` host vs surface .kz) — decide with a
   measurement, not a preference.
4. The incremental invalidation rule, if incremental is attempted at
   all — including the proof obligation that a skipped re-solve cannot
   change output.
5. Whether `el.clip`'s childOffset semantics and floating's root-offset
   are cheap in the native solver or whether they force a second pass.
6. What the history ledger's schema is (scene/commit/machine/protocol
   version) so runs stay comparable as the machine changes.
