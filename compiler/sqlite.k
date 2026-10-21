// koru/compiler/sqlite — diagnostics-bus consumer in the external compiler
// toolkit: `import koru/compiler/sqlite` subscribes every backend diagnostic
// as a row in a SQLite db. The whole module is the join plus its link dep —
// `std/compiler:requires` targets the BACKEND build (build_backend.zig), the
// same requires door koru-libs packages use for user binaries via
// std/build:requires. No registration, no flags: the import IS the plugin.
//
// Sink settings are the consumer's `koru/compiler/sqlite:config` block —
// `db-file: "name.db"` (default koru-diagnostics.db) and `flush: true|false`
// (the fsync discipline: true = synchronous FULL per row, false = OFF —
// inserts still commit per row, only OS-level failure loses them).
import std/compiler

std/compiler:requires {
    exe.linkLibC();
    exe.linkSystemLibrary("sqlite3");
}

std/compiler(diagnostic)
! diagnostic d |> sqlite(d)
