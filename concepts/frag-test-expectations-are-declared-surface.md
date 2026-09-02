---
type: belief
id: frag-test-expectations-are-declared-surface
provenance: Lars pull on the //~ thread — expectations should be norun declarations, not comment directives (2026-09-02)
ts: 2026-09-02
---

# A test's expectations are declared program surface, adjacent to the //~ comment form (belief)

A test program declares its contract to the runner the way any program
declares anything: as typed, compiler-checked calls. `koru/regressions:run()`,
`:compile-fail(backend)`, `:error("KORU030", "…")`, `:expect("…")` are norun
declarations like `case` — collected into the AST, parsed, resolved, and
validated by the compiler itself. A typo is a compile error with a location;
an unknown marker is impossible. The runner walks the AST it already knows how
to walk.

The `//~` comment directives (ruled Lars 2026-07-17) are the ADJACENT spelling
of the same vocabulary — two live intakes, one validation wall, one spelling
per test (mixing is rejected with teaching). The comment form is the only one
that can express a frontend parse-error negative: a file that fails at the
frontend never materializes its AST, so it cannot declare its expectations as
program calls; the runner reads `//~ compile_fail(frontend)` from the file
text before compiling. The declared form is the sharper tool — compiler-checked
where the comment form is hand-parsed — but it does not replace the ruled
surface; it sits beside it.

Why it is nicer for actual Koru programs: the test file is a real program
whose surface is the language's own — the same mechanism `flag.declare`,
`command.declare`, and `case` already use. The runner's "can't drift"
guarantee moves from a bespoke lexer into the type system.

Verified 2026-09-02: a backend-fail compile still materializes the AST
(`program.ast.json` is written after the phantom failure), and invocations
serialize as `module_qualifier` + `segments` — walkable with the exact pattern
the runner already uses on suite.k's in-process AST.

Implemented the same day (commits after 3f20751): the tors exist
(`run`, `compile-fail(stage:)`, `error(id:, msg:)`, `expect(text:)`,
`expect-not(text:)`, `leaks-allow(reason:)` — koru-natural hyphenated names,
labeled args; the runner's overridable seam moved from `run` to `score` to
free the marker name after the duplicate-`run_event` measurement). The runner
drives koruc, deletes a stale `program.ast.json` first, then walks the fresh
one filtered by the file's own `source_module`. A typo'd marker is a real
compiler error (`KORU040 unknown tor`) at the backend stage; wrong arg labels
are `PARSE006` at the frontend. All 13 suite cases migrated; every red path
forced by sabotage (expect miss, expect-not violation, unpinned negative,
conflicting kind, no declarations, typo). The //~ intake was restored as a
live adjacent door after a first version retired it — the retirement was the
error, not the adjacency.

Open: the program.ast.json bridge as a compiler-serialization coupling and
what it costs if the format churns.
