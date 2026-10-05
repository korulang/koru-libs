// Stack declaration probe: db + web + a dev-only debug sidecar.
// Exercises service decls, depends_on edges, flag-gated declarations,
// and build:config port interpolation (dev=3000:3000, prod=80:80).

import libs/stack
import std/build

[build("dev")]std/build:config {
    "web_port": "3000:3000"
}

[build("prod")]std/build:config {
    "web_port": "80:80"
}

libs/stack:service(db) {
    "image": "postgres:16",
    "healthcheck": "pg_isready -U shop",
    "env": { "POSTGRES_DB": "shop" }
}

[depends_on("db")]libs/stack:service(web) {
    "image": "web:latest",
    "port": "web_port",
    "env": { "DB_HOST": "db" }
}

[build("dev")|depends_on("db")]libs/stack:service(debug_ui) {
    "image": "debug:latest",
    "port": "9229:9229"
}
