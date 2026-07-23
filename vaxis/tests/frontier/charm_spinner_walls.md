# FRONTIER — Charm Bubbles `spinner` (COMPONENT_CHALLENGE replay 04)

Charm-class spinner needs: animated glyph cycling, Style fg, drop-in tag,
**frame ticks** so the frame index advances on a timer.

## Wall 1 — `koru/vaxis:run` has no `! tick` — FIXED (2026-07-23)

`run` now declares `! ?tick i64` (monotonic ms). Presence-gated loop:
`@hasDecl(__H, "tick")` → tryEvent + ~60 Hz pulses + repaint; absent →
blocking `nextEvent` (no timer tax on non-animated apps).

Pin `800_004` remains (self-contained run mirror *without* tick → KORU021).
That is the historical wall shape, not the live vaxis surface.

Probe: `examples/probe_tick.k` (or any `! tick _ |> …` consumer).

## Still open — Charm spinner widget

- Builtin / component `spinner` with Charm frame tables + Style fg
- Wire into gallery
- Progress spring can drink the same tick substrate

Natural aspirational program (needs `<spinner/>` next):
`vaxis/tests/frontier/charm_spinner_natural.k`
