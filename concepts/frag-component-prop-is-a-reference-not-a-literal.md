---
type: belief
id: frag-component-prop-is-a-reference-not-a-literal
provenance: ui/index.kz row-block emitter — probe_ctx_comp.k collision
  with std/ctx (2026-10-19)
ts: 2026-10-19
---

# A component prop is a value reference, not attribute text

`libs/ui:component` markup carries two value kinds that share one syntax
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
