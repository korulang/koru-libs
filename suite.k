// suite.k — koru-libs regression suite (v3: self-describing tests).
//
// Run:  koruc suite test
//
// A case: an `expr` label + a JSON `source` block (the flag.declare idiom).
// This is a RUNNER — cases point at standalone koru test programs; nothing here
// touches the koru toolchain. Expectations live INLINE in each test file as
// `//~` directives (run / compile_fail(stage) / error[…] pins / leaks: allow);
// the suite stays pure composition. "kind" here is retired and rejected.

import koru/regressions

koru/regressions:case(gzip round-trip) {
  "file": "gzip/tests/roundtrip.kz"
}

koru/regressions:case(gzip one-shot round-trip) {
  "file": "gzip/tests/oneshot_roundtrip.kz"
}

koru/regressions:case(gzip use-after-finish is rejected) {
  "file": "gzip/tests/deflate_use_after_finish.kz",
  "category": ["c-libs", "smoke"],
  "tags": ["phantom-obligations"]
}
