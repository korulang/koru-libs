// map_decode — the ask/decode split, exercised without a network.
//
// `fixture` is a local tor standing in for the wire: test()
// substitutes it with a scripted FeelsDist, then the REAL decoders —
// `feels.pick` (greedy argmax) and `feels.draw` (chaotic sample) — run
// over it. `judge` is never mocked: issuing, fuel, phantoms and the
// auto-inserted retire all run real.
//
// Why not `koru/odds:feels.map => map { ... }`? Cross-module mock
// substitution is a pinned compiler gap — the emitter writes the mock
// as a dead sibling while calls resolve to the nested module copy
// (regression 395_009_cross_module_mock: FAILURE, "never green").
// ast_mock_roundtrip.k is red for the same reason. A same-module
// producer mock is the supported spelling (395_008: SUCCESS).
//
// `dry-run` exercises the real `feels.map` offline: budget 0
// short-circuits to `| exhausted` before any socket is opened.

import koru/odds
import std/testing

tor fixture { } -> koru/odds:FeelsDist

tor judge-mail { m: string }
| urgent f64
| routine f64
| failed string

judge-mail = koru/odds:judge(budget: 3): j |> fixture(): d |> koru/odds:feels.pick(j, d)
| yes p => urgent p
| no p => routine p
| err e => failed e.msg

// Sampled decode through a chaotic judge — same dist, other policy.
tor judge-mail-chaos { m: string }
| urgent f64
| routine f64
| failed string

judge-mail-chaos = koru/odds:judge(budget: 3): j |> koru/odds:chaos(j): jc |> fixture(): d |> koru/odds:feels.draw(j: jc, d)
| yes p |> koru/odds:settle(j: jc): j2 => urgent p
| no p |> koru/odds:settle(j: jc): j2 => routine p
| err e |> koru/odds:settle(j: jc): j2 => failed e.msg

// The margin question gate.k cannot ask today: the dist survives the
// ask, so per-choice confidence is a field read, not a decode branch.
tor audit { m: string }
| calm f64
| failed string

audit = koru/odds:judge(budget: 3): j |> fixture(): d => calm d.confidence.yes

// Exhausted is real: fuel 0 returns | exhausted before any I/O.
tor dry-run { m: string }
| judged f64
| failed string

dry-run = koru/odds:judge(budget: 0): j |> koru/odds:feels.map(j, text: m, question: "urgent?")
| map d => judged d.yes
| exhausted => failed "no fuel"
| err e => failed e.msg

test(pick argmaxes a scripted distribution) {
    fixture => { yes: 0.9, no: 0.1 }
    judge-mail(m: "disk full")
    | urgent p |> assert(p == 0.9)
    | routine _ |> assert.fail()
    | failed _ |> assert.fail()
}

test(pick routes the low branch too) {
    fixture => { yes: 0.2, no: 0.8 }
    judge-mail(m: "typo fix")
    | urgent _ |> assert.fail()
    | routine p |> assert(p == 0.8)
    | failed _ |> assert.fail()
}

test(draw samples the scripted distribution) {
    fixture => { yes: 1.0, no: 0.0 }
    judge-mail-chaos(m: "disk full")
    | urgent p |> assert(p == 1.0)
    | routine _ |> assert.fail()
    | failed _ |> assert.fail()
}

test(confidence survives the fetch) {
    fixture => { yes: 0.9, no: 0.1, confidence: { yes: 0.95, no: 0.4 } }
    audit(m: "disk full")
    | calm c |> assert(c == 0.95)
    | failed _ |> assert.fail()
}

test(exhausted judge names its outcome) {
    dry-run(m: "whatever")
    | judged _ |> assert.fail()
    | failed msg |> assert(msg.len > 0)
}
