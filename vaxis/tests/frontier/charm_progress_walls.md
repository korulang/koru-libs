# FRONTIER — Charm Bubbles `progress` (COMPONENT_CHALLENGE replay 03)

Charm-class progress needs: proportional ▌/░ fill, optional `%`, **color**
(purple→pink blend), width from the window. Widget boundary =
`koru/vaxis:component(progress)` owning `<progress-bar/>`.

## Wall 1 — Style has no Color — FIXED

`Style.fg` / `Style.bg` packed RGB. Probe: `examples/style_color.k`.

Pin `800_003` remains (unknown fields → Stage D) — separate analysis hole.

## Wall 2 — write-at paints bytes — FIXED

`write-at` / `write-styled` / `write-in` use `printSegment`.

## Wall 3 — fill math inside component boundary — FIXED

`koru/vaxis:progress-bar` owns proportional fill + half-block blend + `%`.
Markup tag `<progress-bar …/>` resolves to that event (builtin `wa_qual` path).
Reusable widget:

```
koru/vaxis:component(progress) {
    <progress-bar value={{ value:d }} max={{ max:d }}/>
}
```

Proof demo: `examples/component_progress.k` (space +10, q quit).

## Still open (polish, not blocking)

- Spring / harmonica-style animated transitions (needs frame tick substrate)
- Customizable colors / fill runes (Charm options) — defaults match Bubbles

Replay the contestant against the same target for catalog taste-gate.
