---
type: belief
id: frag-stack-references-derive-the-edge
provenance: koru/stack two-pass collector — a {{ svc.field }} in a service body records the depends_on edge it means (2026-10-04)
ts: 2026-10-04
---

# A stack reference derives the dependency edge

`koru/stack` service bodies interpolate `{{ svc.field }}` — naming another
declared service inside a value IS the `depends_on` edge. There is no second
declaration to disagree with the usage: the collector runs two passes (fields
resolve env/config roots first; service refs read the resolved fields second),
each `{{ svc.f }}` records an edge, and the existing topo sort owns cycles.

The surface a service exposes to references is small and typed by position:
`name`/`host` (compose DNS name), `port` (container side — what a peer on the
network dials), `host_port` (the published mapping), `image`. Everything else
is a named refusal: unknown root, unknown field, unset `env.*`, a config key
the active build doesn't define, a self-reference, and a reference to a
service the active `--build` gates out — the last is a compile-time version
of what deploy-time `NullReferenceException` is elsewhere.

`{{ "X" | env_late }}` emits `${X}` verbatim — deploy-time deferral spelled
through the Liquid vocabulary rather than smuggled as raw passthrough.

Open: `{% %}` logic tags are refused in service bodies (substitution only);
a `run:` process arm would resolve `svc.port` differently (host port on
loopback vs container port on the compose network) — the placement rule is
acknowledged but not yet implemented.
