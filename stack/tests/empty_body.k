// Refusal pin: a service whose `{}` body carries no fields declares no
// spec — "image" is required (a `run:` arm will make it either/or).
// The empty-body shape itself is what surfaced 210_311/210_312/210_313
// upstream; this file now pins the semantic refusal on top of it.

import libs/stack

libs/stack:service(a) {
}
