// koru/diag/sqlite — diagnostics-bus consumer living in koru-libs, not
// stdlib: `import koru/diag/sqlite` subscribes every backend diagnostic as a
// row in a SQLite db. The whole module is the join plus its link dep —
// `std/compiler:requires` targets the BACKEND build (build_backend.zig), the
// same requires door koru-libs packages use for user binaries via
// std/build:requires. No registration, no flags: the import IS the plugin.
import std/compiler

std/compiler:requires {
    exe.linkLibC();
    exe.linkSystemLibrary("sqlite3");
}

std/compiler(diagnostic)
! diagnostic d |> sqlite(d, path: "koru-diagnostics.db")
