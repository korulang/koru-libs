# COMPONENT_CHALLENGE catalog

Finished **Charm-class** reusable widgets from `COMPONENT_CHALLENGE.md`.
Each entry is a runnable `examples/component_*.k`; the line names the widget
tag, the thesis, and any toolchain gaps floated.

The catalog is the long-running artifact; each replay is one slice through it.
**Depth-first:** the active Charm target is polished to max before the queue
advances. Thin boundary-only demos do not enter Replays.

## Active target

| Charm | Status |
|-------|--------|
| **progress** | In flight — Charm-class meter (fill, empty/full runes, %, color blend, width from win; spring when substrate allows). Not cataloged until taste-gate clears. |

### Port queue (do not skip)

1. progress ← active
2. spinner
3. textinput
4. list (simple)
5. viewport
6. paginator
7. help
8. table
9. textarea
10. timer / stopwatch
11. filepicker

## Seed — pre-challenge substrate (not scored replays)

These existed before the generator; contestants **read** them to diverge. Do not
clone them. Most are layout/composition demos — useful ground, not Charm polish.

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

*(empty — no Charm-class survivor yet)*

### Evaporated (taste-gate)

| Replay | Tag | Why |
|--------|-----|-----|
| 01 · 2026-07-23 | `selection-list` | App-shaped `! draw`/`! key`; not a reusable tag boundary |
| 02 · 2026-07-23 | `progress-bar` | Boundary clean; Charm name without meter craft (label + value/max text) |
