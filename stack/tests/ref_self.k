// Refusal pin: a service referencing itself — must refuse
// must exit 1 naming the offending reference.

import libs/stack
libs/stack:service(name: "api", image: "shop/api") {
    "env": { "ME": "{{ api.name }}" }
}