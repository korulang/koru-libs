// Stack reference probe: api's env names db through {{ db.* }} — the
// reference derives the depends_on edge and resolves against db's
// declared fields. env_late defers a secret to the deploy host.

import libs/stack

libs/stack:service(db) {
    "image": "postgres:16",
    "healthcheck": "pg_isready -U shop",
    "ports": ["5432:5432"],
    "env": { "POSTGRES_DB": "shop", "POSTGRES_PASSWORD": "{{ \"DB_PASS\" | env_late }}" }
}

libs/stack:service(api) {
    "image": "shop/api",
    "ports": ["3000:3000"],
    "env": {
        "DATABASE_URL": "postgres://{{ db.name }}:{{ db.port }}/shop",
        "PGUSER": "{{ env.PG_USER }}"
    }
}
