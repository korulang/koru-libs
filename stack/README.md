# @korulang/stack

Declarative service stacks for Koru. The deployment graph is compile-time
data: declared in the same source as the program, checked before it
materializes, exported as docker-compose YAML.

Compose is an export format, not the source of truth — the Koru model is
richer (flag-erased variants, compile-checked edges) and governs downward.

## Installation

```koru
~import std/package
~std/package:requires.npm { "@korulang/stack": "^0.0.1" }
```

## Usage

```koru
~import koru/stack
~import std/build

// Values resolve through build:config — the flag decides which port ships.
[build("dev")]std/build:config {
    "web_port": "3000:3000"
}
[build("prod")]std/build:config {
    "web_port": "80:80"
}

koru/stack:service(db, image: "postgres:16") {
    "healthcheck": "pg_isready -U shop",
    "env": { "POSTGRES_DB": "shop" }
}

[depends_on("db")]koru/stack:service(web, image: "web:latest") {
    "port": "web_port",
    "env": { "DB_HOST": "db" }
}

// flag-gated: exists only under --build=dev
[build("dev")|depends_on("db")]koru/stack:service(debug_ui, image: "debug:latest") {
    "port": "9229:9229"
}

// a field-less service needs no block
koru/stack:service(cache, image: "redis:7")
```

## Commands

```bash
koruc app.kz stack manifest [--build=dev|prod]
```

Emits `compose.yaml` in the current directory. `up` and `down` are pending —
the imperative materialization reuses the same graph.

**Command position matters:** the command is the argument immediately after
the input file. `koruc app.kz --build=dev stack manifest` does a normal
build and silently ignores the command.

## What the compiler refuses

Everything `docker compose up` only discovers at runtime:

- **`depends_on` naming an undeclared service** — exit 1, names the missing
  service.
- **dependency cycles** — exit 1, names the services left unordered.
- **a service body that isn't valid JSON fields** — exit 1.
- **a service declaration without `name:`** — exit 1.

## Semantics

- **Edges** — `[depends_on("a", "b")]` on the declaration, the same
  annotation convention `std/build:step` uses. Topological order determines
  emission order.
- **Readiness** — a dep that declares `"healthcheck"` emits
  `condition: service_healthy`; without one, `service_started`.
- **Flag-erased values** — any string field naming a `build:config` key
  substitutes the flag-gated value; anything else is literal. `[build("x")]`
  gates whole declarations, so the graph's *shape* and its values both vary
  per flag — resolved before the artifact exists, never inside it.

## Tests

`stack/tests/` — exercised as real call sites via `koruc`:

- `app.k` — three services: `db` (healthcheck + env), `web` (`depends_on`,
  config-interpolated port), `debug_ui` (dev-gated). `koruc app.k stack
  manifest --build=dev` emits all three with edges; `--build=prod` drops
  `debug_ui` and resolves the port to `80:80`.
- `dangling.k` — refusal pin: edge to an undeclared service, exit 1.
- `cycle.k` — refusal pin: `a → b → a`, exit 1.
