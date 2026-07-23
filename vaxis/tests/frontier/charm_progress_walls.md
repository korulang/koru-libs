# FRONTIER — Charm Bubbles `progress` (COMPONENT_CHALLENGE replay 03)

Charm-class progress needs: proportional ▌/░ (or █/░) fill, optional `%`,
**color** (solid and/or purple→pink blend), width from the window, spring only
if the substrate can express it. Widget boundary = `koru/vaxis:component(progress)`.

Replay 02's label + `value / max` text dump is disqualified. Replay 03 stopped
at the first real walls — no fake ASCII meter, no catalog credit.

## Wall 1 — Style has no Color — FIXED (2026-07-23)

`Style` now carries `fg` / `bg` as packed `u32` RGB (`0` = terminal default;
else `0xRRGGBB` → `libvaxis.Color.rgbFromUint`). `write-styled` maps them onto
`Cell.Style`. Probe: `examples/style_color.k` (and frontier `style_fg_color.k`).

Pin `800_003` remains: *unknown* fields on a Style **without** `fg` still fall
through to Stage-D Zig — that is a separate Koru analysis hole, not this wall.

## Wall 2 — write-at paints bytes, not graphemes — FIXED (2026-07-23)

`write-at` / `write-styled` / `write-in` now use `Window.printSegment` (libvaxis
grapheme iterator). Charm `▌` / `░` / `█` paint as one cell each.

## Wall 3 — component markup cannot own fill math — OPEN

`koru/vaxis:component` synthesizes markup → `write-at` / child calls. No loop,
no string-build of N×full + M×empty from `value`/`max`/`win.width` inside the
component body. Host-side fill then `<progress bar={{ s:s }}/>` puts chrome
outside THE BAR.

`win.width` is readable; width-from-window is not the blocker.

### Unblock (next)

Ship a meter primitive the widget owns — e.g. a `|zig` `progress-bar` /
`<meter>` path that builds proportional + per-cell blend inside vaxis, callable
from the component boundary (builtin markup tag or equivalent). Not a
draw-pipeline dodge in the demo `app`.

Then replay retries the **same** Charm `progress` target.
