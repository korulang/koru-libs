# koru/winnow — DESIGN

Status: draft, 2026-09-26. Seeds the package; argues the surface before the
code argues back.

## What it is

**Result shaping for agent-facing tool output.** A command runs, produces
stdout+stderr+exit, and something decides what the model actually sees.
Winnow is that decision, expressed as a per-command grammar applied at the
tool-result boundary — inside the harness or scope proc, not wrapped around
a shell.

This is the revival of `COCPORN/sidetrack` (2025): same compression ladder,
different layer. The old tool was a PTY shim that monkey-patched a shell the
agent thought it owned — brittle by construction (session drift, alias
interference, the agent blind to its own output being compressed). Winnow
keeps the grammar and the ladder; it drops the shell.

## The ladder

Five tiers, cheapest first. A profile composes some prefix of them.

| tier | mechanism | cost | implementation |
|---|---|---|---|
| 1. filters | regex/string ops on lines | ~0 | `pcre2` + pure-Koru string ops |
| 2. static | exit-code-keyed canned reply | 0 | data, no proc |
| 3. diff | delta vs previous result, same command key | ~0 | pure-Koru Myers (exercises the compiler, not a C lib) |
| 4. summarize | semantic compression of survivors | one cheap call | `koru/ai` (Jev-class chat model) |
| 5. escalate | "is the summary enough?" | one judgment | `koru/odds` — `when p >= 0.8` IS the gate |

Tier 5 is the upgrade over the original design: sidetrack's tail-first pass
carried `confidence_threshold: 0.75` as a bare env-var float. In winnow the
gate is a typed `odds` judgment — the branch set is the answer space, the
payload is calibrated probability, and escalation is a named branch, not a
fallback.

**Passthrough is not a fallback.** `apply` returns `| raw` when no profile
claimed the command — that is an honest answer the caller routes on, never
a degraded output dressed as a shaped one. Loud, named, type-visible.

## Surface (proposed tors)

```koru
// tier 1 — line ops (pure string, shipped in v0)
~pub tor head  { text: string, lines: i64 } -> string
~pub tor tail  { text: string, lines: i64 } -> string
~pub tor below { text: string, marker: string } -> string
~pub tor dedup { text: string } -> string

// tier 1 — regex ops (compose koru/pcre2 at flow level, shipped in v0).
// Callers hand a BARE pattern; winnow wraps it whole-line (`(?m)^.*(?:P).*$`,
// inverted for remove), compiles, scans once via `find.all`, and frees.
~pub tor extract.lines { pattern: string, text: string }
| ok *std/string:String<view!>
| err string
~pub tor remove.lines  { pattern: string, text: string }   // same branches
~pub tor grep          { pattern: string, text: string }
| yes | no | err string
// ~pub tor replace  — not yet lifted; needs a replace primitive or
// match-offset reconstruction over pcre2

// tier 3 — delta (pure Koru Myers)
~pub tor diff { prev: string, next: string, sorted: bool } -> string

// the compositor — applies a profile's ladder
~pub tor apply { prof: *Profile<loaded>, command: string, output: string,
                 exit: i32, prev: ?string }
| shaped string
| raw    string      // no tier claimed it — honest, routed
| err    Err

// profiles
~pub tor profile.load { text: string }   // parse a shapes doc
| ok *Profile<loaded!>
| err Err
~pub tor profile.free { prof: *Profile<!loaded> }
```

`profile.load` takes the doc as text (parsed via `yyjson` or a compiled
table — decided at lift time). `*Profile<loaded!>` mints the obligation;
`profile.free` discharges it. Same shape as pcre2's compile/free.

Open: whether `apply` owns the prev-output cache (a `*Session`) or the
caller threads `prev`. v0 threads it — kopium sessions already hold state
in the bridge; a second cache inside the library duplicates authority.

## The profiles grammar

Cleaned port of sidetrack's `profiles.json`. One doc, profiles keyed by
command class:

```json
{
  "profiles": {
    "npm-test": {
      "match": "^npm (run )?test\\b",
      "exit": {
        "0":  { "static": "✅ All tests passed" },
        "*":  { "filters": [
                  { "op": "extract", "pattern": "FAIL|PASS|✓|✗" },
                  { "op": "extract", "pattern": "Error:|TypeError:|Expected" },
                  { "op": "head",    "lines": 50 }
                ],
                "summarize": { "threshold": 1500, "gate": "coverage" } }
      },
      "diff": { "sorted": true }
    }
  }
}
```

- `match` — regex over the command line; used when the caller is a generic
  `exec`. A scope verb (`test(path)`) skips `match` entirely — the profile
  is named in the verb's own declaration. Same grammar, two binding modes.
- `exit` — exit-class overrides; `0`/`1`/`*` keys, sidetrack semantics.
- `static` — tier 2; replaces output entirely. Only legal under an exit
  key, never bare (a canned reply for a command that *failed* is the lie
  this package exists to prevent).
- `filters` — ordered ops: `remove`, `replace`, `extract`, `dedup`,
  `head`, `tail`, `below`.
- `diff.sorted` — sort lines before diffing (order-independent runs).
- `summarize.gate` — names the `odds` judgment that gates tier 4→full.

## Consumers

- **kopium** — scope procs call `winnow:apply` where `libs.kz` hand-rolls
  `reportTail` today. Longer term: a `shape:` clause in the register block
  derives per-verb profiles — the fifth derived surface — but the package
  ships before that machinery; verbs call it directly.
- **pi** — the JS port (`@korulang/winnow` schema shared) post-processes
  `bash.ts` results where pi truncates to last-N-lines today.
- **sidetrack-test-suite** — revived as the conformance harness: one
  profiles doc, two implementations, measured parity.

## The one known gap

`std.process.Child.run` is batch-only. The interactive case (spawn a game,
drive a TUI) needs spawn-as-handle — `spawn`/`send`/`read`/`kill` over a
possession-shaped `*Child<running>`. That is a std.process extension, not
winnow's to build; winnow shapes output, it does not own processes.

## Doctrine

- **No substitute shaping.** Summarize calls the model or errs; a heuristic
  masquerading as a summary is the banned move. (Same family as koru/odds'
  `single-judgment-surface` invariant — ship one here too.)
- **Full output is never destroyed.** Winnow returns the shaped text; where
  the raw goes is the caller's contract (kopium writes it to the world,
  pi writes a temp file). The library doesn't hide the original, it
  answers "what should the model see."
- **The grammar is the artifact.** Engines port; `match`/`exit`/`filters`/
  `diff`/`summarize` semantics are the spec both implementations conform to.
