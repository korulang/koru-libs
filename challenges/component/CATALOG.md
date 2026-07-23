# COMPONENT_CHALLENGE catalog

Finished **Charm-class** reusable widgets from `COMPONENT_CHALLENGE.md`.
Each entry is a runnable `examples/component_*.k`; the line names the widget
tag, the thesis, and any toolchain gaps floated.

The catalog is the long-running artifact; each replay is one slice through it.
**Depth-first:** the active Charm target is polished to max before the queue
advances. Thin boundary-only demos do not enter Replays.

**Eyes:** `koru-examples/gallery` — sit-and-look TTY surface for cleared exhibits
(`koruc run gallery.k` from that dir).

## Active target

| Charm | Status |
|-------|--------|
| **textinput** | Next — spinner Bridge cleared. |

### Port queue (do not skip)

1. progress ← **cataloged** (Bridge, 2026-07-23)
2. spinner ← **cataloged** (Bridge, 2026-07-23)
3. textinput ← **active**
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

| Demo | Tag | Thesis | Outcome |
|------|-----|--------|---------|
| `examples/component_progress.k` · eyes: `koru-examples/gallery` | `progress-bar` | Charm defaults meter — proportional ▌/░, purple→pink half-block blend, trailing `%`; width from `win`; drop-in `<progress-bar value max/>` in dock/stack. Public surface: `koru/vaxis:progress-bar { win, value, max }` (colors/runes/% hardcoded to Bubbles defaults). Spring deferred. | Bridge |
| `examples/component_spinner.k` · eyes: `koru-examples/gallery` | `spinner` | Charm MiniDot braille cycle + purple `#5A56E0`; MiniDot FPS owned inside widget from `! tick` ms; drop-in `<spinner ms/>`. Public: `koru/vaxis:spinner { win, ms }`. Optional fg/kind props deferred (same hardcode pattern as progress-bar). | Bridge |

### Evaporated (taste-gate)

| Replay | Tag | Why |
|--------|-----|-----|
| 01 · 2026-07-23 | `selection-list` | App-shaped `! draw`/`! key`; not a reusable tag boundary |
| 02 · 2026-07-23 | `progress-bar` | Boundary clean; Charm name without meter craft (label + value/max text) |

### Frontiers

| Replay | Outcome | Walls |
|--------|---------|-------|
| 03 · 2026-07-23 | Frontier → Bridge | Color; grapheme; fill math → `progress-bar` |
| 04 · 2026-07-23 | Frontier → Bridge | No `! tick` on `run` (KORU021). Pin `800_004`. Tick fixed; spinner shipped replay 05. |
| 05 · 2026-07-23 | Bridge | `spinner` MiniDot + tick ms + purple — see Replays |
