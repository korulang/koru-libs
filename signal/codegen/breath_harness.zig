const std = @import("std");
const model = @import("model");
const oracle = @import("oracle");

pub fn main() !void {
    const bars = [_]oracle.Bar{
        .{ .idx = 0, .iso = "t0", .pass_rate = 90, .passed = 0, .in_scope = 0, .failed = 0, .todo = 0, .in_sample = true },
        .{ .idx = 1, .iso = "t1", .pass_rate = 85, .passed = 0, .in_scope = 0, .failed = 0, .todo = 0, .in_sample = true },
        .{ .idx = 2, .iso = "t2", .pass_rate = 70, .passed = 0, .in_scope = 0, .failed = 0, .todo = 0, .in_sample = false },
    };

    var seq: [20]oracle.Bar = undefined;
    @memcpy(seq[0..3], bars[0..3]);
    var i: usize = 3;
    while (i < seq.len) : (i += 1) {
        seq[i] = .{
            .idx = @intCast(i),
            .iso = "t stall",
            .pass_rate = 70,
            .passed = 0,
            .in_scope = 0,
            .failed = 0,
            .todo = 0,
            .in_sample = false,
        };
    }

    var model_state: model.State = .{};
    _ = model.init(&model_state);

    var ref: oracle.OracleState = .{};
    var mismatch: u32 = 0;
    var oos_fires: u32 = 0;

    for (seq) |bar| {
        model_state.pass_rate = bar.pass_rate;
        _ = model.block(&model_state);

        const ref_out = oracle.step(&ref, bar);
        if (@abs(model_state.alarm - ref_out.alarm) > 1e-9) mismatch += 1;
        if (@abs(model_state.dip_ticks - ref_out.dip_ticks) > 1e-9) mismatch += 1;
        if (!bar.in_sample and model_state.alarm >= 0.5) oos_fires += 1;
    }

    if (mismatch > 0) {
        std.debug.print("FAIL: codegen model diverged from oracle on {d} check(s)\n", .{mismatch});
        return error.OracleMismatch;
    }
    if (oos_fires == 0) {
        std.debug.print("FAIL: sustained inhale never tripped alarm\n", .{});
        return error.NoAlarm;
    }

    std.debug.print("PASS: koru/signal codegen matches breath oracle ({d} OOS fire(s), 0 mismatches)\n", .{oos_fires});
}
