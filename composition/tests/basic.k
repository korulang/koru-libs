// @korulang/composition — the scenario, asserted through the import surface.
//
// Same verse→chorus fixture the rdaw prototype ran: 120bpm, verse beats 0–32
// (0–16s), chorus nominally at beat 64 (32s — wrong on purpose), kick clip at
// beat 4 inside verse. comp.follow snaps chorus to verse end; shifting the
// leader re-resolves the follower. Then the projection half: a 50px/s view
// turns those seconds into Rects, and pan moves the window, not the world.

part expect
import koru/composition
import std/io

koru/composition:comp.new(): comp
|> koru/composition:tempo.new(bpm: 120.0, start: 0.0): tempo
|> koru/composition:timeline.new(comp, tempo, start: 0.0, start-beats: 0.0, duration: 0.0, beats: 32.0): verse
|> koru/composition:timeline.new(comp, tempo, start: 0.0, start-beats: 64.0, duration: 0.0, beats: 16.0): chorus
|> koru/composition:clip.new(tl: verse, start: 0.0, start-beats: 4.0, duration: 0.4, beats: null): kick
|> koru/composition:comp.follow(comp, follower: chorus, leader: verse, offset: 0.0): chorusb
|> koru/composition:comp.resolve(comp): comp1
|> koru/composition:resolve.timeline-end(tl: verse): vend
|> expect.eq(name: "verse end @120bpm", got: vend, want: 16.0)
|> koru/composition:resolve.timeline-start(tl: chorusb): cs
|> expect.eq(name: "chorus snapped to verse end", got: cs, want: 16.0)
|> koru/composition:resolve.clip-abs-start(tl: verse, clip: kick): ks
|> expect.eq(name: "kick abs start", got: ks, want: 2.0)
|> koru/composition:timeline.shift(tl: verse, delta: 4.0)
|> koru/composition:comp.resolve(comp: comp1): comp2
|> koru/composition:resolve.timeline-start(tl: chorusb): cs2
|> expect.eq(name: "chorus re-follows after shift", got: cs2, want: 20.0)
|> koru/composition:resolve.timeline-end(tl: verse): vend2
|> expect.eq(name: "verse end after shift", got: vend2, want: 20.0)
// ---- projection: the reusable half ----
|> koru/composition:view.new(width: 800.0, pps: 50.0): view
|> koru/composition:proj.timeline-rect(view, tl: verse, y: 10.0, h: 20.0): vr
|> expect.eq(name: "verse rect x (post-shift)", got: vr.x, want: 200.0)
|> expect.eq(name: "verse rect w", got: vr.w, want: 800.0)
|> koru/composition:proj.clip-rect(view, tl: verse, clip: kick, y: 10.0, h: 20.0): kr
|> expect.eq(name: "kick rect x (post-shift)", got: kr.x, want: 300.0)
|> expect.eq(name: "kick rect w", got: kr.w, want: 20.0)
|> koru/composition:view.pan(view, dx-seconds: 4.0)
|> koru/composition:proj.x(view, seconds: 20.0): px
|> expect.eq(name: "panned playhead x", got: px, want: 800.0)
|> koru/composition:view.zoom(view, factor: 2.0)
|> koru/composition:proj.x(view, seconds: 20.0): px2
|> expect.eq(name: "zoomed playhead x", got: px2, want: 1600.0)
|> expect.summary(): fails
|> std/io:print.ln("failures: {{ fails:d }}")
|> koru/composition:timeline.release(comp: comp2, tl: chorusb)
|> koru/composition:timeline.release(comp: comp2, tl: verse)
|> koru/composition:comp.free(comp: comp2)
