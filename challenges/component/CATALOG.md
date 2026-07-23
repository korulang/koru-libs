# COMPONENT_CHALLENGE catalog

Finished **reusable widgets** from `COMPONENT_CHALLENGE.md` (repo root).
Each entry is a runnable `examples/component_*.k`; the line names the widget
tag, the thesis, and any toolchain gaps floated.

The catalog is the long-running artifact; each replay is one slice through it.

## Seed — pre-challenge substrate (not scored replays)

These existed before the generator; contestants **read** them to diverge. Do not
clone them. Most are layout/composition demos — useful ground, not the bar for
a scored replay (scored entries need a reusable markup-tag widget boundary).

| Demo | Thesis |
|------|--------|
| `examples/component_greet.k` | leaf `component` + `{{ prop:s }}` |
| `examples/component_nest.k` / `component_forward.k` | parent forwards `win` / props |
| `examples/component_stack.k` | static `<stack-panel>` owns y |
| `examples/component_stack_live.k` | live `stack` / `stack-row` + store sweep |
| `examples/component_dock.k` | `<dock>` top / bottom / fill |
| `examples/component_dock_stack.k` | static `<stack-panel dock="fill">` |
| `examples/component_dock_stack_live.k` | empty fill returns live `Stack` |
| `examples/component_rows.k` | row windows / hand layout precursor |
| `examples/component_counter.k` / `component_flow.k` | early interaction / flow shapes |

## Replays

*(empty — replay 01 `selection-list` evaporated at taste-gate 2026-07-23: app-shaped
draw/key pipeline, not a reusable `<selection-list/>` widget)*
