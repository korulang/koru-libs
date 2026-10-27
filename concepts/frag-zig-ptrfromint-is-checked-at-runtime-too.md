---
type: belief
id: frag-zig-ptrfromint-is-checked-at-runtime-too
provenance: once-campfire-koru probe, 2026-10-04 — first {{text}} bind through
  sqlite3's bindValue panicked `incorrect alignment` on a DEBUG build; the
  workaround comment in index.kz asserted the check was comptime-only
ts: 2026-10-04
---

# Zig's @ptrFromInt alignment check fires at runtime, not just comptime (belief)

A magic-pointer C sentinel — `SQLITE_TRANSIENT`, `(destructor_type)-1` — cannot
be spelled through `@ptrFromInt(maxInt(usize))`. Zig checks the address against
the target pointer's alignment at comptime *and* at runtime in safety-checked
build modes; `maxInt` is misaligned for any pointer type, so the cast panics
the first time it executes. Defeating comptime evaluation with a `var` local
only moves the failure from compile to run — the old comment in
`sqlite3/index.kz` asserted "the check is comptime-only," and that premise was
wrong.

Nor does `@bitCast` rescue it: fn-pointer types are not legal bitcast targets
in Zig 0.15, and translate-c's own emitted spelling
(`c_translation.cast` → `@ptrFromInt`) hits the same wall — meaning
`c.SQLITE_TRANSIENT` exists in cimport but is unusable as a constant.

The working shape: declare the extern with the parameter typed `usize` and pass
`std.math.maxInt(usize)` directly. A C sentinel is a pointer-sized integer, not
a function — the `usize` param is the honest ABI description and no cast is
ever attempted. `@extern(.{.name = "sqlite3_bind_text"})` keeps the real symbol
name while the local name reads clean.

General rule for binding C APIs: when the header defines a magic pointer value
`(T)-1`, `(T)0`, `(T)-2`, do not reach for pointer casts — widen the extern's
parameter to `usize` (or `[*c]const u8`/`*anyopaque` where the callee only
compares or stores it) and let the integer be what it is.
