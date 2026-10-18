---
type: belief
id: frag-pointer-events-arrive-as-optional-arms
provenance: koru-libs/metal frames event arms + clay el.clip — spellings landed with the gallery probe, 2026-10
ts: 2026-10
---

# Pointer events arrive as optional arms; clip is a configure tor

The pointer event surface and the clip element needed spellings; both
borrow the substrate's vocabulary rather than coining new names.

## The spellings

- `! ?mouse-up`, `! ?mouse-move`, `! ?mouse-drag`, `! ?scroll` — optional
  arms on `frames`, spelled 1:1 after the Event union kinds
  (`mouse_up`, `mouse_move`, `mouse_drag`, `scroll`). The mailbox carries
  the kinds; the arms carry the kebab spellings of the same words.
- `el.clip` — a clay configure-tor in the `el.cfg` family (called on an
  open element, not an opener). `ox`/`oy` carry `childOffset` — scroll
  position — and `horiz`/`vert` flag the clipped axes, mirroring Clay's
  own `clip` decl field names.

## Why borrowed vocabulary

An agent or a spec reading `mouse-move` or `el.clip` can ground it in
documentation that already exists — AppKit's event names, Clay's
`clip` config — instead of a mapping table invented here. The
interaction atoms are nanoui's (pressable click = down+up on the same
hit, drag-scoped capture, wheel-scrolled clip viewport); keeping the
substrate's names means the port's semantics and its spellings arrive
from the same source.

## Consequence

Hit-testing is a consumer-side store query over `CmdView.ud` — Clay emits
the command stream, the consumer builds the hit map it wants (gallery.k
shows the pattern). No event dispatcher decides z-order for you; the
query's scan order is the topmost rule.
