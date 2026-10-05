// Stack lifecycle probe: a real `stack up` needs a pullable image.
// Pins the up/down/logs subcommands against the live daemon.

import libs/stack

libs/stack:service(cache) {
    "image": "redis:7-alpine",
    "healthcheck": "redis-cli ping",
    "port": "6379"
}
