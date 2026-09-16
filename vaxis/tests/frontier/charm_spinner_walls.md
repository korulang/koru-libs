# FRONTIER — Charm Bubbles `spinner` (COMPONENT_CHALLENGE replay 04→05)

Charm-class spinner needs: animated glyph cycling, Style fg, drop-in tag,
**frame ticks** so the frame index advances on a timer.

## Wall 1 — `koru/vaxis:run` has no `! tick` — FIXED (2026-07-23)

`run` now declares `! ?tick i64` (monotonic ms). Presence-gated loop:
`@hasDecl(__H, "tick")` → tryEvent + ~60 Hz pulses + repaint; absent →
blocking `nextEvent` (no timer tax on non-animated apps).

Pin `800_004` remains (self-contained run mirror *without* tick → KORU021).
That is the historical wall shape, not the live vaxis surface.

Probe: `examples/tick.k` (or any `! tick _ |> …` consumer).

## Spinner widget — SHIPPED (replay 05 Bridge)

- Builtin `koru/vaxis:spinner { win, ms }` — MiniDot frames + purple fg +
  MiniDot period (`1000/12` ms) inside the zig boundary
- Markup `<spinner ms={{ ms:d }}/>` via wa_qual (same path as progress-bar)
- Demo: `examples/component_spinner.k`

Surface `i64 /` still emits Zig `/` (needs `@divTrunc`) — FPS math stays in
the zig builtin (honest float, not a library dodge of a koru expression).

## `<text>` inside `<stack-panel>` — CLOSED (2026-09-16)

The stack-panel inner walk treated every child tag as a component call, so
`<text>` in a stack row resolved as `<consumer>:text` → KORU040. A text row
is a PAINTED element in the row's slice: the walk now routes `cn == "text"`
through `textEl` (the shared placeholder/prop classifier the top-level path
uses) and emission carves `sub(win, y:stack_y, h:1)` before painting at y:0
of the slice — the same two-op shape a stacked component gets. Verified live:
`charm_spinner_natural.k` renders the MiniDot glyph + `q quit` row and exits
clean on `q`.

## `<text>` inside `<dock>` — CLOSED (2026-09-16)

Same class as the stack-panel gap: dock children were all classified as
component calls. A text row is painted content in the carved slot — the
inner walk routes `cn == "text"` through `textEl` and emission carves the
dock slot first (top `sub` / bottom `sub-from-bottom` / fill `sub-fill`,
the same three primitives components get) then paints at y:0 of the
slice. Verified live: `dock_text.k` pins a title row top and `q quit`
bottom in one `<dock>`. Nested `<stack-panel>` kids inside a dock slot
still classify text as components — deeper nesting is the remaining case.
