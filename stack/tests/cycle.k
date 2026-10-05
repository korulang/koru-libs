// Refusal pin: a depends_on cycle. `koruc cycle.k stack manifest` must
// exit 1 with "depends_on cycle involving: a b" — topological ordering
// cannot emit either side, so the leftover set names the cycle.

import libs/stack

[depends_on("b")]libs/stack:service(a, image: "img:a")
[depends_on("a")]libs/stack:service(b, image: "img:b")
