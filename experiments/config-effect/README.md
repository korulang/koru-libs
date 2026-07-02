# Spike: inward configuration via optional effect-branch

**Question.** Can a library event whose common path needs zero ceremony also
declare an OPTIONAL effect-branch (`! ?name`) that, when the caller handles it,
fires once *before* the main work, hands the caller a mutable borrow of a
config value, and then proceeds using the *mutated* config — configuration
flowing INWARD through the effect channel?

**Verdict: YES — the pattern is expressible and runs TODAY.** All four legs
stand on probes that compile and run end-to-end against
`/Users/larsde/src/koru/zig-out/bin/koruc`. One safety guarantee (leg 4) is
NOT enforceable today, and one peripheral toolchain defect surfaced (floated,
not blocking).

Every probe below is kept runnable. Run from the repo root
(`/Users/larsde/src/koru-libs`):
`/Users/larsde/src/koru/zig-out/bin/koruc run experiments/config-effect/<probe>.kz`

---

## Leg 1 — DEFAULTS: WORKS

`probe1_defaults.kz`. Event `fetch` declares `! ?configure *Config`; the caller
omits the handler entirely; the proc's `configure(&cfg)` call lowers to a no-op
(the optional-effect contract, grounded in tests 400_077 / 400_078) so `cfg`
keeps its Zig struct defaults.

```
$ koruc run experiments/config-effect/probe1_defaults.kz
...
done 30
fetch http://example.com timeout=30 retries=0
```

`done 30` and `timeout=30 retries=0` are the struct defaults — zero ceremony on
the common path.

## Leg 2 — FIRE-ONCE-BEFORE-WORK: WORKS

`probe2_fire_once_before.kz`. The caller now handles `! configure`. All markers
are routed through `std.debug.print` (a single stderr stream) so ordering is
deterministic; the handler emits its marker via a `mark` event.

```
$ koruc run experiments/config-effect/probe2_fire_once_before.kz
...
1: proc begin
2: configure handler fired
3: main work
```

The handler fires exactly once, strictly between "proc begin" and "main work".
This is the synchronous-callback semantics grounded in tests 400_080 / 400_108:
the proc regains control after the firing returns.

## Leg 3 — INWARD MUTATION (THE CRUX): WORKS

`probe3_inward_mutation.kz`. The handler receives the mutable borrow `c: *Config`
and mutates it INWARD by invoking `set.timeout` / `set.retries` (each a `|zig`
proc that writes through the borrowed pointer). The proc then reads the mutated
config.

```
$ koruc run experiments/config-effect/probe3_inward_mutation.kz
...
done 5003
fetch http://example.com timeout=5000 retries=3
```

`done 5003` = 5000 (handler-set timeout) + 3 (handler-set retries) — NOT the
defaults 30/0. Configuration flowed from the caller's handler back into the
library proc through the effect channel. **This is the reverse of the corpus's
usual outward effect-data flow, and it works.**

### Why it works — the grounded mechanism

The corpus already contains every ingredient; the pattern is their composition:

- **Optional effect branch** `! ?name Payload`: tests 210_076, 400_077.
- **Pointer payload on an effect branch** (`! frame *Frame<ready>`): 400_080.
- **Handler invoking another event** (`! make r |> destroy(r)`): 400_105.
- **Handler invoking an event with a literal arg** (`! v _ |> leaf(n: 3)`): 230_015.
- **A `|zig` proc writing through a pointer arg** (`res.* = ...`): 400_061.
- **Proc reads state after the firing returns** (`frame(f); destroy(f);`): 400_080
  — the firing is a synchronous callback, so a stack-local `&cfg` is valid across it
  and observes the handler's writes.

The novel *combination* — optional (`?`) + pointer (`*`) payload on one effect
branch, used for inward mutation — has no single passing test, so it was probed
directly rather than assumed. It compiles and runs.

Notes on shape choices:
- The decorative phantom `<ready>` on the payload is **optional** — bare
  `*Config` works identically for inward mutation (`bare_ok` variant → `done 42`).
  Cleanest DX is a plain `*Config` payload.
- An effect payload may **not** carry a discharge obligation `<!state>` — that is
  rejected at signature level (test 400_104, `error[KORU027]: cannot discharge an
  obligation`), because a `!` branch fires 0..N times and "discharge exactly once"
  is incoherent. This matters for leg 4.

## Leg 4 — ESCAPE (stretch): the safety guarantee is INEXPRESSIBLE today

`probe4_escape.kz`. sqlite3's row borrow (`*Statement<prepared!>`) makes escaping
the borrow a *compile* error via a phantom obligation. The analogous protection
does **not** extend to an effect-branch borrow. The probe's handler stashes the
borrow into a module-level `var` (a use-after-return of the proc's stack local):

```
$ koruc --check experiments/config-effect/probe4_escape.kz
✓ Shape checking passed
$ koruc run experiments/config-effect/probe4_escape.kz
...
done 30            # compiles AND runs — the escape is never caught
```

The escape compiles cleanly through the whole pipeline. This matches the
compiler repo's own note in test 400_080: *"the phantom state is currently
decorative … Phase 4 hasn't extended the phantom checker to track obligations
through effect branches."*

Precise gap, at the koru level: **to make the inward config borrow leak-safe the
way sqlite3's row borrow is, the phantom checker would need to track a
firing-scoped borrow lifetime through `!` effect-branch payloads** — a borrow
valid only for the duration of the synchronous firing, whose escape (stash into
outer state, or read after the firing returns) is a compile error. Two things
block expressing it today: (1) 400_104 forbids the `<!state>` discharge form on
`!` payloads at the signature level, so you cannot even *declare* the
sqlite-style obligation on an effect borrow; (2) 400_080 confirms effect-payload
phantom states are decorative and untracked. The nearest grounded, enforced
shape is the terminal-branch obligation (`| row *Statement<prepared!>`,
`sqlite3/index.kz:90`) — but that is a `|` terminal, not a `!` effect branch, and
terminals fire exactly once, which is precisely why the obligation is coherent
there and incoherent on a multi-fire `!` branch.

**So: the pattern's data-flow (legs 1–3) is fully expressible; its compile-time
borrow-safety (leg 4) is not.** A library shipping this pattern today gets the
ergonomics and the inward flow, but the caller *could* stash the borrow and the
compiler would not stop them.

---

## Toolchain findings

**1. Layout-sensitive codegen defect in the effect-branch inliner (FLOATED).**
Pinned as `repro_inliner_singleline.kz`. A `|zig` proc that (a) contains an
effect-branch call and (b) discards an unused param with `_ = url;` compiles
correctly when its body is written multi-line, but **fails when the identical
body is on a single physical line**:

```
$ koruc run experiments/config-effect/repro_inliner_singleline.kz
Error: output_emitted.zig:86:17: error: pointless discard of local constant
    _ = url; var cfg = Config{}; { const c = &cfg; ... }
            ^~~
✗ Backend execution failed
```

The inliner auto-emits `_ = &url;` for the param and *also* keeps the user's
`_ = url;` from the body prologue — a double discard Zig rejects. The multi-line
path dedups this; the single-line path does not. Source layout must never change
codegen correctness, so this is a suspected defect — floated (~50% chance it is a
niche misuse) for a human call. It does **not** block the config-effect pattern:
the idiomatic multi-line form compiles cleanly (probe1/probe2/probe3).

**2. Raw Zig error leak (bad-error-message defect, secondary).** The failure
above surfaces as a Zig diagnostic pointing at generated `output_emitted.zig`
coordinates, with no koru-level wall. This is the same class of leak the compiler
repo is closing: an effect-branch-lowering edge where the koru-level diagnostic
isn't built yet.

Neither finding was worked around; both are pinned and reported.

## Proof of life

All commands run from `/Users/larsde/src/koru-libs` against
`/Users/larsde/src/koru/zig-out/bin/koruc`. Outputs pasted above per leg.
Probes kept: `probe1_defaults.kz`, `probe2_fire_once_before.kz`,
`probe3_inward_mutation.kz`, `probe4_escape.kz`, `repro_inliner_singleline.kz`.
