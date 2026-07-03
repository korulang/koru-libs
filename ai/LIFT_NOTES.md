# ai — the definitive Koru LLM-generation edition (quality pass)

**One-line pitch**: LLM text generation over Anthropic/OpenAI where the request
scratch and the HTTP connection are both phantom obligations the compiler
enforces.

**Entry type**: quality pass on `ai`

**Author**: Claude (Opus 4.8), lift-challenge contestant

## The pillar gap this pass closes

`ai` was pre-current-language and **did not compile at all**. Two independent
rots:

1. **KORU110** — every `~proc` was bare (`~proc generate { ... }`). Bare procs
   are unresolvable in the current language; a call site errors with KORU110.
2. **An invented cross-module escape hatch** — it reached the curl sibling via
   `const curl = @import("root").koru_libs.curl;` and called
   `curl.post_with_headers_event.call(.{...})` / `curl.close_event.call(...)` —
   symbols attested by **no** passing test. The lift's entire premise (compose
   with curl) rested on a fabricated API.

The one complete move: **migrate `ai` to compile and run under the current
language, composing with curl the sanctioned koru way, with the curl resource's
obligation enforced end-to-end** — and, in doing so, add a *second* obligation
(the request scratch) so both the request and the response are compile-time
safe. Where the clean form hit compiler walls, I stopped and pinned them rather
than route around (three findings below).

### Before → after

| | Before | After |
|---|---|---|
| Proc form | `~proc generate {` (bare, KORU110) | `~proc request.anthropic\|zig {` etc. |
| Curl call | `curl.post_with_headers_event.call(.{...})` (invented) | `koru/curl:post.with-headers(...)` in flow position (attested) |
| Curl cleanup | `curl.close_event.call(...)` (invented) | `koru/curl:close(resp)` + enforced `<koru/curl:open>` obligation |
| Resource safety | request JSON `defer`-freed inside one Zig proc; no compile-time guarantee | `*Request<built!>` + `*Response<open!>` — **both** obligations enforced |
| Compiles? | No | Yes; runs end-to-end |

> Dependency note: this worktree predated the merged curl quality pass, so its
> `curl/index.kz` still had bare procs. I synced those four proc tags to `|zig`
> (and one `allocPrintZ`→`allocPrintSentinel`) to match `main` exactly. That is
> a mechanical dependency sync, **not** part of this `ai` pass — `curl/index.kz`
> is now byte-identical to `main`.

## The quadrifecta self-audit

- **DX**: The happy path is one declarative flow (README). `request.*` hides all
  provider-specific JSON shaping; `parse.*` hides all response scraping; the
  caller never touches curl handles or JSON. The honest cost: it is a
  building-block flow, not a single `generate(...)` call, and the caller writes
  the auth header inline (provider-specific). That is a real ergonomic
  concession — forced by Toolchain findings A/B/C, not chosen — and it buys a
  genuine upside: both obligations are legible at the call site.
- **Performance**: All lifting is compile-time (phantom checking, event
  dispatch, monomorphized JSON writers). Runtime cost over hand-written curl+std
  is one heap alloc for the request JSON and per-field dupes on the parsed
  result — the same allocations a hand-written client makes. No reflection, no
  boxing, no runtime obligation bookkeeping. **Unmeasured** against a
  hand-written baseline; no benchmark was run.
- **Correctness**: Wrong usage is a build error. The `err` branch is *unskippable*
  — the flow does not compile without handling both `ok` and `err` from `parse.*`
  and curl's transport `err`. HTTP non-2xx is surfaced as a typed `Error`, never
  a silent wrong-answer. Negative test: `tests/negative/forgotten_free.kz` fails
  to compile with `error[KORU030]` when `free.request` is omitted.
- **Resource safety**: Two obligations, both uncompilable to forget.
  `request.*` issues `*Request<built!>` (index.kz:81, :110) discharged only by
  `free.request` (index.kz:135). The response carries curl's
  `*Response<open!>`, borrowed by `parse.*` as `<koru/curl:open>`
  (index.kz:154, :190) and discharged only by `koru/curl:close`. No leak path:
  the request body is freed by `free.request`; the response body+handle by
  `close`; the parsed result owns its own duped bytes.

## What it explicitly doesn't do (yet)

- **No single `generate(...)` convenience event** — blocked by findings A/B/C.
- **No streaming** — one request, one reply.
- **Auth headers are caller-supplied inline** — because a consumer package
  cannot construct curl's `Header` Zig type in its output binary (finding C), so
  the header array is built at the flow call site, not inside `ai`.
- **Anthropic/OpenAI only**; parsers are minimal string scanners (no full JSON
  parse), sufficient for the documented response shapes.
- **`max_tokens` defaults to 1024**; `system` is optional.

## Toolchain findings

All three were surfaced by honest library code and are pinned as minimal repros
in [`toolchain-repros/`](./toolchain-repros/). Each was reached by asking "is the
toolchain wrong here, or is my code wrong?" — the koru-level form is attested by
passing tests in each case, so the wall is the toolchain's (a koru-level
guarantee not yet built), not a misuse. Floating these for a design call before
any compiler change.

### A. Cross-module `open!` obligation is lost in a non-head subflow branch
`toolchain-repros/A_nested_obligation_lost.kz` vs `A_control_head.kz`. When the
resource-producing cross-module event (`koru/curl:get`) is the subflow **head**,
the obligation threads and `koru/curl:close` is accepted. Move it one level down
into a branch (`| ok p => koru/curl:get(...)`) with the *same* discharge idiom
and:

```
error[KORU030]: Phantom state mismatch: argument 'resp' carries no obligation here,
but this event consumes '<!open>'. Pass a value that still holds its '<open!>' obligation.
```

The control (curl as head) compiles. Only difference: branch depth.

### B. A pipe-binding in a subflow `=>` continuation emits malformed Zig
`toolchain-repros/B_subflow_bind_continuation_codegen.kz`. A subflow branch whose
continuation binds a call and pipes onward — `| ok resp => parse(resp): reply |>
koru/curl:close(resp) | ...` — mis-emits: the emitter turns the bound call into a
struct field name and leaks the binding as an undeclared identifier:

```
output_emitted.zig:57:50: error: use of undeclared identifier 'reply'
   (emitted:  return .{ .@"parse(resp):" = reply };)
```

This is kin to the already-pinned koru test
`000_CORE_LANGUAGE/020_EVENTS_FLOWS/020_030_chained_subflow_bind_produce`
("the chained form currently drops the trailing produce — the inline-continuation
path doesn't capture it"). Same inline-continuation gap, here producing broken
Zig rather than a dropped value. **This is the finding that forced the
building-block design**: it makes a single subflow that borrow-parses-then-
discharges-then-produces impossible to emit.

### C. A consumer can't name/construct a sibling package's Zig type in the output binary
`toolchain-repros/C_xmod_type_in_output.kz`. To hold/build `curl.Header` in `ai`:
- `@import("root").koru_libs.curl` works in the backend/inlined context (sqlite3
  uses `@import("root").koru_libs.sqlite3.c` this way) but in the **output**
  binary: `error: root source file struct 'output_emitted' has no member named 'koru_libs'`.
- the koru-level `koru/curl:Header` ref translates in event-signature positions
  but leaks verbatim inside a raw-Zig `struct {}` field or a proc-body
  constructor: `error: expected ',' after field`.

Net: there is no working spelling for a sibling package's Zig type in a
consumer's emitted output. `ai` sidesteps it by building the header array as an
inline anonymous literal at the flow call site (curl coerces it), which is why
auth headers are caller-supplied.

*Bad-error-message note*: findings B and C both surface as raw Zig
(`output_emitted.zig:...`) leaking to the user instead of a koru-level
diagnostic — i.e. the koru-level wall isn't built at these boundaries yet.

## Proof of life

```
$ koruc --check ai/index.kz
✓ Shape checking passed

$ koruc run ai/tests/roundtrip.kz            # full stack, real HTTPS call
...
✓ Built executable: a.out
Running a.out...
API error [401] from anthropic                # build→POST→parse→close→free, all real

$ koruc run ai/tests/negative/forgotten_free.kz --auto-discharge=disable
error[KORU030]: Resource 'req' <built!> was not discharged. Call: koru.ai:free.request

$ koruc --check ai/examples/01_anthropic_generate.kz
✓ Shape checking passed
```

(The 401 is the deterministic real reply to an invalid key — proof the entire
transport + obligation-discharge + error-parse path executes for real, no stub.)
