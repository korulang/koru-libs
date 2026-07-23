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
| **filepicker** | Next — timer/stopwatch Bridge cleared. |

### Port queue (do not skip)

1. progress ← **cataloged** (Bridge, 2026-07-23)
2. spinner ← **cataloged** (Bridge, 2026-07-23)
3. textinput ← **cataloged** (Bridge, 2026-07-23)
4. list (simple) ← **cataloged** (Bridge, 2026-07-23, replay 07 glm)
5. viewport ← **cataloged** (Bridge, 2026-07-23, replay 08 hy3)
6. paginator ← **cataloged** (Bridge, 2026-07-23, replay 09 hy3)
7. help ← **cataloged** (Bridge, 2026-07-24, replay 10 hy3)
8. table ← **cataloged** (Bridge, 2026-07-24, replay 11 hy3)
9. textarea ← **cataloged** (Bridge, 2026-07-24, replay 12 hy3)
10. timer / stopwatch ← **cataloged** (Bridge, 2026-07-24, replay 13 hy3)
11. filepicker ← **active**

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

| `examples/component_viewport.k` · eyes: `koru-examples/gallery` | `viewport` | Charm bubbles/viewport — a scrollable content window: content taller than the `win`, the widget paints ONLY the visible slice starting at the host-owned offset; long lines hard-clip at the right edge (bubbles' no-soft-wrap default); chromeless like bubbles' (pager title/status are host markup, the bubbletea pager shape). Store owns `y` + `count`; keys (j/k line, d/u half-page, g/G ends) mutate state, the widget owns paint — NOT a `! draw`/`! key` mini-app. Public: `koru/vaxis:viewport { win, content, offset }`. SHOWN on a 16×72 pty: slice moves, clamps hold at both ends, status tracks `line N of 41`. Holes floated: host can't see win height → max scroll is last-line-at-top (count-1), not bubbles' count-height clamp; **arrow keys structurally can't reach `! key`** (run's dispatcher drops codepoint > 0x3000; kitty arrows are PUA 57352+, libvaxis Key.zig:177); soft-wrap deferred; real `[]string` payload deferred (same as list). | Bridge |
| `examples/component_paginator.k` · eyes: `koru-examples/gallery` | `paginator` | Charm bubbles/paginator — pagination **status chrome only** (not page content): Dots mode (●/○, ActiveDot pink `#EE6FF8` + bold, InactiveDot dim) and Arabic mode (`N/M`, current pink). Host store owns `page` + `total`; widget owns paint; h/l mutate page (arrows unreachable — same 0x3000 wall). Public: `koru/vaxis:paginator { win, page, total, kind }`. Demo drives two tags from one store. | Bridge |
| `examples/component_help.k` · eyes: `koru-examples/gallery` | `help` | Charm bubbles/help — keybinding hints. SHORT mode (default): one bottom line `key desc • key desc • …`, muted keys `#626262`, softer descs `#4A4A4A`, dim ` • ` separators `#3C3C3C`, **width-aware truncation with a trailing `…`** when wider than `win` (bubbles' ShortHelpView + ansi.Truncate — SHOWN truncating at both 100- and 46-col widths on a pty). FULL mode: one `key  desc` row per binding, keys right-padded into an aligned column (bubbles' single-column FullHelpView); both modes bottom-anchor (help hugs the screen bottom). Toggle short↔full with `?` — host store owns the `mode` int, the widget owns the paint (NOT the `! key` pipeline). Bindings arrive as a host-owned `key:desc`-per-line `string` payload (list/viewport path); keys carry arrow glyphs (↑/k) safely because they are painted, not typed. Public: `koru/vaxis:help { win, bindings: string, mode: i64 }` (palette/separators hardcoded to Bubbles defaults; same pattern as progress-bar). Holes: a real structured `[]Binding` with separate short/full lists — and multi-column full help — is deferred (the flat newline payload can't express column groups, so full help is one column); rune display-width counts each codepoint as 1 col (arrows/•/… correct; wide CJK not special-cased). | Bridge |

| `examples/component_table.k` · eyes: `koru-examples/gallery` | `table` | Charm bubbles/table — columns + header + selectable rows. Bold header row over a dim `─` underline (Header BorderBottom); fixed-width columns with 1-col padding each side (Padding(0,1)); cell text wider than its column truncates with a trailing `…` (ansi.Truncate — SHOWN on `Banglad…`/`Argenti…`/`Philipp…` at Country width 8); the SELECTED row paints whole-row bold + Charm pink `#EE6FF8` (DefaultStyles Selected = bold + lipgloss "212"). Host store owns the cursor index; j/k move, g/G jump ends — widget OWNS paint, NOT the `! key` pipeline. Page-aligned visible window keeps the selection on screen (SHOWN: j across the page boundary flips to rows 12–20 with the cursor on 12; G/g land on last/first page). Payload is host-owned strings (bubbles FromValues): `headers`/`widths` `\|`-separated, `rows` newline-delimited with `\|` fields. Public: `koru/vaxis:table { win, headers, widths, rows: string, selected: i64 }` (palette hardcoded to Bubbles defaults; same pattern as progress-bar). Holes: real typed `[]Column`/`[]Row` payload deferred (flat-string upgrade list/help flagged); bubbles' smooth offset viewport deferred — needs widget-owned scroll state the stateless prop rail can't hold (page-aligned window instead, list's shape); rune width = 1 col/codepoint (wide CJK edge). | Bridge |

| `examples/component_textarea.k` · eyes: `koru-examples/gallery` | `textarea` | Charm bubbles/textarea — multi-line input filling a tall `<dock>` fill window: purple `#5A56E0` `┃ ` prompt gutter down the FULL input height (bubbles' per-row Prompt); muted placeholder when empty with the blink cursor over its first char (text-input's placeholderView shape); purple blink block cursor (~530ms from `! tick` ms — SHOWN alternating on a pty) at the END of the value (append/pop path); bottom-anchored vertical follow when content outgrows the window (SHOWN: 16 lines in a 13-row fill shows d…p with the cursor line parked on the last row — the widget sees its own height, so no page-aligned compromise); long lines hard-clip (viewport's no-wrap) EXCEPT the cursor line, which horizontally scrolls like text-input (both SHOWN at 72 cols). Enter inserts a line break through the proven `append-char(s, k.ch)` path — raw ch 13 lands in the buffer and the widget treats `'\r'` and `'\n'` both as hard breaks; backspace pops across breaks (SHOWN rejoining lines). Host store owns the buffer; widget OWNS paint/chrome, NOT the `! key` pipeline. Public: `koru/vaxis:textarea { win, value: string, ms: i64 }` (palette/prompt/placeholder hardcoded to Bubbles-ish defaults; same pattern as progress-bar). Holes: mid-buffer caret / arrow navigation deferred (append/pop end-only — text-input's hole; arrows also unreachable, the 0x3000 wall); soft-wrap deferred (honest hard-clip); line numbers / char limit / focused-blurred chrome deferred. | Bridge |

| `examples/component_timer.k` · eyes: `koru-examples/gallery` | `timer` | Charm bubbles/timer — countdown. Paints remaining as Go `Duration.String()` taste (`1m2s` / `500ms` / `0s`); purple `#5A56E0` while running, dim when paused, timed-out `0s` bold pink `#EE6FF8`. Host store owns `remaining_ms` + `running` (0/1); decrements on `! tick` wall delta. Public: `koru/vaxis:timer { win, remaining_ms, running }`. Gallery hole floated: a bare `! tick` installs alone and drops later when-ticks — clocks must share the host tick store with `ms`. | Bridge |
| `examples/component_stopwatch.k` · eyes: `koru-examples/gallery` | `stopwatch` | Charm bubbles/stopwatch — count-up. Elapsed `Duration.String()` taste; purple running / dim paused. Host owns `elapsed_ms` + `running`; increments on `! tick` wall delta; `r` resets. Public: `koru/vaxis:stopwatch { win, elapsed_ms, running }`. | Bridge |

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
| 09 · 2026-07-23 (hy3) | Bridge | `paginator` Dots + Arabic status chrome — see Replays |
| 10 · 2026-07-24 (hy3) | Bridge | `help` keybinding hints — width-aware short help (` • ` join + `…` truncation) + column-aligned full help, `?` toggle; muted-key/soft-desc/dim-sep Charm palette — see Replays |
| 11 · 2026-07-24 (hy3) | Bridge | `table` columns + header + pink selected row + `…` cell truncation + page-aligned scroll — walls floated: widget-owned scroll state (bubbles' smooth offset) inexpressible on the stateless prop rail; typed `[]Column`/`[]Row` payload deferred |
| 12 · 2026-07-24 (hy3) | Bridge | `textarea` multi-line input — `┃ ` gutter + placeholder + blink cursor + bottom-anchored follow + hard-clip/cursor-line scroll — hit no new wall (Enter rides `append-char(s, k.ch)` as raw ch 13; widget treats `\r`/`\n` as breaks) |
| 13 · 2026-07-24 (hy3) | Bridge | `timer` + `stopwatch` — countdown/count-up Duration paint + tick-driven host state — see Replays |
