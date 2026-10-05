---
gauntlet: web
kind: gauntlet
status: open
reference: tokio-rs/topcoat @ v0.10.0 (3e7bb43) — docs/ + examples/
control: the reference's own example apps, built and run under cargo
rung: 1 (served bytes) → 2 (interaction) → 3 (throughput)
vehicle: orisha + koru/dom — the SSR seam does not exist; that absence is the first bar
opened: 2026-10-04
---

# WEB_GAUNTLET — can a Koru program serve a page that acts like a page

A gauntlet, not a challenge: **depth against the world.** The bar is somebody
else's, it is published, and it is not ours to move.

Sibling, not successor, to `DOM_GAUNTLET`. That one asks whether a Koru
program can put rows on a screen. This one asks whether Orisha + koru/dom can
do what a real web framework does across the whole boundary — serve rendered
HTML, navigate without reloads, carry values and updates between server and
browser. They share the component spelling; a server-side paint lowering
would feed both.

## The reference — named, fetchable, comparable, *pinned*

[tokio-rs/topcoat](https://github.com/tokio-rs/topcoat) at **v0.10.0, commit
`3e7bb43`** — a server-rendered web framework in the tokio org that splits one
Rust codebase across server and browser. It is the right reference for four
reasons:

- **The example corpus is a ready-made fixture suite.** 25 example apps —
  `hello-world`, `module-router`, `path-query-params`, `request-response`,
  `runtime`, `websocket`, `sse`, `toasty-todo` — each a whole program that
  compiles and runs under cargo. Whole apps, not API surfaces: same admissibility
  ruling as krausest.
- **`docs/` is a fixed behavioral spec.** `docs/view/` (view, component, props,
  attributes, class, live), `docs/runtime/` (expr, record, shard, link,
  procedure, coherence), router, context, cli. The operation set is derivable
  from these pages — the closer derives it, nobody recalls it.
- **It is the same architectural problem, solved in public.** Server-rendered
  components, a router, a serialization boundary (records, procedures), live
  updates (shards over WebSocket), client navigation (runtime links). That is
  precisely the seam Orisha + koru/dom faces. The places their model and ours
  diverge are the interesting ones — divergence measured, not assumed.
- **It is versioned.** The bar is pinned to a tag, so "the reference moved"
  is a decision on the walk, never a surprise in a board.

**The control is the reference itself.** DOM_GAUNTLET could read krausest's
published columns because the opponents were already measured. Nobody has
published topcoat's rendered bytes. So the calibration inverts: the closer's
first job is to build topcoat's examples under cargo, capture what they serve,
and certify those captures as goldens — then never touch the reference again
except on a pinned upgrade.

## The sibling endeavor — Campfire as the pull oracle

A parallel effort is already running the same doctrine from the other end:
`~/src/once-campfire-koru` ports Basecamp's `once-campfire` onto Orisha as a
**gap-closing oracle** — a real app (real schema, real auth, real cable) that
walks code paths in dependency order rather than checklist order. Their
G1–G12 catalog and this gauntlet share the load-bearing joints:

- **Their G10 view layer = our rung-1 SSR.** "HTML templates with `{{}}` and
  escaping" and "component → HTML bytes under a native target" are the same
  artifact from two sides. **Designed once, consumed by both** — whoever owns
  it, the other is a customer, not a reimplementer.
- **Their WS subflow sketch = our rung-2 transport.** `*Socket<open!>` pump
  custody, enqueue-only `Socket.ref`, `std/store` subscription registry —
  Campfire's Action Cable and topcoat's shards are the same wire need. Their
  three open questions (subflow env capture, timer surface, ref completeness)
  are this gauntlet's too.
- **Their G1–G5 header/body/query surface** is the table stakes for serving
  any conformance fixture at all.

**Division:** Campfire is the *pull* oracle — it discovers gaps a workload
actually hits (it already killed an unexecuted `SQLITE_TRANSIENT` path).
This gauntlet is the *push* oracle — topcoat's spec discovers gaps a workload
might never walk (prefetch semantics, record round-trips, link navigation).
Shared stack, two pressures; the board records both origins on each closure.

## The rung — three, and each has its own closer

**Naming the rung is the only reluctance this door has, so it is named thrice.**

### Phase 1 — served bytes · RUNG 1 · unattended

Serve the fixture pages and assert the **DOM structure** of the response HTML
against the captured goldens. Not byte-identical — attribute order and
whitespace differ legitimately — but structural equality, same discipline as
the dom closer. Initial fixture set derived from `hello-world`,
`module-router`, `path-query-params`, `request-response`.

→ **No leash between rounds. Wide fan-out. Exit-on-bar is legitimate.**

### Phase 2 — interaction · RUNG 2 · round-boundary leash

The boundary behaviors, observed in a headless browser and a wire client:

- client-side navigation updates page/title/history and preserves state
- prefetch fires (or doesn't) per declared mode
- a connected update round-trips to the server and repaints only its shard
- a structured value crosses the wire in both directions intact

Each is a mechanical assertion — DOM state after a click, a message on a
socket, a value echoed back — but the harness is browser-in-the-loop, and a
broken harness lies confidently.

→ **Returns to Lars at round boundaries. The closer's `cant-tell` fraction
gates everything.**

### Phase 3 — throughput · RUNG 3 · batch-boundary leash

req/s against topcoat serving identical fixture pages, `wrk`-class harness,
same protocol discipline as the koru benchmarks: min-capacity estimators,
interleaved runs, the strongest comparator configuration enumerated *before*
measuring.

→ **Batch boundaries, holdout exit, never a laptop number presented as
settled.**

**Phase 2 does not open until Phase 1 is green; Phase 3 until Phase 2.** A
latency number for a page that serves the wrong HTML measures nothing and
does it confidently.

## The floor — measured 2026-10-04, stated plainly

**No Koru program has ever rendered a component to HTML.** The paint lowering
is JS-target only, and the refusal is code, not comment — `dom/index.kz:420`:

```zig
if (!std.mem.eql(u8, CompilerEnv.lang, "js")) {
    std.debug.panic("koru/dom:component has no '{s}' paint lowering …", .{CompilerEnv.lang});
}
```

- **Zero WebSocket or Upgrade handling** across `orisha/lib` and every
  `koru-libs/*/index.kz` (grep, same date). The wire side of shards is air.
- **korulang.org — the flagship Koru site — is a SvelteKit build.** Orisha
  embeds it and serves it static: requests answered, gzipped, ETagged,
  zero-copied. Orisha has never produced a byte of HTML from a component.
- **`koru-libs/sse` frames SSE as a *client*** of AI provider streams —
  parsing `data:` lines off a curl body. Nothing pushes. The name invites a
  wrong assumption; the doc comment already warns.
- **`koru-libs/signal` is world-model instrumentation** — dimension algebra,
  token-bucket kernels. Not UI reactivity. Another name collision; map it
  before anyone reasons from it.
- **Positive control on the other half:** `dom/app` compiles today on koru
  `main` @ `1a2e2de49` (rebuilt this session after removing five
  KORU054-stale `| else |> _` arms). The client-side component pipeline is
  alive; only the server-side half of it is missing.

Expected calibration baseline: **0 of N served-component pages.** Not a
failure — the floor.

## The vehicle — orisha + koru/dom

- **Orisha owns the socket.** kqueue/epoll/io_uring pump, pattern-match
  router, static embedding. `orisha:answer` is platform-free by construction —
  request bytes in, response bytes out, no file descriptor named
  (`lib/index.k:107`) — which is why the wasm serverless build was free.
  Every conformance fixture is, at bottom, bytes through that seam.
- **koru/dom owns the markup spelling.** Capital = ours, anything else passed
  through uninspected (RULED 2026-08-07 in `DOM_GAUNTLET.md`); `{{ ident:t }}`
  typed props; composition is ordinary flow. It has exactly one paint
  lowering and it is JS. **The first compiler-facing artifact this gauntlet
  needs is a second lowering: component → HTML bytes under a native target.**
  Its absence is enforced at `dom/index.kz:420`, not accidental — which means
  adding it is a toolchain change, argued in toolchain terms, never routed
  around in the library.
- **The store owns reactivity** on whichever side of a wire it sits. What
  `std/store:watch` already does in one address space — compile the
  subscriber into the write path — is the shape shard updates want, at
  transport distance. Thesis, not design.
- **The boundary objects may already exist.** `std/proto` knows field shapes
  at compile time; a wire schema could derive from the same declaration
  (records). Whether it should — and what spelling Lars wants — is a walk
  question, not something to synthesize.

## The thesis under test — and what we must not import

DOM_GAUNTLET's claim was that Koru pays at compile time what React pays in a
vdom diff. The web claim extends it across the boundary: topcoat spends
runtime on serialization (records), fragment rerenders (shards), and a
shipped JS runtime that executes a macro-extracted expression subset
(`expr!`). Koru's counter-claim is that the same component lowers to bytes on
the server and paint on the client — one spelling, two targets — and that a
wire schema derives from declarations the compiler already holds.

**But their model is not ours.** Topcoat is server-first: pages render on the
server, `expr!` lifts *fragments* to the browser, records *cross* a boundary.
Koru's JS backend compiles whole programs — the `expr!` subset problem does
not exist here because there is no subset. A faithful port of topcoat's
architecture would be building someone else's product.

So the standing rule for the closer: **the bar is observable behavior —
served HTML structure, DOM state after interaction, messages on a wire —
never API spelling.** Topcoat having a `#[record]` attribute is not a gap.
Nothing being able to carry a `Todo` across the wire is. Model divergence is
not an exclusion; a missing user-visible capability is.

(The one place their model deserves study rather than import: `#[record]`
serializes private fields implicitly — visibility stops being the boundary
the moment a struct crosses. Obligations and taint are Koru's answer-shaped
mechanisms for "what may cross." The gauntlet should surface that question
with evidence, not presume the answer.)

## Rulings this brief needs on the walk

1. **The bar is observable behavior** (above). Needs ratification because it
   decides what "conformance" means wherever our model differs.
2. **The pin.** v0.10.0 @ `3e7bb43` — upgrade only by decision, recorded in
   the ledger.
3. **The SSR spelling.** Does `koru/dom:component` gain a second paint
   lowering (native → HTML string), or is a server-rendered component a
   different spelling entirely? Evidence first — read how the JS lowering is
   welded — then the question comes to Lars. Nothing synthesized.

## The budget — declared before the first spawn

- **Tonight:** the brief, the ledger, and **one calibration pull** — clone
  topcoat at the pinned tag, `cargo run` the smallest example, capture the
  served HTML as a golden, and write down what a fixture capture costs. No
  fleet. ≤2 spawns.
- **The run proper:** budgeted in rounds at the walk after the calibration
  board is read. The calibration says what a round costs.

## The closer, and how it certifies itself

Two closers for three rungs:

- **`bytes-closer`** (rung 1): fetches fixture pages, parses to DOM,
  structurally diffs against goldens. Verdict per fixture:
  `pass` / `fail` / `cant-tell`, plus the self-reported `cant-tell` fraction
  that gates the fleet.
- **`wire-closer`** (rung 2): headless browser + raw socket client. Asserts
  interaction outcomes — DOM after navigation, message frames, echoed values.
  Same verdict shape, same `cant-tell` gate.

**The calibration is a positive control, inverted from DOM's.** There, the
control was a known-good *other* implementation. Here the reference *is* the
known-good implementation: the closer must certify its own capture of
topcoat's `hello-world` at ~0% `cant-tell` before it is ever pointed at
Koru. A closer that cannot certify the reference's own output is broken, and
no round run against it means anything.

## The board

`web/board/` — computed only, monotonic, in-tree. Per round: the bar, the
current number, the delta, what moved. Nothing handwritten, ever.

## The ledger

`web/LEDGER.md` — one line per exclusion, with a reason. A contestant may
PROPOSE; it may never enact. Ratification is Lars's, on the walk — this is
where the human judgment lives, and it is the whole reason the diffs do not
need any.

Expected first proposal, logged now so it arrives honestly: topcoat's
`view!`/`expr!` split exists because Rust compiles one way. Koru's whole-
program-JS answer means several reference behaviors may have **no gap to
close** — a fixture can already be served by a different architecture. That
is a conformance result (behavior met), recorded on the board — not an
exclusion, and it does not need ratification.

## Exit conditions

- **The bar is met** — on rung 1 a real finish; take it.
- **Plateau** — the closer stopped moving across N rounds, computed.
- **Budget exhausted** — declared above.
- **The ledger grew faster than the score** — a run producing mostly
  exclusions is discovering the bar was wrong. Stop, walk.
- **The model divergence made the comparison meaningless** — if every
  fixture ends "met by different architecture," the gauntlet taught its
  lesson early. Also a finish; report it as one.

## The standing guard

**The bar is a measure, not a telos.** Beat someone else's framework as your
only standard and you have built someone else's framework.

The feature mining is the deliverable, same as DOM's: every place a fixture
forces an escape — to `|js`, to hand-written serialization, to a shell-out —
is a place the language could not reach, and **that count is the real
board.** An Orisha that serves topcoat-parity pages while the page logic is
60% hand-rolled JSON is a finding we would want to know, and would never
learn from a stopwatch.

**So the headline metric is two numbers, not one:** fixtures conformant, and
the fraction of the serving path that escaped the language.
