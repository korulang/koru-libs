# Live-resize jitter — investigation record

A handoff for the next agent. The symptom is *almost* nailed. What follows is
everything that was tried, measured, exonerated, and rejected, plus the leads
that were never explored. Do not re-run an experiment whose result is recorded
here unless you suspect the recording is wrong — that is wasted effort.

## The artifact under test

- `clay/tests/spec_sel_live.k` — a live OMNI layout spike: Clay folds ~25 spec
  panels + floating chrome per frame, Metal renders rects.
- Build: `koruc -OReleaseFast spec_sel_live.k` → `./a.out`
- Controls: **Tab** cycles selection, **click** selects, **Esc** quits.
- The window is a `KoruMetalView` (NSView subclass) hosting a `CAMetalLayer`,
  driven by a consumer-side `frames` loop on the main thread.
- Relevant code: `metal/index.kz` — `syncSurfaceSize`, `drawLiveFrame`,
  `liveDraw`, `impSetFrameSize`, `impWindowResized`, `impLiveStart`, `impLiveEnd`
  (~lines 330–445 at time of writing); `frames|zig` event pump (~line 695+).

## The symptom

During an edge-drag live resize: **supposedly static boxes jitter a little**;
the side panel (floating, lerped to `wins.w - 144`) looks buttery. The user
describes it as "a texture being resized and then repainted afterward." Severity
varied by machine/screen size; later became *constant* once the synchronous
draw path was in.

## Why live drawing exists at all

During an edge drag, AppKit runs a modal tracking loop *inside* `sendEvent:` —
the frames loop is parked in that call, so no `! frame` body runs until
mouse-up. Without intervention the compositor stretches a stale drawable and
the layout snaps once on release. The current design:

1. `frames|zig` installs the consumer's frame callback into `$mod.frame_cb`.
2. `KoruMetalView` has a `setFrameSize:` override (calls NSView's original IMP,
   then draws) and observes `NSWindowDidResizeNotification`.
3. Both paths funnel into `liveDraw`, which syncs surface size and draws —
   **deduped by dims** so the double-fire per step renders once.
4. `NSWindowWillStart/DidEndLiveResizeNotification` bracket the drag;
   `impLiveEnd` clears the dedupe cache and draws a final frame.
5. `setPreservesContentDuringLiveResize: NO` on the window.
6. Presents are **immediate** (`presentDrawable:` + `commit`), never
   transaction-pinned.

## Measured facts (exonerated suspects)

Instrumentation added `std.debug.print` lines in `liveDraw` (tag `S` =
setFrameSize, `N` = notification, `E` = liveEnd) logging view bounds (`vp`),
layer bounds (`lb`), drawable size (`dw`), and whether a draw happened; plus
`std/io:print.ln` in the consumer logging every solved `rc` rect per frame.
Drag logs captured to `/tmp/omni_rc*.log` (may be gone — regenerate by re-adding
the prints; the diffs were committed *without* them at `d12d429`).

- **The fold is clean.** 1557 frames of solved rects: every element's `x/y/w/h`
  stream is monotone with ≤2 total sign flips across all 25 elements. Static
  boxes are bit-identical every frame. **The layout algorithm did not produce
  the jitter — do not re-investigate it.**
- **`vp == lb` on all 344 resize events.** The CAMetalLayer's bounds never lag
  `contentView.bounds` — the layer is not displaying at a stale size.
- **`dw = 2×vp` always.** Drawable size stays coherent (Retina 2×).
- **S→N ordering is stable** — `setFrameSize:` fires first at each new dims,
  the notification follows at identical dims (dedupe makes it a no-op).
- **View bounds during a drag are integral points** on this machine. Fractional
  bounds are still possible on other configurations.

## What fixed what

| Change | Result |
|---|---|
| Draw via `NSWindowDidResizeNotification` only | Worked (relayout during drag) but "stretch then repaint" judder per step |
| Draw inside `setFrameSize:` (earlier in the step) | Same judder persisted |
| `presentsWithTransaction = YES` always | Jitter gone, but app starved: gray startup, clicks seconds late, hang |
| PwT bracketed to live-resize only | Smooth drag but "super slow"; clicks throttled afterward |
| PwT off + dedupe (one draw/step) | Jitter back, clicks instant |
| `contentsScale = backingScaleFactor` (was 1.0 default) + integral `drawableSize` in pixels | Correctness fix; jitter persisted |
| ReleaseFast build | Jitter persisted (Debug frame time exonerated) |
| `setPreservesContentDuringLiveResize: NO` | **Best version so far** — residual slight jitter remains |
| Edge-snapped rect coords (round x/y, w/h from rounded edges) | Kept; removes sub-pixel shimmer as a confound |

**Why PwT starves the pump (confirmed):** transaction-pinned presents queue
until a CATransaction commits. Queued drawables hold the pool (default 3);
`nextDrawable` blocks in the frames loop; the mailbox drains late; clicks feel
throttled. This reproduces even *after* a drag ends (queued presents outlive
it). Do not re-enable it without a present budget.

## Where the jitter likely still lives

The content stream is provably correct, so the residual artifact is in the
*composite step* — something we cannot see from inside the process. Most likely
a one-vsync mismatch per drag step between the layer-bounds commit and our
immediate present. With `preservesContentDuringLiveResize: NO` it probably
manifests as a brief unpainted/flickering strip rather than a stretch now —
**nobody has looked at the artifact frame-by-frame.**

## Leads never explored (in priority order)

1. **Actually watch it.** Screen-record the drag (QuickTime) at high frame
   rate, step through frames, and *see* the artifact: is it a stretched frame,
   an unpainted strip, a torn frame, or a content shift? Every hypothesis so
   far was inferred from feel and log coherence — the visual evidence was never
   captured. This is the single cheapest decisive experiment.
2. **`displaySyncEnabled` / `frameInterval` on CAMetalLayer** — never touched.
   Immediate presents may be tearing or landing mid-vsync.
3. **Draw on the notification path only** (drop `setFrameSize:`) — the inverse
   of the current split was never tested in isolation.
4. **CVDisplayLink-driven redraw** — the MTKView architecture: a display-link
   callback on a separate thread posts dims; redraw happens at vsync cadence
   *outside* `sendEvent:`, so the tracking loop is never blocked and presents
   pace with the display. Complication: `frame_cb` runs Koru store code —
   NOT thread-safe against the main thread's mailbox. Would need to marshal a
   "draw now" onto the main runloop in tracking mode (a custom NSEvent posted
   in NSEventTrackingRunLoopMode, or performSelector in common modes).
5. **Layer-hosted vs layer-backed.** The view sets `setLayer:` then
   `setWantsLayer:` — making it layer-*hosted*, so `updateLayer`/`drawRect:`
   are never called and AppKit's own resize-repaint path can't help. A
   layer-backed view (`wantsLayer=YES`, layer returned from `makeBackingLayer`)
   participates in AppKit's display machinery differently during resize.
6. **Instrument present→display latency** — `os_signpost` around
   `presentDrawable`/`commit` + Instruments, or count presents vs vsyncs via
   a CVDisplayLink tick, to see whether presents queue ahead of the display.
7. **`-setMaximumDrawableCount:`** — default 3; never varied.

## Reproduce / verify

```sh
cd /Users/larsde/src/koru-libs/clay/tests
/Users/larsde/src/koru/zig-out/bin/koruc -OReleaseFast spec_sel_live.k
./a.out
```

Drag the lower-right corner; watch the fixed boxes (left column, the thin
h:8 separators) vs the palette (right edge, appears only after Tab-selecting).
Baseline for "correct" = any native app (e.g. TextEdit) live-resizing.

Baseline commit for the plumbing: `d12d429` in koru-libs.
