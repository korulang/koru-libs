---
type: belief
id: frag-a-proc-cannot-forward-the-call-site-splice-surface
provenance: vaxis `run` — the hand-written driver needed to hand the call's
  `!` arms to `step_event.handler(.{}, __H)`, and `__H` is not a value (2026-09-16)
ts: 2026-09-16
---

# A proc cannot forward the call-site splice surface (belief)

Effect-arm splicing gives a proc a name for the call site's `!` arms — `__H`,
the handler struct — usable exactly once, *in the splice position of the call
it implements*. The moment a lifecycle wants two pieces — an outer proc that
owns the loop and an inner unit that owns the dispatch — the outer proc needs
to FORWARD the arms, and it cannot: `__H` is not a value. There is no
`step_event.handler(.{}, __H)` to write; the struct exists only where the
emitter is looking at the call site.

So the composition a proc cannot express, a generated call site expresses
trivially. The fix is never "give the proc a way to name `__H`" — it is to
move the call into a context where `__H` exists: a transform emits a generated
unit (`vaxis:step() <the call's ! arms>`) and the emitter splices the arms
there the same way it does for authored code. The transform does not dodge
the splice-surface rule; it relocates the call into the one place the rule
admits.

The consequence for library shape: **a lifecycle driver that must carry
consumer `!` arms is a transform, not a proc.** `vaxis:run` hand-spelled its
init/step/live/wait/deinit loop for months because step's dispatch needed
the arms; the day `run` became a transform emitting the pump composition
itself, the duplicated middle was deleted and `run` IS the composition.
Anywhere a hand-written loop carries a second copy of dispatch code "because
the arms cannot be passed on," the copy is the tell — the loop wants to be a
generated call.

Open: whether `__H`-as-value is a language feature worth wanting at all. The
generated-site route covers every case found so far, and making the splice
surface a first-class value would expose the emitter's representation as API.
