# @koru/ai — LLM text generation for Koru

A first-class Koru edition of one-shot LLM text generation over the **Anthropic
Messages** and **OpenAI Chat Completions** HTTP APIs. Built on
[`@koru/curl`](../curl) — we dogfood our own lifted HTTP client.

The whole point is in the type system: an in-flight request carries a phantom
`built!` obligation and the HTTP response carries curl's `open!` obligation, so
**the compiler will not let you leak the request scratch or forget to close the
connection.** Two resources, both proven safe at compile time, discharged in
your flow.

## Install / resolve

`ai` reaches its sibling `curl` through the `koru` path alias. `koru.json`:

```json
{ "paths": { "koru": ".." } }
```

## The happy path

`ai` gives you building-block events; you wire them in a top-level flow together
with `curl`. Both obligations are visible right at the call site:

```koru
~import koru/ai
~import koru/curl
~import std/io

~koru/ai:request.anthropic(model: "claude-sonnet-4-20250514", prompt: "What is a phantom type?", system: null, max_tokens: 256, allocator: null)
| built req |> koru/curl:post.with-headers(req.url, req.body, headers: &.{ .{ .name = "Content-Type", .value = "application/json" }, .{ .name = "x-api-key", .value = "sk-ant-..." }, .{ .name = "anthropic-version", .value = "2023-06-01" } })
    | ok resp |> koru/ai:parse.anthropic(resp)
        | ok result |> std/io:print.ln("{{ result.text:s }}") |> koru/curl:close(resp) |> koru/ai:free.request(req)
        | err e |> std/io:print.ln("API error [{{ e.code:d }}]: {{ e.msg:s }}") |> koru/curl:close(resp) |> koru/ai:free.request(req)
    | err e |> std/io:print.ln("Transport error: {{ e.msg:s }}") |> koru/ai:free.request(req)
```

Delete the `koru/curl:close` **or** the `koru/ai:free.request` and it will not
compile. That is the lift.

For OpenAI, swap `request.anthropic`→`request.openai`, `parse.anthropic`→
`parse.openai`, and use OpenAI's headers (`Authorization: Bearer <key>`).

## API

| Event | Shape | Purpose |
|---|---|---|
| `request.anthropic` / `request.openai` | `{ model, prompt, system?, max_tokens?, allocator? }` → `built *Request<built!>` | Build provider JSON; yields a request carrying a `built!` free-obligation. |
| `free.request` | `{ req: *Request<!built> }` | Discharge the request obligation (frees the JSON body). |
| `parse.anthropic` / `parse.openai` | `{ resp: *curl:Response<curl:open> }` → `ok GenerateResult \| err Error` | Borrow the response, parse into an **owned** `GenerateResult` (every byte duped, so it survives `close`). |

`GenerateResult` = `{ text, usage:{input_tokens,output_tokens}, model, stop_reason, allocator }`.
`Error` = `{ code, msg, provider }`. HTTP non-2xx surfaces on the `err` branch
with the raw API error body; transport failures surface on curl's own `err`.

## Why building blocks, not a single `generate(...)`

A one-call `generate(...)` would have to be a *subflow* that borrow-parses the
response, discharges it, and produces a value in one event. That exact shape is
blocked by three current compiler gaps (obligation loss in non-head subflow
branches; a codegen bug on bind-in-continuation; no output-binary spelling for a
sibling package's Zig type). The building-block flow lives entirely in top-level
flow position, which the compiler handles cleanly — and it has the side benefit
of making **both** obligations explicit in the caller's code. Full write-up,
repros, and verbatim errors in [`LIFT_NOTES.md`](./LIFT_NOTES.md).

## Run it

```
koruc run ai/tests/roundtrip.kz            # full stack, real HTTPS → 401 err arm
koruc run ai/tests/negative/forgotten_free.kz --auto-discharge=disable   # MUST FAIL
```
