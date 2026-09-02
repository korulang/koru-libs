# koru/signal

Stateful **signal processing** in Koru: named models, carried state, external clock, compile-to-Zig.

**Lineage:** downstream of the [Intranquil JSFX transpiler](https://github.com/6digit-studio/intranquil) → [6digit-world](https://github.com/korulang/6digit-world) WMFX fork → this package. Koru owns the surface; the init/block emit belt is shared with audio DSP. See **`THIRD_PARTY.md`** for licenses and attribution.

The caller owns the loop. Signal owns **init** (compile boundary + state allocation) and **tick** (one discrete-time step).

```koru
import koru/signal

koru/signal:shape(Breath) {
    pass_rate: f64
    drawdown: f64
    alarm: f64
    // ...
}

const {
    depth_floor: 8
    dur_threshold: 18
}

koru/signal:init(Breath) {
    peak: 0
    dip_ticks: 0
}
| ok |> for(snapshots)
    ! each bar |> koru/signal:tick(Breath, pass_rate: bar.rate)
        | out s |> handle(s.alarm)
        | err e => ...
| err e => ...
```

## Quick demo

```bash
cd ~/src/koru-libs/signal/examples
KORU_HOME=~/src/koru koruc breath_demo.k
./a.out
# PASS: breath demo — alarm=1, dip_ticks=18
```

The demo drives twenty synthetic pass-rate snapshots (90 → 85 → 70 held) and checks that **Breath** fires when the inhale is held too long.

## Surface API

| Spelling | Role |
|----------|------|
| `koru/signal:shape(Name) { … }` | Port / wire declaration (norun metadata) |
| `koru/signal:init(Name)` | Compile boundary — allocate emitted `State`, register instance |
| `koru/signal:tick(Name, pass_rate: r)` | External-clock step — read input, update state |
| `koru/signal(Name)` | Bare reference — registers model name at compile time |

v0 models: **Breath** (sustained drawdown), **Floor** (pass_rate below threshold).

Named models mirror **named stores** (`std/store:insert(world)` parallel).

## Verify the package

See **`signal/AUTHORING.md`** for the model-authoring spine (Breath reference).

```bash
# Full signal verify (suite + codegen oracle)
cd ~/src/koru-libs/signal && bash verify.sh

# Lib suite only
cd ~/src/koru-libs && KORU_HOME=~/src/koru koruc suite.k test

# Codegen weld + oracle parity
cd ~/src/koru-libs/signal/codegen && bash run.sh
```

## Layout

```
signal/
  index.kz              transforms + registry (C3 appends koru/signal_rt/*)
  ../signal_rt/         per-model runtime slots (breath.kz, floor.kz) + build:requires
  models/
    breath.zig          Breath — sustained drawdown
    floor.zig           Floor — threshold alarm
    breath.koru.eel     Koru-authored EEL lowering
    floor.koru.eel
  codegen/              shared init/block emit + parity harness
  examples/breath_demo.k
  tests/                pins (external_tick, shape, init, tick, …)
  SERIES.md             slice roadmap + blog companion
```

## Blog

Draft journal: [koru/signal Journal, Part 1](https://korulang.org/blog/drafts?draft=koru-signal-journal-01-external-clock) (after `bun run blog:index` in korulang_org).

Roadmap: `SERIES.md`.
