// Refusal pin: {{ db.* }} where db is gated out of the active build
// must exit 1 naming the offending reference.

import libs/stack
[build("dev")]libs/stack:service(name: "db", image: "postgres:16") {
    "ports": ["5432:5432"]
}
libs/stack:service(name: "api", image: "shop/api") {
    "env": { "DB": "{{ db.host }}:{{ db.port }}" }
}