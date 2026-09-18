---
type: belief
id: frag-the-callback-boundary-is-a-mailbox-not-a-call
provenance: koru-libs metal — KoruMetalView IMPs to a ring to the frames
  drain; a human ESC keypress reached `! key-down` (2026-09-18)
ts: 2026-09-18
---

# The callback boundary is a mailbox, not a call (belief)

`__H` is splice-position-only — a rule already held for *internal*
forwarding (frag-a-proc-cannot-forward-the-call-site-splice-surface). The
same rule closes the *external* boundary harder: a C-ABI callback — an
ObjC IMP, a delegate method, an audio render proc — can never reach a
Koru effect arm at all. It has no call site; there is no `__H` to name.

So the boundary is decoupled by construction, not by convention. The
native side pushes a payload into a queue the module owns; the proc that
holds the splice — the loop the arms hang on — drains the queue and calls
the arms as ordinary effect calls. vaxis's watcher-thread + wake-pipe is
the same shape mirrored (a C condvar the pump cannot poll becomes a byte
on an fd the pump can); metal's IMP-to-ring is the incoming direction.

Consequences:

- **Native callbacks are `! ?` optional arms, full stop.** `when` guards
  classify at the binding site; unbound arms cost a generated no-op; the
  dispatch switch lives where the emitter can see `__H`.
- **Subclassing is library code.** `objc_allocateClassPair` /
  `class_addMethod` need nothing from the compiler — the IMP is a module
  fn that writes the mailbox, carrying no Koru knowledge.
- **The interesting question is who owns the splice.** Callbacks that
  fire off the loop's own thread (audio render, async delegates) still
  work — the ring must merely be safe under that caller; the dispatch
  site never moves.

Open: real-time producers (Core Audio's render proc cannot allocate or
lock) want a wait-free ring, not the plain bounded ring that suffices
for UI events — a constraint on the mailbox, not on the pattern.
