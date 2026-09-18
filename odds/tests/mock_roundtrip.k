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
    | bug q     |> std/io:print.ln("chaos: bug p={{ q:f }}") |> koru/odds:settle(j: cj): g |> koru/odds:retire(j: g)
    | feature q |> std/io:print.ln("chaos: feature p={{ q:f }}") |> koru/odds:settle(j: cj): g |> koru/odds:retire(j: g)
    | other q   |> std/io:print.ln("chaos: other p={{ q:f }}") |> koru/odds:settle(j: cj): g |> koru/odds:retire(j: g)
    | exhausted |> std/io:print.ln("chaos exhausted") |> koru/odds:settle(j: cj): g |> koru/odds:retire(j: g)
    | err e     |> std/io:print.ln("chaos err: {{ e.msg:s }}") |> koru/odds:settle(j: cj): g |> koru/odds:retire(j: g)
| feature p |> std/io:print.ln("triage: feature p={{ p:f }}") |> koru/odds:retire(j)
| other p   |> std/io:print.ln("triage: other p={{ p:f }}") |> koru/odds:retire(j)
| exhausted |> std/io:print.ln("triage exhausted") |> koru/odds:retire(j)
| err e     |> std/io:print.ln("triage err: {{ e.msg:s }}") |> koru/odds:retire(j)

koru/odds:judge.mock(budget: 10): j2 |> koru/odds:feels(j: j2, text: "per our previous correspondence, going forward we should synergize", question: "full of corporate jargon")
| yes p |> std/io:print.ln("jargon: yes p={{ p:f }}") |> koru/odds:polish(j: j2, draft: "synergize the deliverables")
    | polished d |> std/io:print.ln("polished: {{ d:s }}") |> koru/odds:retire(j: j2)
    | exhausted |> std/io:print.ln("polish exhausted") |> koru/odds:retire(j: j2)
| no p |> std/io:print.ln("jargon: no p={{ p:f }}") |> koru/odds:retire(j: j2)
| exhausted |> std/io:print.ln("feels exhausted") |> koru/odds:retire(j: j2)
| err e |> std/io:print.ln("feels err: {{ e.msg:s }}") |> koru/odds:retire(j: j2)
