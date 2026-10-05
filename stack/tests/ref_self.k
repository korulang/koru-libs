// Refusal pin: a service referencing itself — must refuse
// exit 1 naming the offending reference.

import libs/stack
libs/stack:service(api) {
    "image": "shop/api",
    "env": { "ME": "{{ api.name }}" }
}
