// Breath demo — external-clock signal processing with koru/signal.
//
// Synthetic pass-rate snapshots: 90, 85, then 70 for eighteen ticks.
// Sustained inhale trips alarm on tick 20 (dip_ticks >= 18).
//
//   cd ~/src/koru-libs/signal/examples
//   KORU_HOME=~/src/koru koruc breath_demo.k
//   ./zig-out/bin/output

import koru/signal
import std/io

koru/signal:shape(Breath) {
    pass_rate[percent]
    drawdown[percent]
    alarm[1]
    surprise[1]
}

const {
    depth_floor: 8
    dur_threshold: 18
}

koru/signal:init(Breath)
| ok |> for(0..20)
    ! each i |> snapshot-rate(i): r
        |> koru/signal:tick(Breath, pass_rate: r)
            | out s |> check-step(i, s.alarm, dip-ticks: s.dip_ticks)
            | err e |> std/io:print.ln("tick failed: {{ e:s }}")
| err e |> std/io:print.ln("init failed: {{ e:s }}")

tor snapshot-rate { i: usize } -> f64

proc snapshot-rate|zig {
    return switch (i) {
        0 => 90.0,
        1 => 85.0,
        else => 70.0,
    };
}

tor check-step { i: usize, alarm: f64, dip-ticks: f64 }

proc check-step|zig {
    const std = @import("std");
    if (i != 19) return;
    if (alarm < 0.5) @panic("sustained inhale never tripped alarm");
    if (dip_ticks < 18.0) @panic("dip_ticks below dur_threshold");
    std.debug.print(
        "PASS: breath demo — alarm={d}, dip_ticks={d}\n",
        .{ alarm, dip_ticks },
    );
}
