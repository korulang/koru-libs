// Refusal pin: a depends_on edge naming an undeclared service.
// `koruc dangling.k stack manifest` must exit 1 with
// "no service named 'missing' is declared" — the graph is compile-time
// data; a dangling edge is a refusal, never a runtime surprise.

import libs/stack

[depends_on("missing")]libs/stack:service(name: "web", image: "web:latest")
