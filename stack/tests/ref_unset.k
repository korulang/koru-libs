// Refusal pin: {{ env.X }} with X unset in .env and process env
// must exit 1 naming the offending reference.

import libs/stack
libs/stack:service(name: "api", image: "shop/api") {
    "env": { "WHO": "{{ env.DEFINITELY_UNSET_XYZ }}" }
}