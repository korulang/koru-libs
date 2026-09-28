---
type: belief
id: frag-a-presence-claim-is-a-missing-config-field
provenance: vaxis `! tick _ |> _` banned when KORU037 widened to transform flows — the arm was config, not a handler (2026-09-28)
ts: 2026-09-28
---

# A presence claim is a missing config field

When a consumer arms an optional branch with a body that means nothing —
`! tick _ |> _` — the arm is not a handler. It is the consumer reaching for
a knob the library did not put on the signature. Vaxis's `tick` presence
armed a 16ms repaint deadline through `@hasDecl(__H, "tick")`: the deadline
was real work, and the no-op arm was the only spelling that reached it.

The arm's *body* is discardable; the arm's *presence* is not. Koru's
no-op rules (KORU037/KORU054) correctly refuse the body — and a library
that only offers presence-via-arm leaves the consumer no honest spelling
once the body is banned. The fix is not a carve-out; it is to split the
concern where it lives: behavior the consumer configures goes on the input
declaration (`tick_ms: 16` on `run`/`init`), while the `!` arm remains for
consumers who actually handle the beat.

The tell is general: if the only way to switch a library feature on is to
name an arm you then empty, the feature is a parameter, not a handler.
Design the signature so `@hasDecl` means "the consumer handles this" and
config means "the consumer wants this" — conflating them is what forced
the fake arm.
