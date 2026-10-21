---
type: belief
id: frag-package-source-is-only-as-relocatable-as-its-baked-paths
provenance: session
ts: 2026-10-21
---

A package's import spelling can be fully relative (`import libs/clay`
survives any move because `libs:` resolves per-config), while still being
non-relocatable in practice — because paths baked *inside* the package
resolve in a different court:

- `~std/build:requires` and `~std/compiler:requires` blocks are verbatim
  Zig spliced into the consumer's generated build.zig. A `.cwd_relative`
  or absolute path written there is evaluated at the *consumer's* build
  invocation — `clay`'s hardcoded `/Users/larsde/src/koru-libs/clay/
  clay_impl.c` compiled the old copy silently even after the package was
  checked out at `oshun/clay`. The compile only "passed" because the
  stale path still existed.
- Host-type qualifiers (`*koru/clay:Tree`, `! cmd koru/clay:CmdView`)
  are checked against the module name under which the *entry file*
  imported the declaring package — not the resolved directory. `koru/X`
  historically matched because it resolved to the same module, but the
  check fires on the qualifier name, and `libs/` is the convention every
  test config maps.

The relocation audit for any package move is therefore two greps, not
one: `cwd_relative|addCSourceFile` for baked filesystem paths, and
`[a-z]+/[a-z]+:` for qualifier spellings that must match the consumers'
import names. Emitted build files bake absolute paths by convention —
that is the toolchain's current norm, not a bug to fix in the lib — but
a package-relative `requires` primitive would retire this class entirely.
