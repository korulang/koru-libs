# koru/signal — mechanical slices & blog series

Companion to the package. Each slice is one grab; each post lands after its slice is green.

## Blog series (proposed)

Same rhythm as MLIR/SPIRV in koruc: **surface → IR → backend artifact → host loop**.

| # | Post title (working) | Slice | Green when |
|---|---------------------|-------|------------|
| 1 | **External clock for signal graphs** | v0 pin | `external_tick` passes; caller owns `for`, signal owns `:tick` |
| 2 | **Named models like named stores** | A | `init(Breath)` / `tick(Breath, …)` transforms (store `:insert(world)` parallel) |
| 3 | **Codegen weld — compile models to Zig** | C | `models/breath.zig` regen; slim signal `State` — **done** (C1+C2) |
| 4 | **`:shape` — ports and carried state** | D | norun `:shape(Breath) { … }` — **done** (`shape_surface`) |
| 5 | **Koru source lowers to the same EEL backend** | E | Koru-authored breath ≡ reference emit (oracle parity) — **done** (`breath.koru.eel` + `breath_parity`) |
| 6 | **Second model proves the registry** | B+F | Two models, instance table, build imports both — **done** (`Floor` + `two_models`) |

Posts are `draft: true` on korulang.org until Lars flips them (see `blogpost` skill). Cite `signal/tests/*` and `./run_regression.sh` / `koruc suite test` — never invent test paths.

**Companion journal (draft):** `korulang_org/src/routes/blog/koru-signal-journal-01-external-clock/+page.svx` — read at `/blog/drafts` after `bun run blog:index`.

## Slices (implementation)

### A — Surface syntax
- A1 `init(Breath)` → `init.model(model: "Breath")` — **done**
- A2 `tick(Breath, pass_rate: r)` → `tick.model(...)` — **done**
- A3 bare reference `koru/signal(Breath)` — **done** (default transform → nop registry)
- Escape hatch: `init.model` / `tick.model` call runtime directly.

### B — Runtime generalization
- B1 instance table (`Breath → Instance`) — **done**
- B2 tick-before-init err pin — **done**

### C — Emit pipeline
- C1 signal emit profile (drop JSFX transport fields from emitted `State`) — **done** (`include_transport = false`)
- C2 `codegen/run.sh` → `models/breath.zig` — **done**
- C3 build requires from model set used in program — **done** (`koru/signal_rt/*` + post-transform weld; `breath_only_build`, `two_models_build`)

### D — `:shape` (norun)
- D1 norun `shape` tor registration — **done** (kernel-parallel; `koru/signal:shape(Breath) { … }`)
- D2 reduce `[type]` blocks, `const { }` → init constants — **done** (`breath.koru.kz` + `signal-model-emit`; tick body in `block { }`)

### E — Koru → EEL → Zig
- E1 expr → `[]const Section` — **done** for model files (`model_emit.zig`: shape + const + block → EEL)
- E2 `codegen.emitModule(sections, PortUnit[])` in-process — **done** (`signal-koru-emit`)
- E3 round-trip pin vs reference oracle — **done** (`breath_parity`: Koru≡reference≡oracle)

### F — Ops
- F1 `suite.k` cases — **done**
- F2 `package.json` — **done**
- F3 second model — **done** (`Floor` threshold + `two_models` pin)

## MLIR/SPIRV parallel (already in koruc)

From `src/main.zig` — same **compile boundary** idea:

1. User writes Koru with `|mlir` / GPU variants
2. Compiler **synthesizes build requirements** (`.mlir` → `.o` / `.spv` glob in `build_output.zig`)
3. Host loop calls emitted handlers; backend is AOT artifact

Signal path:

1. User writes `:shape` / `:init` / `:tick`
2. `:init` lowers through **shared init/block codegen** → `models/*.zig` + `addImport`
3. External clock calls `:tick`; state lives in emitted `State`

Shared machinery: `std/build:requires`, `std/compiler:requires`, transform pass, `${REL_TO_ROOT}` paths — not new territory, new IR target.
