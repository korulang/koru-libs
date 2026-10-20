---
type: belief
id: frag-a-phantom-state-name-carries-a-lifecycle-policy
provenance: sqlite3 stream refactor, 2026-10-20 — `row!` single-token streams
  compiled `neg_row_leak` clean because release.row auto-discharged them;
  renamed the durable pull-model state `stream` to keep the obligation real
ts: 2026-10-20
---

# A phantom state name carries a lifecycle policy, not just a label (belief)

A `*T<name>` phantom looks like a state tag. It is actually a *policy*: the
name keys the set of tors that may discharge the obligation, and — through
the auto-discharge inserter — whether the debt can satisfy itself at scope
end without an explicit call.

Measured in sqlite3: `row` is the scoped-borrow state. `release.row` exists
as its unattended discharger (a no-op returning a bare borrow), so ANY
`*Statement<row!>` minted into a flow auto-releases at arm end — correct for
the `! row` effect path where the engine owns the statement, but a silent
leak hole for the pull model: a stream minted as `row!` and abandoned
compiled clean, the object and its owned connection lost. `stream` is the
durable-debt state: its only dischargers (`next`, `finalize.stmt`) are
unattended-excluded (branches / live `<opened!>` return), so a leaked stream
refuses at compile time — KORU030 naming the verbs that can spend it.

Consequence: one object under two lifecycle policies needs two state names,
and therefore two read surfaces. `col.*` reads `<row>` (effect path);
`scol.*` reads `<stream>` (pull path) — same helpers underneath.

RULED 2026-10-20, Lars: `scol.int` / `scol.text` / `scol.real` is the
sanctioned spelling for pull-model column reads. On the wire the register
alias papers over the split — `libs.sqlite3:scol.int -> col-int(1)` — so
the agent surface still reads `col-int`.

This corrects if the language ever gains a borrow-spelling that accepts a
handle regardless of state (or per-handle multi-state), which would let one
`col.*` serve both policies and retire the `scol.*` twins.
