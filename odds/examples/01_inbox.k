// 01_inbox — the Probably inbox department against real Jev.
//
// Three mails walk the routes: a bug urgent enough to earn the polish
// loop, a feature request rerouted through a <chaotic> judge, and an
// other that goes straight through. Every judgment is a REAL call to
// the OpenRouter Decisions API — the criteria keys are reflected off
// each tor's f64-payload branches, so the answer space is declared
// once, in the type.
//
// Run it:
//   OPENROUTER_API_KEY=sk-or-v1-... koruc run odds/examples/01_inbox.k
//
// With no key the `err` arms fire — itself a faithful run. For an
// offline run swap `odds:judge` for `odds:judge.mock` below.

import koru/odds
import std/io

tor mail-bug {} -> string
tor mail-feature {} -> string
tor mail-other {} -> string

mail-bug -> "Subject: URGENT - app crashes on login\n\nEvery time I enter my password and hit enter, the app just disappears. Started after the update yesterday. I can't get into my account at all and I have invoices due today."
mail-feature -> "can we get a new icon theme"
mail-other -> "your invoice for march is attached"

tor route { m: string }
route = koru/odds:judge(budget: 8): j |> koru/odds:triage(j, text: m, question: "Which team should handle this message?")
| bug p |> std/io:print.ln("route: bug     p={{ p:f }}") |> koru/odds:feels(j, text: m, question: "genuinely urgent")
    | yes q when q >= 0.8 |> std/io:print.ln("drop everything        p={{ q:f }}") |> koru/odds:polish(j, draft: m)
        | polished d |> std/io:print.ln("polished: {{ d:s }}") |> koru/odds:retire(j)
        | exhausted |> std/io:print.ln("judge exhausted mid-polish") |> koru/odds:retire(j)
    | no q when q >= 0.8  |> std/io:print.ln("it can wait            p={{ q:f }}") |> koru/odds:retire(j)
    | yes q               |> std/io:print.ln("uncertain - follow up  p={{ q:f }}") |> koru/odds:retire(j)
    | no q                |> std/io:print.ln("uncertain - follow up  p={{ q:f }}") |> koru/odds:retire(j)
    | exhausted           |> std/io:print.ln("judge exhausted at urgency check") |> koru/odds:retire(j)
    | err e               |> std/io:print.ln("feels err: {{ e.msg:s }}") |> koru/odds:retire(j)
| feature p |> std/io:print.ln("route: feature p={{ p:f }}") |> koru/odds:chaos(j): cj |> koru/odds:ctriage(j: cj, text: m, question: "Which team should handle this message?")
    | bug q     |> std/io:print.ln("chaos reroute: bug     p={{ q:f }}") |> koru/odds:settle(j: cj): g |> koru/odds:retire(j: g)
    | feature q |> std/io:print.ln("chaos reroute: feature p={{ q:f }}") |> koru/odds:settle(j: cj): g |> koru/odds:retire(j: g)
    | other q   |> std/io:print.ln("chaos reroute: other   p={{ q:f }}") |> koru/odds:settle(j: cj): g |> koru/odds:retire(j: g)
    | exhausted |> std/io:print.ln("judge exhausted in chaos") |> koru/odds:settle(j: cj): g |> koru/odds:retire(j: g)
    | err e     |> std/io:print.ln("ctriage err: {{ e.msg:s }}") |> koru/odds:settle(j: cj): g |> koru/odds:retire(j: g)
| other p   |> std/io:print.ln("route: other   p={{ p:f }}") |> koru/odds:retire(j)
| exhausted |> std/io:print.ln("judge exhausted at triage") |> koru/odds:retire(j)
| err e     |> std/io:print.ln("triage err: {{ e.msg:s }}") |> koru/odds:retire(j)

mail-bug(): m |> route(m)
mail-feature(): m |> route(m)
mail-other(): m |> route(m)
