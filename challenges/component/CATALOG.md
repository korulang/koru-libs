# COMPONENT_CHALLENGE catalog

Finished widgets / composition theses from `COMPONENT_CHALLENGE.md` (repo root).
Each entry is a runnable `examples/component_*.k` (or noted path); the line names
what it proves and any toolchain gaps it floated.

The catalog is the long-running artifact; each replay is one slice through it.

## Seed — pre-challenge substrate (not scored replays)

These existed before the generator; contestants **read** them to diverge. Do not
clone them.

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

| `examples/component_selection_list.k` | live dock fill + store sweep branches on `row == ui.sel` into two row components; keys mutate sibling-store cursor, vaxis damage-repaint |
