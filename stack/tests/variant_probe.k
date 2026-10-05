// Variant-selection probe: db has a base decl plus |dev and |prod
// redefinitions. --build=dev selects the |dev spec (full replacement, not a
// merge); no flag selects the base. api's {{ db.image }} resolves against
// whichever variant won — the reference tracks the selected spec.

import libs/stack

libs/stack:service(db) {
    "image": "postgres:16"
}

libs/stack:service(db)|dev {
    "image": "postgres:16-dev"
}

libs/stack:service(db)|prod {
    "image": "registry.internal/db:release"
}

libs/stack:service(api) {
    "image": "shop/api",
    "env": { "DB_IMG": "{{ db.image }}" }
}
