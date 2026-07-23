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
| **paginator** | Next — viewport Bridge cleared. |

### Port queue (do not skip)

1. progress ← **cataloged** (Bridge, 2026-07-23)
2. spinner ← **cataloged** (Bridge, 2026-07-23)
3. textinput ← **cataloged** (Bridge, 2026-07-23)
4. list (simple) ← **cataloged** (Bridge, 2026-07-23, replay 07 glm)
5. viewport ← **cataloged** (Bridge, 2026-07-23, replay 08 hy3)
6. paginator ← **active**
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
| `examples/component_text_input.k` · eyes: `koru-examples/gallery` | `text-input` | Charm field — prompt `> `, placeholder when empty, purple blink block cursor (~530ms from `! tick` ms), horizontal scroll on overflow; typing via `append-char`/`pop-char` (610_022). Public: `koru/vaxis:text-input { win, value, ms }`. Mid-buffer caret / optional placeholder·fg props deferred. | Bridge |
| `examples/component_list.k` · eyes: `koru-examples/gallery` | `list` | Charm bubbles/list simple delegate — bold purple title (marginLeft 2), `<N>. <title>` rows with paddingLeft 4, selected row swaps to paddingLeft 2 + `'> '` prefix (label still starts at column 4); pink `#EE6FF8` + bold selected, soft contrast unselected. Pagination footer one ●/○ per page — current ● pink `#EE6FF8`, others dim (capped to a 20-wide window around the current page); page-aligned scroll keeps the selection visible. Items are a single newline-delimited `string` payload (same `string` path text-input uses); the host store owns only `selected` + `count` — paint/chrome live in the widget, NOT the `! key` pipeline. Public: `koru/vaxis:list { win, title, items, selected }` (palette/runes hardcoded to Bubbles default taste; same pattern as progress-bar). Real `[]string` payload deferred (would beat the newline encoding). Witnessed-but-non-blocking hole: the store-reject `@compileError` embeds a user string literal UNESCAPED → a leaked Zig `expected ',' after argument` instead of the koru-level message (only fires under that misuse). | Bridge |

| `examples/component_viewport.k` | `viewport` | Charm bubbles/viewport — a scrollable content window: content taller than the `win`, the widget paints ONLY the visible slice starting at the host-owned offset; long lines hard-clip at the right edge (bubbles' no-soft-wrap default); chromeless like bubbles' (pager title/status are host markup, the bubbletea pager shape). Store owns `y` + `count`; keys (j/k line, d/u half-page, g/G ends) mutate state, the widget owns paint — NOT a `! draw`/`! key` mini-app. Public: `koru/vaxis:viewport { win, content, offset }`. SHOWN on a 16×72 pty: slice moves, clamps hold at both ends, status tracks `line N of 41`. Holes floated: host can't see win height → max scroll is last-line-at-top (count-1), not bubbles' count-height clamp; **arrow keys structurally can't reach `! key`** (run's dispatcher drops codepoint > 0x3000; kitty arrows are PUA 57352+, libvaxis Key.zig:177); soft-wrap deferred; real `[]string` payload deferred (same as list). | Bridge |

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
| 06 · 2026-07-23 | Bridge | `text-input` prompt + placeholder + blink cursor + scroll — see Replays |
| 07 · 2026-07-23 (glm probe) | Bridge | `list` simple delegate — title + paginated rows + ● ○ paginator — see Replays |
| 08 · 2026-07-23 (hy3) | Bridge | `viewport` scroll window — visible-slice paint + host offset — walls floated: arrow keys unreachable past the 0x3000 key filter; host can't see win height for bubbles' count-height clamp |
