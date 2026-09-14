# koru/signal — proposed surface (v0.2 sketch, nothing welded yet)

*Seeded 2026-09-14 from the design walk. This file is the artifact to argue
against — the rulings it encodes live in koru `concepts/`:
`frag-signal-lift-vs-native-port`, `frag-kernel-vocabulary-is-the-gpu-portability-contour`,
`frag-dimension-algebra-is-model-scoped`, `frag-taint-is-per-value-signal-is-per-stream`.*

## The ruling shape

A model is **not one declaration** — it is distributed sections joined on
the model name, the same binding mechanism Koru uses everywhere
(`store:insert(bodies)`/`store:query(bodies)` on a store name; `route()`
invocations collected in Orisha; `~std/build:requires` blocks welded at
build). Each section is a named `norun`/`comptime` tor whose `{ }` block is
a **signal-local grammar** — the transform owns it, it mimics Koru rather
than matching it.

```koru
// The model "Bucket" — the sections may live in different files;
// codegen joins them on the name and refuses a partial model loudly.

std/proto(BucketState) {          // carried state is a registered proto —
    bucket: f64                   // identity + layout; std/store can carry
    deficit: f64                  // it per-row (per-entity instances = a
    prev_faucet: f64              // store column set), and the wire schema
    seeded: f64                   // can later derive from the same entry
}

koru/signal:units(Bucket) {       // closed dimension vocabulary — phantom
    faucet: tokens/s              // labels are open strings; THIS registry
    requested: tokens             // is what makes `tokens/s` checked rather
    granted: tokens               // than opaque. `pecrent` refuses as
    deficit: tokens               // "unknown unit", not "phantom mismatch"
    bucket: tokens
    capacity: tokens
    dt: s
    present: 1
    pred: tokens/s
    err: tokens/s
    surprise: tokens
}

koru/signal:transfers(Bucket) {   // the legal dimension-changing steps —
    integrate: tokens/s -> tokens // the algebra table the language never
}                                 // grows; checked at model-compile time

koru/signal:consts(Bucket) {
    dt: 10
    capacity: 4000
    refill_rate: 80
}

koru/signal:ticks(Bucket) {       // kernel vocabulary: elementwise, masked
    if (present) {                // if, no loops — the portable contour;
        refill = refill_rate * dt // absent sample = an inactive lane
        bucket += refill
        if (bucket > capacity) { bucket = capacity }
        requested = faucet * dt
        if (bucket < requested) { granted = bucket } else { granted = requested }
        bucket -= granted
        deficit = requested - granted
        if (seeded) { pred = prev_faucet } else { pred = faucet }
        prev_faucet = faucet
        seeded = 1
        err = faucet - pred
        surprise = deficit
    }
    // void: conservative hold — no refill, no grant, state frozen.
}
```

## What each piece maps to

| Surface | Mechanism | Status |
|---|---|---|
| `std/proto(BucketState)` | nominal identity + layout; store-consumable | exists — `std/store:new { breath: BreathState }` shape green (690_286) |
| port/unit labels | `f64<percent>` phantom on scalars | exists — enforced (330_063–067, literal suffix 330_066) |
| `signal:units` | closed vocabulary + dimension algebra over labels | **new layer** — the part no organ owns |
| `signal:ticks` | signal-local statement grammar, kernel vocabulary | new — spelling modeled on `kernel:self { }` |
| per-entity instances | proto state → store rows; tick inside `! query` | designed, unbuilt — the rung-2 convergence |
| `present`/void | lane mask (predication) | designed — ports to GPU unlike real control flow |

## Authoring rules (the honest ones)

- **Kernel vocabulary in tick bodies.** Masked `if`, elementwise
  arithmetic, no loops, no host calls — so the body can lower to
  `kernel:self` when `std/signal` exists. Anything that can't is a
  lift-only capability and gets marked as such.
- **Completeness is checkable.** `units(FastBreath)` with no other
  sections naming `FastBreath` is a dangling reference — loud refusal,
  KORU201-style, never a silent miss. Two `units(Bucket)` blocks is a
  duplicate registrant — refused, per proto's rule.
- **Sections may be distributed.** Units in the model lib, ticks in the
  consumer — the name is the join key, home-scoped like proto.

## Unmeasured — compile before claiming

- Phantom label on a **proto field** (`peak: f64<percent>` inside
  `std/proto`) and on a **store column** round-trip — does the label
  survive insert/query? If it strips, unit-checking lives in the tick
  body only; if it survives, store columns carry dimensions.
- Whether `model_emit.zig` can see a `std/proto` declaration it must
  derive from — the weld today scrapes one file's own text.
- Void's final shape — `if (present)` guard vs a declared `| void` arm.
- Ternary inside tick bodies (kernel bodies use `if` statements; the
  WMFX `cond ? a : b` idiom may or may not earn a spelling).

## What this file is not

Not a commitment to weld it. The first reader should try to write
`models/bucket.koru.kz` in this shape by hand, then decide what
`model_emit.zig` learns — and anything the surface needs that EEL cannot
lower is a finding to float, not a wart to design around.
