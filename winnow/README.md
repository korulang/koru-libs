# @korulang/winnow

Result shaping for agent-facing tool output. A command runs; winnow
decides what the model sees — a per-command grammar of line filters,
exit-keyed statics, diffs, and judged summaries, applied at the
tool-result boundary.

The design and the full planned surface live in
[`DESIGN.md`](DESIGN.md). What is implemented is what is in
`index.kz` — nothing else is claimed.

## v0 surface

```koru
~import koru/winnow

// line ops — subslice returns, no allocation
koru/winnow:tail(text: output, lines: 120)
koru/winnow:head(text: output, lines: 50)
koru/winnow:below(text: output, marker: "failing tests:")
koru/winnow:dedup(text: output)

// regex ops — bare patterns; winnow wraps whole-line, compiles, frees.
// `ok` carries an owned *std/string:String<view!> — caller frees.
koru/winnow:extract.lines(pattern: "FAIL|Error", text: output)
koru/winnow:remove.lines(pattern: "^ok ", text: output)
koru/winnow:grep(pattern: "panic", text: output)   // | yes | no | err
```

Designed but not yet lifted (see DESIGN.md): `replace` over
`koru/pcre2`, `diff` (pure-Koru Myers), `apply` (the profile
compositor), `summarize` over `koru/ai` with `koru/odds` as the
escalation gate, and `profile.load`/`free` for the shapes grammar.

## Doctrine

Passthrough is honest, not a fallback — a profile that claims nothing
returns `raw` and the caller routes on it. Summarize calls the model
or errs; a heuristic is never allowed to masquerade as a summary.
Winnow decides what the model sees; where the full output goes is the
caller's contract.
