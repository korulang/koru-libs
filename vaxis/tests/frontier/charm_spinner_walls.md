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
