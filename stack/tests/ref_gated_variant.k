// Refusal pin: api references {{ db.image }} but db exists ONLY as a |dev
// decl — under --build=prod (or any non-dev build) the reference names a
// service the active build gates out. Expected: stack refuses naming both.

import libs/stack

libs/stack:service(api) {
    "image": "shop/api",
    "env": { "P": "{{ db.image }}" }
}

libs/stack:service(db)|dev {
    "image": "postgres:16-dev"
}
