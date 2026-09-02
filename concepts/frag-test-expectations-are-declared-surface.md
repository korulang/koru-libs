---
type: belief
id: frag-test-expectations-are-declared-surface
provenance: Lars pull on the //~ thread — expectations should be norun declarations, not comment directives (2026-09-02)
ts: 2026-09-02
---

# A test's expectations are declared program surface, not comment directives (belief)

A test program declares its contract to the runner the way any program
declares anything: as typed, compiler-checked calls. `koru/regressions:run()`,
`:compile-fail(backend)`, `:error("KORU030", "…")`, `:expect("…")` are norun
declarations like `case` — collected into the AST, parsed, resolved, and
validated by the compiler itself. A typo is a compile error with a location;
an unknown directive is impossible. The runner stops hand-parsing comments and
walks the AST it already knows how to walk.

The `//~` comment directive survives only where it is structurally forced:
frontend parse-error negatives, whose AST never materializes. That is the one
true necessity. The other two reasons `//~` existed — the Rust/Clang inline-
comment convergence, and a "language-agnosticism" the koru-only runner never
actually had — are both dead.

Why it is nicer for actual Koru programs: the test file is a real program
whose surface is the language's own — the same mechanism `flag.declare`,
`command.declare`, and `case` already use. The runner's "can't drift"
guarantee moves from a bespoke lexer into the type system.

Verified 2026-09-02: a backend-fail compile still materializes the AST
(`program.ast.json` is written after the phantom failure), and invocations
serialize as `module_qualifier` + `segments` — walkable with the exact pattern
the runner already uses on suite.k's in-process AST.

Open: the exact tor spellings (compile-fail / expect / expect-not / error /
leaks-allow names); the frontend-negative residue's vehicle (`//~` kept as a
narrow exception, or deferred — the current corpus has zero frontend
negatives); the program.ast.json bridge as a compiler-serialization coupling
and what it costs if the format churns.
