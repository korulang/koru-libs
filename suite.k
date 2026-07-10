// suite.k — koru-libs regression suite (v2: JSON-block DSL).
//
// Run:  koruc suite test
//
// A case: an `expr` label + a JSON `source` block (the flag.declare idiom).
// This is a RUNNER — cases point at standalone koru test programs; nothing here
// touches the koru toolchain.

import koru/regressions

koru/regressions:case(gzip round-trip) {
  "file": "gzip/tests/roundtrip.kz",
  "kind": "run"
}

koru/regressions:case(gzip one-shot round-trip) {
  "file": "gzip/tests/oneshot_roundtrip.kz",
  "kind": "run"
}

koru/regressions:case(gzip use-after-finish is rejected) {
  "file": "gzip/tests/deflate_use_after_finish.kz",
  "kind": "compile_fail",
  "category": ["c-libs", "smoke"],
  "tags": ["phantom-obligations"]
}
