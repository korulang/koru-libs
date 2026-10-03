// Empty-body pin: a service whose `{}` body carries no fields. The
// original repro that surfaced two compiler defects — an empty Source
// block swallowed the following declaration (210_311/210_312), then
// emitted a dangling `.text =` splice (210_313). Both fixed in koru;
// this file keeps the consumer-level assertion: two services, both
// present, `a` bare, `b` carrying env.

import libs/stack

libs/stack:service(name: "a", image: "img:a") {
}

libs/stack:service(name: "b", image: "img:b") {
    "env": { "X": "1" }
}
