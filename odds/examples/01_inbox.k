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
// With no key the `err` arms fire — itself a faithful run.

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
| [bug: Bug reports] p |> std/io:print.ln("route: bug     p={{ p:f }}") |> koru/odds:feels(j, text: m, question: "genuinely urgent")
    | yes q when q >= 0.8 |> std/io:print.ln("drop everything        p={{ q:f }}") |> koru/odds:polish(j, draft: m)
        | polished d |> std/io:print.ln("polished: {{ d:s }}")
        | exhausted |> std/io:print.ln("judge exhausted mid-polish")
    | no q when q >= 0.8  |> std/io:print.ln("it can wait            p={{ q:f }}")
    | yes q               |> std/io:print.ln("uncertain - follow up  p={{ q:f }}")
    | no q                |> std/io:print.ln("uncertain - follow up  p={{ q:f }}")
    | exhausted           |> std/io:print.ln("judge exhausted at urgency check")
    | err e               |> std/io:print.ln("feels err: {{ e.msg:s }}")
| [feature: Feature requests] p |> std/io:print.ln("route: feature p={{ p:f }}") |> koru/odds:chaos(j): cj |> koru/odds:ctriage(j: cj, text: m, question: "Which team should handle this message?")
    | [bug: Bug reports] q         |> std/io:print.ln("chaos reroute: bug     p={{ q:f }}") |> koru/odds:settle(j: cj)
    | [feature: Feature requests] q |> std/io:print.ln("chaos reroute: feature p={{ q:f }}") |> koru/odds:settle(j: cj)
    | [other: Other messages] q    |> std/io:print.ln("chaos reroute: other   p={{ q:f }}") |> koru/odds:settle(j: cj)
    | exhausted                    |> std/io:print.ln("judge exhausted in chaos") |> koru/odds:settle(j: cj)
    | err e                        |> std/io:print.ln("ctriage err: {{ e.msg:s }}") |> koru/odds:settle(j: cj)
| [other: Other messages] p   |> std/io:print.ln("route: other   p={{ p:f }}")
| exhausted |> std/io:print.ln("judge exhausted at triage")
| err e     |> std/io:print.ln("triage err: {{ e.msg:s }}")

mail-bug(): m |> route(m)
mail-feature(): m |> route(m)
mail-other(): m |> route(m)
