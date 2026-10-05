// Stack declaration probe: Postgres + Redis behind one API.
// Exercises multiple datastore services, multiple depends_on edges on
// one consumer, and per-service healthchecks driving startup order.

import libs/stack
import std/build

[build("dev")]std/build:config {
    "api_port": "3000:3000"
}

[build("prod")]std/build:config {
    "api_port": "80:80"
}

libs/stack:service(pg) {
    "image": "postgres:16",
    "healthcheck": "pg_isready -U shop",
    "ports": ["5432:5432"],
    "env": { "POSTGRES_DB": "shop" }
}

libs/stack:service(cache) {
    "image": "redis:7-alpine",
    "healthcheck": "redis-cli ping",
    "ports": ["6379:6379"]
}

[depends_on("pg", "cache")]libs/stack:service(api) {
    "image": "shop/api",
    "port": "api_port",
    "env": {
        "DB_HOST": "pg",
        "DB_PORT": "5432",
        "REDIS_URL": "redis://cache:6379/0"
    }
}
