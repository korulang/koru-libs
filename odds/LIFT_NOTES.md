# LIFT_NOTES — @korulang/odds

Toolchain findings and open design questions, recorded as the lift
surfaces them. Ground rule (repo CLAUDE.md): a wall this package hits
is a compiler gap and the gap is the deliverable — nothing here is
routed around; these notes are the ledger.

## Findings

- **`@This().Output` works inside `~proc` bodies.** Proc bodies splice
  into the event struct's `handler`, so `@typeInfo(@This().Output)`
  enumerates the declared branch names at comptime — the hook the
  criteria reflection stands on. It is *emergent*, not pinned: nothing
  in the koru regression suite says a proc body may use `@This()`, and
  an emitter change to how bodies splice would break this package
  silently. Worth a pin in koru's suite.

- **Proc bodies compile against the consumer's Zig std.** Zig 0.15.2
  moved JSON/`std.http` to the `Io.Writer` interface
  (`Stringify.value(v, .{}, *Io.Writer)`,
  `fetch(.response_writer = &aw.writer)`,
  `std.Io.Writer.Allocating` replacing `ArrayList.writer()`). A package
  whose `|zig` bodies use std APIs is implicitly version-locked to
  whatever zig the consumer's `koruc` invokes.

- **`PARSE006` again:** a bare positional arg whose spelling doesn't
  match the parameter name (`feels(j2, ...)`) is refused with a good
  hint (`j: j2`). Cost: one compile cycle. No action needed.

- **Auto-discharge is real, and `retire` never needed `[!]`.** Koru's
  emitter splices a resource's disposer at scope exits when the
  *strict* candidate set (void events — any output disqualifies, since
  the inserter cannot bind a return) has exactly one member, or one
  `[!]` default among several. `retire` was always sole for
  `<greedy>`: `chaos` returns `*Judge<chaotic!>` and the void filter
  excludes it — transitions never reach the candidate set at all.
  Greedy judges auto-discharge with nothing spelled, with or without
  the annotation. `<chaotic>` still requires a spelled `settle`: a
  transition mints a fresh obligation, so it is never a *disposal* —
  the inserter will not chain. Verified: zero-`retire` greedy flow
  compiles and runs unannotated; `<chaotic>` without `settle` hits
  `KORU030` naming the call. (The earlier revision of this note
  claimed `[!]` settled a retire-vs-chaos tie — wrong set read; the
  loose candidate list only feeds the error suggestion.)

- **No network-shaped obligations surfaced** — deliberately. The whole
  HTTP lifecycle happens inside each proc body, so the checker sees
  nothing of it. `@korulang/curl`'s `open!`/`close` is the lifted
  pattern; composing it flow-position-style (as `@korulang/ai` does) is
  the alternative, but `ai`'s LIFT_NOTES documents the compiler gaps
  blocking the all-in-one request→parse→discharge event shape that a
  single `triage` call wants. The trade-off is real: zero package
  dependencies and one call site, vs. obligations visible to the
  checker. Open question below.

## Open questions

- **Criteria descriptions.** `criteria` currently maps each branch
  name to itself (`"bug": "bug"`). Jev reads option *descriptions* to
  separate categories; name-as-description works on clear cases
  (observed p≈1.0) but is thin where branches overlap. There is no
  per-branch metadata slot in tor syntax — descriptions want a home
  that isn't a second declaration. (Syntax is Lars's; candidates: a
  doc-string convention on branches, a `criteria` argument of name→desc
  pairs, or richer `instructions`.)

- **`confidence` is dropped.** The API returns per-choice `confidence`
  alongside `probabilities`; the package forwards only the probability.
  Options: a second f64 payload (`| bug f64 f64`), a `confidence`
  question type, or a `when`-surface redesign.

- **Batched questions.** The API evaluates N questions in parallel per
  call — a `decide`-style event that fans out N judgments in one POST
  is the native unit. The current shape (one tor call = one question =
  one request) is the degenerate case. A batch event would need a
  multi-question input surface Koru doesn't obviously have yet.

- **`noul`/`score` are unmapped.** `choice` is the primitive whose
  schema matches a tor; `noul` returns a bare scalar and `score` a
  rubric position. `feels` currently uses `choice{yes,no}` — native
  `noul` would lose `confidence` and the two-probability payload.

- **`err` payloads are thin.** Every failure class (NoKey, FetchFailed,
  HttpStatus, BadJson, UnknownBranch) collapses to `odds call failed`.
  HttpStatus should carry the code and response body.

- **`gen` belongs to a different package eventually.** Generation is
  `@korulang/ai`'s domain; it lives here only because that package has
  no OpenRouter endpoint yet. When it grows one, `gen` should compose
  rather than duplicate.
