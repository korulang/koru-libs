# COMPOSITION_CHALLENGE catalog

Finished **composed surfaces** from `COMPOSITION_CHALLENGE.md` — assemblies that
drink from cleared COMPONENT leaves. Each entry is a runnable
`examples/composition_*.k`; the line names the composition, which leaves it
wires, the thesis, and any toolchain gaps floated.

The catalog is the long-running artifact; each replay is one slice through it.
**Depth-first:** the active composition is polished before the queue advances.
Leaf reimplementation does not enter Replays.

**Eyes:** `koru-examples/gallery` — sit-and-look TTY surface (`koruc run gallery.k`).

**Leaf law:** only tags cataloged under `challenges/component/CATALOG.md` Replays.

## Active target

| Composition | Status |
|-------------|--------|
| **pager** (viewport + paginator) | **Shipped** (replay 01 hy3, 2026-07-24) — see Replays. Queue advances to menu after taste-gate. |

### Port queue (do not skip)

1. pager (viewport + paginator) ← **active**
2. menu (list + help)
3. browser (filepicker + help)

## Seed — leaf catalog (read, do not redo)

Cleared COMPONENT Bridges the contestant may nest (see that catalog for theses):

| Leaf demo | Tag |
|-----------|-----|
| `examples/component_viewport.k` | `viewport` |
| `examples/component_paginator.k` | `paginator` |
| `examples/component_list.k` | `list` |
| `examples/component_help.k` | `help` |
| `examples/component_filepicker.k` | `filepicker` |
| (+ progress, spinner, text-input, table, textarea, timer, stopwatch) | … |

Layout substrate (not scored here): `component_dock*.k`, `component_stack*.k`,
`component_flow.k`.

## Replays

| Demo | Composition | Thesis | Outcome |
|------|-------------|--------|---------|
| `examples/composition_pager.k` | **pager** — `<viewport/>` + `<paginator/>` ×2 (Dots + Arabic) | Charm's deliberate split rewired: one host store owns `page`/`total`/`offset`; the named `koru/vaxis:component(pager)` dock nests the catalog `<viewport/>` (paints the current 12-line page slice at the store offset) over BOTH `<paginator/>` modes bound to the same `page`/`total` — one `h`/`l` mutation steps `page`+`offset` together (multi-field `stored`, timer's shape) so the visible content, the ActiveDot, and the `N/M` count flip in lockstep and can never disagree. Leaves own all paint; nothing reimplemented in `! draw`. Holes: hit no new wall — host win-height blindness (viewport's floated hole) → fixed 12-line page-aligned slices; arrows unreachable (0x3000) → h/l. | Bridge (replay 01 hy3 — koruc compile-proven; gallery eyes pending taste-gate) |

### Evaporated (taste-gate)

| Replay | Name | Why |
|--------|------|-----|
| — | — | — |

### Frontiers

| Replay | Outcome | Walls |
|--------|---------|-------|
| — | — | — |
