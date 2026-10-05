// Refusal pin: {{ ghost.name }} names no declared service — must refuse
// must exit 1 naming the offending reference.

import libs/stack
libs/stack:service(api, image: "shop/api") {
    "env": { "DATABASE_URL": "postgres://{{ ghost.name }}:5432/shop" }
}