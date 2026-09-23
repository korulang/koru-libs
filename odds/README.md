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
  or the program does not compile, and `retire` is the sole spliceable
  disposer (void, no output), so the emitter inserts it at scope exits
  and you never spell it. `settle` is the only call you write: a mode
  transition mints a fresh obligation, so leaving `<chaotic>` is a
  decision you name, not bookkeeping the compiler does.

## The reflection

A judgment tor's `f64`-payload branches **are** the question's
`criteria`, enumerated at comptime from `@typeInfo(@This().Output)`:

```koru
~pub tor triage { j: *Judge<greedy>, text: string, question: string }
| [bug: Bug reports] f64           ┐
| [feature: Feature requests] f64  ├─→ "criteria": {
| [other: Other messages] f64      ┘       "bug": "Bug reports",
| exhausted                            "feature": "Feature requests",
| err Err                              "other": "Other messages" }
                            control ↑ non-f64 payload, never criteria
```

A pattern-named branch spells `[tag: description]` — the tag is the
criteria key Jev answers with, the text after the first `:` is the
description it reads to separate options. Both halves come out of the
one declared string: the emitter quotes the pattern into the union
field name verbatim (`@"bug: Bug reports"`), so a comptime split on `:`
recovers them. A bare branch name is its own key and description —
`feels`'s `| yes f64 | no f64` needs no annotation.

Continuations match the full pattern name by equality and bind the
`f64` payload — `| [bug: Bug reports] p when p >= 0.8 |>`. Non-`f64`
branches are control flow and excluded by *type*, not by naming
convention.

## Usage

```koru
import koru/odds

koru/odds:judge(budget: 8): j |> koru/odds:triage(j, text: mail, question: "Which team handles this?")
| [bug: Bug reports] p when p >= 0.8  |> ...
| [bug: Bug reports] p                |> ...  // low confidence — a named outcome
| [feature: Feature requests] p       |> ...
| [other: Other messages] p           |> ...
| exhausted                           |> ...  // fuel spent — a named outcome
| err e                               |> ...
```

`chaos`/`settle` flip the judge's decode mode at the type level;
`cfeels`/`ctriage` are only callable on a `<chaotic>` judge. `retire`
is never spelled — it is the sole void disposer, spliced at scope
exits; a `<chaotic>` judge exits through `settle`, which reissues
`<greedy>` and that disposes itself.

## The split

Each judgment is two operations. `feels.map` / `triage.map` ask — one
live POST, fuel spent — and return the **whole distribution** as a
`| map` payload: every branch's probability plus the API's per-choice
`confidence` (`d.yes`, `d.no`, `d.confidence.yes`, …). `*.pick`
argmaxes the dist, `*.draw` samples it — both pure, free, repeatable
over one fetch:

```koru
koru/odds:feels.map(j, text: mail, question: "urgent?")
| map d |> koru/odds:feels.pick(j, d)   // d survives — read d.confidence.*,
    | yes p |> ...                      // decode again, no second call
```

`feels`/`cfeels`/`triage`/`ctriage` are the same ask+decode composed —
the one-call spelling for callers that only want the winner.

`gen` is deliberately a different category: System One models cannot
generate text, so `gen` calls a chat-completions model. `polish`
composes the two — a judgment-gated rewrite loop bounded by fuel.

## Running

```sh
# live — real Jev through OpenRouter (~$0.00002 per judgment)
OPENROUTER_API_KEY=sk-or-v1-... koruc run odds/examples/01_inbox.k
```

## Status

Early. The live backend is one file (`index.kz`) with no
package dependencies — transport is `std.http` inside proc bodies.
Open design questions live in `LIFT_NOTES.md`: batched questions, and
whether the HTTP lifecycle should surface as a Koru-level obligation
like `@korulang/curl`'s `open!`.
