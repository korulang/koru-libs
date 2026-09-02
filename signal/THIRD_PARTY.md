# Third-party notices — `koru/signal`

`koru/signal` (`@korulang/signal`, MIT) is Koru surface + host runtime on top of a
shared **JSFX/EEL2 → Zig** emit pipeline. Upstream lineage and vendored runtimes:

## Lineage

| Layer | Project | Role |
|-------|---------|------|
| Origin | [Intranquil transpiler](https://github.com/6digit-studio/intranquil) (`transpiler/`) | JSFX/EEL2 → Zig for audio DSP (`@sample`, dylib ABI, ULP=0 oracle sweeps) |
| Fork | [6digit-world](https://github.com/korulang/6digit-world) | WMFX — graph IR, scalar/sample wires, world-model emit; **`signal` emit profile** (`include_transport = false`) |
| Koru package | `koru-libs/signal` | `:shape` / `:init` / `:tick`, external clock, `models/*.zig` weld |

Fork decision and spine: `6digit-world/README.md` (2026-06-04). Intranquil keeps the
original transpiler for audio rendering; koru/signal consumes the evolved fork.

## Vendored at codegen build time

`signal/codegen/build.zig` compiles against sibling checkouts (not npm deps):

| Component | Path (typical) | License |
|-----------|----------------|---------|
| **WDL / NSEEL2** (EEL2 reference runtime) | `../ysfx/thirdparty/WDL/` | Cockos permissive — see `ysfx/thirdparty/WDL/LICENSE.txt` |
| **ysfx** (parse + golden reference) | `../ysfx/` | [Apache-2.0](https://github.com/jpcima/ysfx/blob/master/LICENSE) |
| **6digit-world** emit sources | `../6digit-world/src/` | Same repo; see upstream for terms |

Generated `models/*.zig` includes `denormalFilter` derived from WDL `denormal.h`
(portable NSEEL2 assign hygiene — see comments in emitted files).

## Attribution

When redistributing generated model artifacts or documentation derived from this
pipeline, retain:

1. Cockos WDL/NSEEL2 notice (via ysfx vendor tree)
2. ysfx Apache-2.0 notice where ysfx sources or naming are referenced
3. This file (or equivalent) for the Intranquil → 6digit-world → koru/signal chain
