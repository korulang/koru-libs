// mock_roundtrip — the full judge lifecycle against the offline
// backend: issue, judge (greedy + chaotic), polish, retire. No
// network — judge.mock swaps probabilities' provenance, nothing else.
//
// Run it:
//   koruc run odds/tests/mock_roundtrip.k

import koru/odds
import std/io

koru/odds:judge.mock(budget: 10): j |> koru/odds:triage(j, text: "the export button crashes", question: "Which team handles this?")
| bug p |> std/io:print.ln("triage: bug p={{ p:f }}") |> koru/odds:chaos(j): cj |> koru/odds:ctriage(j: cj, text: "the export button crashes", question: "Which team handles this?")
    | bug q     |> std/io:print.ln("chaos: bug p={{ q:f }}") |> koru/odds:settle(j: cj)
    | feature q |> std/io:print.ln("chaos: feature p={{ q:f }}") |> koru/odds:settle(j: cj)
    | other q   |> std/io:print.ln("chaos: other p={{ q:f }}") |> koru/odds:settle(j: cj)
    | exhausted |> std/io:print.ln("chaos exhausted") |> koru/odds:settle(j: cj)
    | err e     |> std/io:print.ln("chaos err: {{ e.msg:s }}") |> koru/odds:settle(j: cj)
| feature p |> std/io:print.ln("triage: feature p={{ p:f }}")
| other p   |> std/io:print.ln("triage: other p={{ p:f }}")
| exhausted |> std/io:print.ln("triage exhausted")
| err e     |> std/io:print.ln("triage err: {{ e.msg:s }}")

koru/odds:judge.mock(budget: 10): j2 |> koru/odds:feels(j: j2, text: "per our previous correspondence, going forward we should synergize", question: "full of corporate jargon")
| yes p |> std/io:print.ln("jargon: yes p={{ p:f }}") |> koru/odds:polish(j: j2, draft: "synergize the deliverables")
    | polished d |> std/io:print.ln("polished: {{ d:s }}")
    | exhausted |> std/io:print.ln("polish exhausted")
| no p |> std/io:print.ln("jargon: no p={{ p:f }}")
| exhausted |> std/io:print.ln("feels exhausted")
| err e |> std/io:print.ln("feels err: {{ e.msg:s }}")
