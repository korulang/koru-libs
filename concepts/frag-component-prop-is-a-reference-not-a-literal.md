---
type: belief
id: frag-component-prop-is-a-reference-not-a-literal
provenance: ui/index.kz row-block emitter — probe_ctx_comp.k collision
  with std/ctx (2026-10-19)
ts: 2026-10-19
---

# A component prop is a value reference, not attribute text

`libs/oshun:component` markup carries two value kinds that share one syntax
surface: quoted literals (`fs="15"`) and props (`fs={{ fs:f }}`). Every
normalization the row emitter applies to attribute text must split on
that distinction, because a prop emits as a *reference to a declared tor
input* and literal-targeted transforms lie about it:

- f64 normalization (`15` → `15.0`) mangled a prop ident into `fs.0` —
  a tuple access that does not exist. Numeric normalization may only
  fire on literal-looking text.
- A prop whose value equals the column name (`fs={{ fs:f }}` emitting
  `fs: fs`) trips KORU161's mandatory punning — the emitter must unwrite
  the label and emit the bare pun.

The general shape: attribute text is writer input and can be normalized
freely; prop expressions are *program text* and pass through verbatim.
The moment a component prop flows into a generated row block it is code,
and code is not normalized — it is emitted.

## The attr rule is parts (2026-10-20)

The two value kinds are no longer all-or-nothing — a quoted value is a
*parts list*: `"{{ p:t }}"` spanning the whole value is still the bare
prop reference, but `lit{{ p:t }}lit` is a format, not a literal and not
a reference. It lowers through `fmt:ln`'s own lowered shape (the
transform pass has already run — oshun emits `ln.impl` + inline_body
directly), copies out through `from-page | ok → take : v`, and the row
field admits it only where the destination is textual: `v.data` into
`char[N]` (bytes copy, overflow truncates per 690_052) or `v` into a
`*String` column, with `free(v)` inside the row arm. A mixed value on a
numeric or otherwise non-text column leaves the decl unconsumed — loud
refusal, because stringifying a typed slot is the XAML mistake in
reverse. Dynamic IDs and templated labels are legitimate; silent
stringification is not.

## The scratch a format lands in is sized at the element (2026-10-20)

Every mixed value formats into the same per-site threadlocal scratch
`fmt:ln` uses — and since `[size(N)]` made that size a call-site
decision, markup gets its own spelling: `bufsize="16k"` on the element.
It is a *meta-attr* in `bind`'s class — consumed by the transform,
never a row field — and it sizes every mixed value that element emits,
no wider (per-call-site means per-element). The refusal culture holds
in both directions: a malformed size (`bufsize="xyz"`, zero, a `{{ }}`
reference — runtime-sized scratch is not a thing) refuses, and a
`bufsize` on an element with no mixed values refuses too, because a
silent no-op attr is the same lie as a silently-dropped one.
