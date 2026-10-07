# Board — rung 2: protocol + error surface (oracle state)

Pinned 2026-10-07, koru-libs main, orisha main `b8bd38a` (typed TLS pump).
All fixtures captured from topcoat v0.10.0 and **self-certified** — the
closer replays each spec against the reference and passes every row.
Conform = claimant exists and closes; oracle = golden + closer only.

| fixture | cases | oracle | conform | notes |
|---|---|---|---|---|
| websocket | 9 | yes | unmeasured | 101 + masked frames + ping/pong + close-echo + 400 no-upgrade; needs `ConnState.mode` + `! frame` arm + `ws-accept`/`ws-send` |
| error | 8 | yes | unmeasured | branded 403/404 boundary, `module_param` 400, internal rewrite — all authored-arm-reachable today |
| manual-router | 6 | yes | unmeasured | same tree as module-router via explicit `.page()`/`.route()` — conformance pair |
| sse | 3 | yes | unmeasured | finite `job` + bounded `ticks` + `last-event-id` resume; chunked decode in closer; needs conn-outlives-answer write side |
| asset | 3 | yes | unmeasured | `/_topcoat/assets/<hash>` + immutable cache-control; no png compression |
| cookie | 1 | yes | unmeasured | volatile set-cookie signature masked, attributes pinned; round-trip needs a stateful closer |
| session | 3 | yes | unmeasured | 303 + volatile session cookie; login form field `name` |
| app-context | 1 | yes | unmeasured | counter masked via volatile-pattern |

Totals: 36 oracle rows captured + self-certified across 8 fixtures
(rung-1's 29 run separate, still green on merged main).

Deferred with reasons in goldens/CAPTURE.md: routerless (no server),
JS/runtime-shell examples (client-side behavior), cookie/session
round-trips (stateful-sequence closer format gap — recorded).
