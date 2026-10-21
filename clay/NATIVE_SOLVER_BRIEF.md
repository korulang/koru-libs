# Native layout solver — fusion brief

```
kind: commissioned design-attack + build session
status: draft — 2026-10-20

progress 2026-10-20 — the differential gate exists and the candidate passes
it: `clay/tests/fuzz_gate.k` + `fuzz_cmp.py`, CAND==REF over 400 commands,
known-wrong MUT arm rejected with 1420 divergences. Candidate is
`nativelayout/index.kz` (flat arrays, no ID hashing; fit → grow →
align/position port; same CmdView stream). Along the way the gate caught a
real UB in the dialect: `sizing()` built `.percent = f` union inits, leaving
`size.minMax.max` as stack garbage that Clay's propagate pass reads as a
clamp bound — percent elements contributed garbage-clamped content heights
to FIT parents. Both bindings now fully initialize the union
(`minMax = {f, 0}` — percent still reads f at offset 0; CloseElement's
max<=0→MAXFLOAT reset now always fires, deterministically un-capped).

decision 2026-10-20 — STAY ON CLAY as the dialect's solver. nl covers ~2/3
of Clay's capability surface (capability map below); switching now would be
premature optimization on a 48h-old subset. Clay remains oracle + default;
nl remains a gate-verified candidate that grows feature-by-feature: each new
dialect capability lands as binding words + nl port + generator rows + gate
proof on both. nl is faster where measured (decl ~1.35×, solve ~1.3×
ReleaseFast) — a noted property, not the reason to switch.

capability map (Clay surface vs nl): PARITY — fit/grow/pct/fix minMax
semantics, uniform pad, gap, ax/ay, ltr/ttb, ROOT+LEFT_TOP floats, clip +
childOffset, image, text (WORDS wrap, fontSize, color), ud, offscreen cull.
ABSENT, additive ports — per-side padding, cornerRadius, overlayColor,
borders (+betweenChildren), CUSTOM commands, aspectRatio, letterSpacing/
lineHeight/fontId, wrap NEWLINES/NONE, textAlignment, attachPoints 9×9,
attachTo PARENT/clipTo, expand, zIndex, pct>1 diagnostic. ABSENT, structural
— element IDs + hover machinery (ud-stamp is our hit-test model instead),
ATTACH_TO_ELEMENT_WITH_ID (wants spec-row refs, not hashes), internal scroll
state (frame-pure by design — childOffset is app-owned), transitions
(cross-frame identity — belongs spec-side if ever wanted).

landmine found 2026-10-20 — nl first lived as `~part native` of libs/clay.
~parts elaborate EAGERLY into every consumer: gallery_comp (never touches
nl.*) blew the 6144MB compile-mem budget with the marker, compiled fine
without it; backend emitted bytes identical → pure frontend dead weight.
Moved nl to its own package `libs/nativelayout` — clay consumers pay zero;
the gate and bench import it directly. fuzz_gate + gallery_comp + smoke +
spec_snap + bench_solvers all re-verified post-move (gate still
CAND==REF 400 cmds; gallery snaps bit-identical).

race 2026-10-20 — `clay/tests/bench_solvers.k`: one climb pass runs BOTH
pipelines per frame (per-frame interleave, 6 laps), same 600-leaf tree.

CORRECTED after a dead measurement basis: the Debug build's ratios
(~3.6× declare, ~4.9× solve) were a codegen artifact — -O0 punishes
Clay's C implementation far harder than nl's lean Zig. ReleaseFast is
the honest basis (and matches every earlier calm absolute). ReleaseFast,
same binary, same frames:

| lap | clay | nl | ratio |
|---|---|---|---|
| declare | 0.062–0.064 | 0.046–0.047 | ~1.35× |
| solve | 0.034 | 0.024–0.027 | ~1.3× |
| drain | ~0 | ~0 | — |

Same-moment nanoui (hillclimb, boxes): build 0.035 + layout 0.014 =
0.049. nl decl+solve ~0.070 — still ~1.4× behind nanoui's build+layout,
not ahead. nl vs clay is a real ~1.35× on declare+solve combined.
Caveats: lap 1 pays ui's word-mapping lap 4 skips (slight nl favor);
nl solve includes Clay-compatible float/wrap bookkeeping nanoui may not
pay. Machine was under memory pressure during measurement (17G wired,
swap active) — absolutes on a calm box may differ; ratios in-binary hold.
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
with a purpose-built 318-line flexbox (`src/ui/layout.zig`). Its solve
(0.015) is ~2.2× faster than Clay's EndLayout (0.033), and its
build+layout (0.050) is 1.74× faster than our expand+declare+solve
(0.087). See §2.

**Should the dialect get a narrow native solver** — and if so, does the
combination (retained spec rows + small solver + dirty gating) let us
*beat* nanoui's frame number rather than trail it?

## 2. Measured state (receipts, not claims)

Re-measured 2026-10-20. The first draft of this table was wrong: it put
Clay's whole frame (declare + solve + commands, per hillclimb's own
`clay.zig` header) in the "layout solve" row against nanoui's solve-only
0.015, derived the Koru split by subtraction (0.089 − 0.058), and the
0.089 itself was a mean (`benchmarking:run` = seconds/passes).

Machine: M2 Pro, both sides ReleaseFast, load avg 3.5–9 across the runs.
Protocol on both sides: 30 warmup + 300 measured × 3 reps, lowest median
retained. Koru side: `std/benchmarking:climb` + `lap` (koru main
1dbc71cf3), ranges over 5 interleaved rounds.

| | nanoui | koru (`bench_boxes_split1.k`) | koru with paint (`bench_boxes_paint.k`) | upstream Clay (`/tmp/clay-split/split.c`) |
|---|---|---|---|---|
| build / expand (spec query + HSL) | 0.035 ms | ~0.020 (inferred: lap 1 0.052–0.056 minus declare) | (in lap 1: 0.059–0.060) | n/a |
| declare (tree into Clay) | (in build) | 0.033–0.036 (declare-only arm, in `bench_boxes_split.k`) | ↑ | 0.0335 |
| layout solve (EndLayout incl. commands) | 0.014–0.015 | 0.032–0.035 | 0.032–0.033 | 0.0331–0.0335 |
| paint | 0.016 | **0** (no paint work) | 0.0154–0.0163 (draw.* → instPush, incl. pass/encoder setup) | 0.002 (cmd read) |
| encode CPU (upload + encode + commit) | 0.012–0.014 | — | 0.0056–0.0062 with the instance ring (was 0.0230–0.0249 with a buffer per flush); instFlush + endEncoding + commit | — |
| **CPU total** | **0.077–0.081** (frame + encode) | 0.084–0.091 (no paint, no encode) | **0.107–0.109** (sum of phase medians; 0.112–0.114 before the single walk, 0.131–0.134 before the ring) | 0.069–0.070 |
| GPU (GPUEnd − GPUStart, same method) | median 0.423–0.424; **min 0.4178–0.4195** | — | **min 0.4145–0.4152** (0.606 before the shadow-σ fix) | — |

- **We are behind on CPU, at parity on GPU**: CPU 0.108 vs 0.079 (1.37×;
  1.44× before the single-walk expansion, 1.67× before the instance ring). GPU min 0.415 vs nanoui min 0.418: a
  0.8% difference, inside the ±5% noise band, so parity, not a win. Same
  1201 instances at 2× backing. The earlier 1.43× GPU gap was our bug,
  not a renderer gap: the bench drew shadows at σ = 4 where nanoui uses
  σ = blur/2 = 2 (paint.zig:66). The instance gate missed it because
  nanoui's dump didn't print border_width. The dump and the comparator
  now carry bw/bc; the σ = 4 candidate fails with 600 divergences, σ = 2
  passes 1201/1201. Before paint existed on our
  side the comparison read 0.087 vs 0.066 (1.32×) — that number flattered
  us by omitting paint + encode. Like for like, expand + declare + solve
  (0.087) vs nanoui build + layout (0.050) is still 1.74×.
- Paint + encode together: **ahead**, 0.021 vs nanoui's 0.028–0.030
  (0.74×), after replacing the per-flush `newBufferWithBytes` with a
  3-slot instance ring (nanoui's model). Before the ring it was 0.039–0.041
  (1.4× behind). The phase boundary differs (our pass/encoder setup falls
  inside the paint lap, nanoui's inside encode), so only the sum compares —
  our encode alone (0.006) is not a like-for-like win over theirs (0.013).
  Both sides' sums are sums of per-phase medians. The ring's slot
  synchronisation (wait on the slot's last command buffer before reuse) is
  correct by construction but not test-gated: a static scene can't expose
  a race.
- The paint path is gated: `metal/tests/offscreen_scene.k` (offscreen
  surface) and `offscreen_twin.k` (same scene through a window) produce
  byte-identical 1280×800 BMPs. A +1/255 colour mutation makes `cmp`
  fail. The window path's `snap.k` is byte-identical before and after the
  metal refactor. `bench_boxes_paint.k` reports 1201 instances flushed per
  frame.
- Expansion, measured step by step (paint binary, gate-verified at each
  step): replacing 20 `when lf.gr == rr` scans with one ordered walk took
  lap 1 from ~0.060 to ~0.055. Moving the HSL intermediates from scratch
  store columns into a `capture` local was a wash. Spelling each `@mod`
  once (nanoui's 4 per leaf) was also a wash: the disassembly shows LLVM
  had already shared the duplicates, with the same 10 `fmod` call sites in
  both binaries. In a no-paint profile (`sample`, 3174 samples,
  top-of-stack), `fmod` is ~32% and nanoui pays the same 4 per leaf (f32
  `@mod`). Clay is ~64%: declare (`Clay__OpenElement` /
  `AddHashMapItem` / `ConfigureOpenElementPtr` / `CloseElement`) plus
  `Clay_EndLayout` / `CalculateFinalLayout` / `SizeContainersAlongAxis`.
  Koru's own frames are ~3%.
- The binding adds nothing measurable: Koru's declare-only arm matches raw
  C Clay's declare, and Koru's EndLayout matches raw C's.
- `bench_boxes.k`'s drain does no work that survives: the tail phase is 0
  at a 41 ns clock in every run. Probable cause (not verified in the
  disassembly): nothing reads the per-command writes, so LLVM collapses the
  loop. Either way, the measured binary has **no paint equivalent**. The
  gate binary doesn't paint either: it prints the instance stream as text
  in nanoui's dump format. Neither binary runs metal's `draw.*` →
  `instPush`, which needs a `*Frame` that today only exists inside a
  windowed `frames` pump.
- hillclimb's own Clay arm reads 0.059–0.060 for the same declare twin my
  C harness reads at 0.069. Not reconciled (possibly a different `clay.h`
  revision). Trust the ratios, not the absolute numbers.
- Instrument note: putting a second pipeline (the declare-only arm) in the
  same binary slowed the full arm's lap 1 from 0.053 to 0.069, while
  EndLayout stayed the same. One pipeline per binary for absolute numbers.
  `split1` (full arm only, with laps) matches the lap-free `climb` binary
  (0.086–0.089), so laps cost nothing measurable.

Scene: `boxes` — 600 rounded+shadowed boxes, 20×30 grid, sine-offset +
HSL colors at frame 100/120. 1201 painted instances.

**Correctness gate ran first** (`clay/tests/bench_boxes_gate.k` +
`bench_boxes_cmp.py`): a patched hillclimb `dump` exe prints nanoui's
painted instance stream; the Koru candidate reproduces it 1201/1201 with
0 divergences at 0.005pt/0.002 tolerances. Mutation-tested: a gr/gc-swapped
seed fails with 2247 divergences + 200 orphans. The gate can say no.

What the table implies for the bet: Clay accounts for ~0.067 of our 0.087
(declare ~0.034 + solve ~0.033). A solver that walks the retained rows
directly replaces **both** halves, not just EndLayout. The expansion pass
(~0.020) is a separate target: `std/store:query(leaves) when lf.gr == rr`
inside `for(0..20)` visits 12,000 rows per frame to emit 600. With paint
and encode measured, encode was a target too and is now closed: the
instance ring took paint + encode from 0.040 to 0.021, ahead of nanoui's
0.029. GPU is at parity once the shadow σ matches. The paint binary's lap 1 reads 0.059–0.060
against split1's 0.052–0.056 for identical code, the binary-composition
effect again, so lap 1 absolutes are per-binary.

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

1. **Constant factor** — no generality tax. The target is Clay's
   declare + solve together (~0.067, §2) if the solver reads spec rows
   directly, or EndLayout alone (~0.033) if it is fed by the same
   per-frame declaration pass.
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
   Two Clay behaviours the Clay oracle will hold us to: it caches
   measurements across frames (`Clay__MeasureTextCached`, clay.h:1639),
   and under the default WORDS wrap it measures **word by word plus a
   separate `spaceWidth`** (clay.h:1717, 1741), not the whole string.
   Kerning across spaces differs, so a whole-string CoreText width will
   not gate identical. A solver without its own cache loses the text
   scene. Hillclimb's Clay twin uses `WRAP_NONE` and our `ui:text` uses
   the default, so the two Clay oracles already measure differently.
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
   gate it as hard as the solver itself. Cheaper first: most dirty
   frames during interaction only change paint (hover recolor). A
   paint-only vs layout dirty split that patches rgba into a cached
   CmdView needs no invalidation proof. Boxes moves every frame, so
   neither form shows anything on boxes.
7. **Gate coverage.** Boxes only exercises fixed leaves, fit rows and a
   grow root. Grow distribution, percent sizing, alignment, clip and
   floating go untested. Clay runs in-process, so trap 1's real
   defense is differential fuzzing: random trees over the §4
   vocabulary, CmdView streams compared Clay vs native, plus a
   known-wrong mutant the fuzzer must catch. Scene gates then cover the
   nanoui side.

## 6. Orthogonal steals (smaller, separable, still worth it)

- **Hillclimb protocol → koru-side harness.** Protocol half done
  (koru main 1dbc71cf3):
  `std/benchmarking:climb(warmup, frames, reps)` returns the lowest
  median, and `lap(k)` / `lap.ms(k)` split a pass into phases. It panics
  if a pass skips, repeats or reorders a lap. Still to do: `--label` +
  append-only `bench/history.jsonl`.
  Makes every future number protocol-comparable to nanoui's published
  table and turns regression into a ledger diff.
- **Paused pump** — store-watch → dirty flag → skip expansion/solve/drain
  when clean; nanoui pauses the display link itself. Idle frame cost
  0.087 → 0 beats any solver constant-factor. Watch out: hover writes
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
