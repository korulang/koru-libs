# @korulang/odds

System One judgments as Koru tors.

A [System One model](https://typesafe.ai) (TypeSafe's **Jev** is the
first) answers typed questions over a closed answer space and returns
calibrated probabilities. That contract is already the shape of a Koru
tor:

- **the branch set IS the answer space** — declared once, in the event
  signature
- **the payload IS the winner's probability** — a `when` clause on it is
  a confidence gate, not a keyword
- **the decode policy IS a phantom state** — `*Judge<greedy>` argmaxes,
  `*Judge<chaotic>` samples the same distribution
- **the judge IS an obligation** — every issued judge must be retired
  or the program does not compile

## The reflection

A judgment tor's `f64`-payload branches **are** the question's
`criteria`, enumerated at comptime from `@typeInfo(@This().Output)`:

```koru
~pub tor triage { j: *Judge<greedy>, text: string, question: string }
| bug f64        ┐
| feature f64    ├─→  "criteria": { "bug": "bug", "feature": "feature",
| other f64      ┘                     "other": "other" }
| exhausted        control, not criteria (non-f64 payload)
| err Err          control, not criteria (non-f64 payload)
```

Rename a branch and the API question changes — the category names are
never spelled twice. Non-`f64` branches are control flow and excluded
by *type*, not by naming convention.

## Usage

```koru
import koru/odds

koru/odds:judge(budget: 8): j |> koru/odds:triage(j, text: mail, question: "Which team handles this?")
| bug p when p >= 0.8 |> ...
| bug p               |> ...        // low confidence — a named outcome
| feature p           |> ...
| other p             |> ...
| exhausted           |> ...        // fuel spent — a named outcome
| err e               |> ...
```

`judge.mock(budget)` issues the same `*Judge<greedy>` resource with a
deterministic hash backend — no network, for tests and offline work.
`chaos`/`settle` flip the judge's decode mode at the type level;
`cfeels`/`ctriage` are only callable on a `<chaotic>` judge.

`gen` is deliberately a different category: System One models cannot
generate text, so `gen` calls a chat-completions model. `polish`
composes the two — a judgment-gated rewrite loop bounded by fuel.

## Running

```sh
# live — real Jev through OpenRouter (~$0.00002 per judgment)
OPENROUTER_API_KEY=sk-or-v1-... koruc run odds/examples/01_inbox.k

# offline — deterministic mock backend, no key needed
koruc run odds/tests/mock_roundtrip.k
```

## Status

Early. The live backend is one file (`index.kz`, ~360 lines) with no
package dependencies — transport is `std.http` inside proc bodies.
Open design questions live in `LIFT_NOTES.md`: per-branch criteria
descriptions, the dropped `confidence` field, batched questions, and
whether the HTTP lifecycle should surface as a Koru-level obligation
like `@korulang/curl`'s `open!`.
