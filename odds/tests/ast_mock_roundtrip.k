// AST-mock roundtrip — the testing shape that replaces judge.mock.
// `koru/odds:feels => yes 0.9` substitutes the invocation with a branch
// constructor at compile time. `judge` itself is NOT mocked: issuing,
// fuel accounting, phantom modes and retire-discharge all run real —
// only the network ask is scripted.

import koru/odds
import std/testing

tor ask-urgency { m: string }
| urgent f64
| routine f64
| failed string

ask-urgency = koru/odds:judge(budget: 3): j |> koru/odds:feels(j, text: m, question: "urgent?")
| yes p => urgent p
| no p => routine p
| exhausted => failed "no fuel"
| err e => failed e.msg

test(urgent verdict routes urgent) {
    koru/odds:feels => yes 0.9
    ask-urgency(m: "disk full")
    | urgent p |> assert(p == 0.9)
    | routine _ |> assert.fail()
    | failed _ |> assert.fail()
}

test(routine verdict routes routine) {
    koru/odds:feels => no 0.2
    ask-urgency(m: "typo fix")
    | urgent _ |> assert.fail()
    | routine p |> assert(p == 0.2)
    | failed _ |> assert.fail()
}

test(exhausted judge names its outcome) {
    koru/odds:feels => exhausted
    ask-urgency(m: "whatever")
    | urgent _ |> assert.fail()
    | routine _ |> assert.fail()
    | failed msg |> assert(msg.len > 0)
}
