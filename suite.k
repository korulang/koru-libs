// suite.k — koru-libs regression suite (v3: self-describing tests).
//
// Run:  koruc suite test
//
// A case: an `expr` label + a JSON `source` block (the flag.declare idiom).
// This is a RUNNER — cases point at standalone koru test programs; nothing here
// touches the koru toolchain. Expectations live INLINE in each test file, in
// one of two adjacent spellings: declared norun markers collected from the
// test's own AST (koru/regressions:run() / :compile-fail(stage:) / :error(…) /
// :expect(…) / :leaks-allow(…); bare in a pure `.k`, `~`-prefixed in a host-
// embedded `.kz`/`.kjs`), or `//~` comment directives. A file uses one, never
// both. The suite stays pure composition. "kind" here is retired and rejected.

import koru/regressions

koru/regressions:case(gzip round-trip) {
  "file": "gzip/tests/roundtrip.kz"
}

koru/regressions:case(gzip one-shot round-trip) {
  "file": "gzip/tests/oneshot_roundtrip.kz"
}

koru/regressions:case(gzip use-after-finish is rejected) {
  "file": "gzip/tests/deflate_use_after_finish.k",
  "category": ["c-libs", "smoke"],
  "tags": ["phantom-obligations"]
}

koru/regressions:case(signal external tick) {
  "file": "signal/tests/external_tick/input.kz",
  "category": ["c-libs", "signal"],
  "tags": ["signal-processing", "external-clock"]
}

koru/regressions:case(signal init surface) {
  "file": "signal/tests/init_surface/input.kz",
  "category": ["c-libs", "signal"],
  "tags": ["signal-processing", "transform"]
}

koru/regressions:case(signal tick surface) {
  "file": "signal/tests/tick_surface/input.kz",
  "category": ["c-libs", "signal"],
  "tags": ["signal-processing", "transform"]
}

koru/regressions:case(signal reference surface) {
  "file": "signal/tests/reference_surface/input.kz",
  "category": ["c-libs", "signal"],
  "tags": ["signal-processing", "transform"]
}

koru/regressions:case(signal tick before init) {
  "file": "signal/tests/tick_before_init/input.k",
  "category": ["c-libs", "signal"],
  "tags": ["signal-processing", "error-path"]
}

koru/regressions:case(signal shape surface) {
  "file": "signal/tests/shape_surface/input.kz",
  "category": ["c-libs", "signal"],
  "tags": ["signal-processing", "shape"]
}

koru/regressions:case(signal model spine) {
  "file": "signal/tests/model_spine/input.kz",
  "category": ["c-libs", "signal"],
  "tags": ["signal-processing", "authoring"]
}

koru/regressions:case(signal two models) {
  "file": "signal/tests/two_models/input.kz",
  "category": ["c-libs", "signal"],
  "tags": ["signal-processing", "registry"]
}

koru/regressions:case(signal breath only build) {
  "file": "signal/tests/breath_only_build/input.kz",
  "category": ["c-libs", "signal"],
  "tags": ["signal-processing", "build"]
}

koru/regressions:case(signal two models build) {
  "file": "signal/tests/two_models_build/input.kz",
  "category": ["c-libs", "signal"],
  "tags": ["signal-processing", "build"]
}

