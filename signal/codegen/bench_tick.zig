const std = @import("std");
const breath = @import("breath");

const Iterations = 1_000_000;

fn runtimeTick(state: *breath.State, pass_rate: f64) struct { alarm: f64, dip_ticks: f64 } {
    state.pass_rate = pass_rate;
    _ = breath.block(state);
    return .{ .alarm = state.alarm, .dip_ticks = state.dip_ticks };
}

pub fn main() !void {
    var state: breath.State = .{};
    _ = breath.init(&state);

    // Warmup — same rate pattern as external_tick oracle.
    for (0..10_000) |i| {
        const rate: f64 = switch (i % 3) {
            0 => 90.0,
            1 => 85.0,
            else => 70.0,
        };
        state.pass_rate = rate;
        _ = breath.block(&state);
    }

    var direct_ns: i128 = 0;
    var runtime_ns: i128 = 0;

    {
        const t0 = std.time.nanoTimestamp();
        for (0..Iterations) |i| {
            const rate: f64 = if (i % 3 == 2) 70.0 else 90.0;
            state.pass_rate = rate;
            _ = breath.block(&state);
            std.mem.doNotOptimizeAway(&state.alarm);
        }
        direct_ns = std.time.nanoTimestamp() - t0;
    }

    _ = breath.init(&state);

    {
        const t0 = std.time.nanoTimestamp();
        for (0..Iterations) |i| {
            const rate: f64 = if (i % 3 == 2) 70.0 else 90.0;
            const out = runtimeTick(&state, rate);
            std.mem.doNotOptimizeAway(&out.alarm);
        }
        runtime_ns = std.time.nanoTimestamp() - t0;
    }

    const direct_per = @as(f64, @floatFromInt(direct_ns)) / @as(f64, @floatFromInt(Iterations));
    const runtime_per = @as(f64, @floatFromInt(runtime_ns)) / @as(f64, @floatFromInt(Iterations));

    std.debug.print(
        "BENCH: breath tick @ {d} iterations (ReleaseFast)\n",
        .{Iterations},
    );
    std.debug.print("  emit block() only     {d:.1} ns/op\n", .{direct_per});
    std.debug.print("  runtime wrapper       {d:.1} ns/op  (+{d:.1} ns)\n", .{
        runtime_per,
        runtime_per - direct_per,
    });
    std.debug.print("  throughput (wrapper)  {d:.0} ticks/s\n", .{
        1.0e9 / runtime_per,
    });
}
