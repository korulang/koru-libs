---
type: belief
id: frag-module-emission-follows-invocation
provenance: measured 2026-11-12 extracting a package whose Zig internals consume a sibling's emitted struct (rails ← yyjson)
ts: 2026-11-12
---

# A module's Zig lands in the emitted root only when one of its tors is invoked — emission follows invocation, not import (belief)

The generated program root (`output_emitted.zig`) declares
`pub const koru_<ns>.koru_<mod>` for a module **iff some tor of that module is
invoked** in the program's flow graph. A bare `import koru/yyjson` — in a `.k`
contract, in a `.kz` impl, or in the entry file — emits nothing.

Verified 2026-11-12 against `rails/tests/`: the test file carried
`~import koru/yyjson` and the package's `index.k` carried `import koru/yyjson`,
yet `root.koru_koru` emitted no `koru_yyjson` member; the package's
`@import("root").koru_koru.koru_yyjson` failed at the Zig stage. Adding a
`koru/yyjson:parse` invocation wired it.

## What follows

- A package whose `.kz` internals consume a sibling package's emitted
  struct cannot declare that dependency. `import` is a name-scope act, not
  an emission act; the Zig-internal dep is invisible to the toolchain.
- The corpus works around this silently: once-campfire's `signing` module
  parses envelopes via yyjson because `cable` happens to invoke
  `koru/yyjson:parse`. Remove cable's call and the build breaks two modules
  away from the cause.
- The honest consumer-side discipline until the gap closes: a consumer of
  the verify tors invokes at least one `koru/yyjson` tor itself.

## Open question

What should declare this? A `~import` variant that forces emission, a
package-level `requires.module` in the deps vocabulary, or emission
computed from `.kz`-internal `@import` references. The package is the
instrument; the gap is the toolchain's.
