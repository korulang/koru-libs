# FRONTIER — `vaxis:run` as a transform

## `! <arm> <ident>` bindings are invisible to `! query` capture — OPEN (2026-09-16)

`vaxis:run`'s generated `vaxis:step()` call carries the consumer's `!`
arms as continuations, so `! char k` binds `k` as an arm-pattern name.
A nested `std/store:query` subflow that references `k` emits a bare `k`
in its generated handler — `use of undeclared identifier 'k'` at
backend build. `! query` bindings DO capture into nested queries
(690_110 passes) — the gap is effect-arm payload bindings specifically;
the pre-transform run masked it by lowering payloads to local consts in
inline dispatch. Repro: `run_arm_capture.k` (KOPIUM `headed.k` shape).
Fix is koru-side: subflow input capture should see enclosing
continuation bindings, not just locals.
