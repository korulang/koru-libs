---
type: belief
id: frag-ctx-is-a-scope-stack-resolved-once
provenance: ui/index.kz ctx transform — probe_ctx.k / probe_ctx_fail.k (2026-10-19)
ts: 2026-10-19
---

# Context injection is a scope stack resolved in one depth-first pass

`libs/ui:ctx(X)` is a compile-time scope: the transform walks the whole
program once, pushes X's scope while descending the ctx step's continuation
subtree, and fills every unfilled call parameter by searching the stack
innermost-out. Precedence is the one that fell out of shadowing — explicit
arg > innermost ctx > outward ctx > declared default > ordinary
missing-param refusal. Nothing checks a context at runtime; the emitted
call site just reads `call(a: inner.a, b: outer.b)` — injection is
argument-filling, not resolution, so the machine evaporates at compile
time.

The lesson is not the mechanism but the unification it proved: a theme, a
data context, and a DI scope are the same claim — "nearest enclosing scope
provides the field" — at two resolution times. `std/ctx` resolves into call
arguments at comptime (zero cost, services and config); a `ctx` column on a
spec row would resolve into view fields at expansion (live-switchable on a
one-write handle flip). Same semantics, different carriers.

Two toolchain facts the probe surfaced, both worth keeping: the transform
must declare `[pre]` and *no* `source` param — the site wrapper gates the
handler on every declared arg being present, so a `source: Source` the call
never supplies silently turns the transform into a no-op; and
whole-program handlers invoked on nested sites must drop the runner's
`site_of` siteView flow or the site's subtree emits twice.
