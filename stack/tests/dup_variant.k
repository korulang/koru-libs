// Refusal pin: two declarations share (name, variant) — the db slot is
// claimed twice for the same build. Expected: stack refuses naming 'db'.

import libs/stack

libs/stack:service(db) {
    "image": "postgres:16"
}

libs/stack:service(db)|dev {
    "image": "postgres:16-dev"
}

libs/stack:service(db)|dev {
    "image": "postgres:16-dev2"
}
