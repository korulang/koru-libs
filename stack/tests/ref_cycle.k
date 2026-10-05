// Refusal pin: a↔b through {{ }} references — the derived edges
// must exit 1 naming the offending reference.

import libs/stack
libs/stack:service(name: "a", image: "img:a") {
    "env": { "NEED": "{{ b.name }}" }
}
libs/stack:service(name: "b", image: "img:b") {
    "env": { "NEED": "{{ a.name }}" }
}